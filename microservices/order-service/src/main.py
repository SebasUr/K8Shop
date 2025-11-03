from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from publisher import publish_order_created
from dotenv import load_dotenv, find_dotenv
import uuid, os, datetime

# Load environment variables from a .env file if present (search up the tree)
load_dotenv(find_dotenv())

app = FastAPI()
DATABASE_URL = os.getenv("DATABASE_URL", "")

class Item(BaseModel):
    sku: str
    qty: int
    price: float


class OrderReq(BaseModel):
    userId: str
    items: list[Item]

@app.get("/healthz")
def healthz(): return {"ok": True, "db": bool(DATABASE_URL)}

@app.post("/orders")
def create_order(req: OrderReq):
    # minimal validation
    if not req.items:
        raise HTTPException(status_code=400, detail="items required")

    order_id = str(uuid.uuid4())
    created_at = datetime.datetime.utcnow().isoformat()
    raw_items = []
    order_items = []
    item_count = 0

    for item in req.items:
        raw = item.model_dump() if hasattr(item, "model_dump") else item.dict()
        qty = int(raw.get("qty", raw.get("quantity", 0)))
        price = round(float(raw.get("price", 0.0)), 2)
        line_total = round(qty * price, 2)
        item_count += qty
        order_items.append({
            "sku": raw.get("sku"),
            "quantity": qty,
            "price": price,
            "total": line_total,
        })
        raw["total"] = line_total
        raw["quantity"] = qty
        raw_items.append(raw)

    total = round(sum(line["total"] for line in order_items), 2)

    event = {
        "event": "order.created",
        "version": 1,
        "orderId": order_id,
        "userId": req.userId,
        "items": raw_items,
        "total": total,
        "itemCount": item_count,
        "createdAt": created_at,
        "messageId": str(uuid.uuid4()),
        "correlationId": order_id,
    }
    # persist: in a real app you would save to DB (omitted here)
    publish_order_created(event)
    return {
        "orderId": order_id,
        "status": "created",
        "total": total,
        "itemCount": item_count,
        "items": order_items,
        "createdAt": created_at,
    }

# Allow running the service directly: `python main.py`
if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8000"))
    log_level = os.getenv("LOG_LEVEL", "info")
    uvicorn.run("main:app", host=host, port=port, log_level=log_level, reload=True)
