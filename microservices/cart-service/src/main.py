import os
import uuid
from typing import List, Optional

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

from .store import InMemoryCartStore

try:
    import redis  # type: ignore
except Exception:  # pragma: no cover
    redis = None

try:
    from .publisher import publish_cart_checked_out
except Exception:  # pragma: no cover
    def publish_cart_checked_out(event: dict):
        print("[cart-service] publisher not available; skipping publish")


load_dotenv()


def getenv_bool(key: str, default: bool = False) -> bool:
    val = os.getenv(key)
    if val is None:
        return default
    return val.lower() in ("1", "true", "yes", "on")


HOST = os.getenv("HOST", "127.0.0.1")
PORT = int(os.getenv("PORT", "8080"))
CART_USE_REDIS = getenv_bool("CART_USE_REDIS", False)
CART_REDIS_URL = os.getenv("CART_REDIS_URL", "redis://localhost:6379/0")


class AddItemRequest(BaseModel):
    productId: str = Field(..., min_length=1)
    quantity: int = Field(..., ge=1)
    price: float = Field(..., ge=0)


class UpdateQuantityRequest(BaseModel):
    quantity: int = Field(..., ge=0)


class CartItemOut(BaseModel):
    productId: str
    quantity: int
    price: float
    total: float


class CartResponse(BaseModel):
    userId: str
    items: List[CartItemOut]
    itemCount: int
    subtotal: float


def _build_store():
    if CART_USE_REDIS and redis is not None:
        from .store import RedisCartStore
        client = redis.from_url(CART_REDIS_URL)
        return RedisCartStore(client)
    return InMemoryCartStore()


store = _build_store()
app = FastAPI(title="cart-service")


def _cart_to_response(user_id: str) -> CartResponse:
    raw = store.get_cart(user_id)
    items: List[CartItemOut] = []
    item_count = 0
    subtotal = 0.0
    for pid, item in raw.items():
        q = int(item.get("quantity", 0))
        p = float(item.get("price", 0.0))
        t = q * p
        item_count += q
        subtotal += t
        items.append(CartItemOut(productId=pid, quantity=q, price=p, total=t))
    return CartResponse(userId=user_id, items=items, itemCount=item_count, subtotal=round(subtotal, 2))


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/cart/{user_id}", response_model=CartResponse)
def get_cart(user_id: str):
    return _cart_to_response(user_id)


@app.post("/cart/{user_id}/items", response_model=CartResponse)
def add_item(user_id: str, body: AddItemRequest):
    store.add_item(user_id, body.productId, body.quantity, body.price)
    return _cart_to_response(user_id)


@app.put("/cart/{user_id}/items/{product_id}", response_model=CartResponse)
def update_item(user_id: str, product_id: str, body: UpdateQuantityRequest):
    store.update_item(user_id, product_id, body.quantity)
    return _cart_to_response(user_id)


@app.delete("/cart/{user_id}/items/{product_id}", response_model=CartResponse)
def delete_item(user_id: str, product_id: str):
    store.remove_item(user_id, product_id)
    return _cart_to_response(user_id)


@app.post("/cart/{user_id}/checkout", response_model=CartResponse)
def checkout(user_id: str):
    cart = _cart_to_response(user_id)
    # publish event (optional)
    try:
        event = {
            "messageId": str(uuid.uuid4()),
            "correlationId": str(uuid.uuid4()),
            "type": "cart.checked_out",
            "userId": user_id,
            "itemCount": cart.itemCount,
            "subtotal": cart.subtotal,
            "items": [i.dict() for i in cart.items],
        }
        publish_cart_checked_out(event)
    except Exception as e:
        # non-strict mode: just log to stdout
        print("[cart-service] checkout publish error:", e)
    # clear cart after checkout
    store.clear(user_id)
    return cart


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host=HOST, port=PORT)
