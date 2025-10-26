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
    total = sum([i.qty * i.price for i in req.items])
    event = {
        "event": "order.created",
        "version": 1,
        "orderId": order_id,
        "userId": req.userId,
        # Support both Pydantic v1 and v2
        "items": [i.model_dump() if hasattr(i, "model_dump") else i.dict() for i in req.items],
        "total": total,
        "createdAt": datetime.datetime.utcnow().isoformat(),
        "messageId": str(uuid.uuid4()),
        "correlationId": order_id
    }
    # persist: in a real app you would save to DB (omitted here)
    publish_order_created(event)
    return {"orderId": order_id, "status": "created", "total": total}

# Allow running the service directly: `python main.py`
if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8000"))
    log_level = os.getenv("LOG_LEVEL", "info")
    uvicorn.run("main:app", host=host, port=port, log_level=log_level, reload=True)
