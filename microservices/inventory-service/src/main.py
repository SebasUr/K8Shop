import os, json, random, time
from typing import List

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from dotenv import load_dotenv, find_dotenv

# Load env from .env if present
load_dotenv(find_dotenv())

app = FastAPI()
DATABASE_URL = os.getenv("DATABASE_URL", "")

# Env flags to control optional RabbitMQ publishing
PUBLISH_ENABLED = os.getenv("INVENTORY_PUBLISH_ENABLED", "0").lower() in ("1", "true", "yes", "on")
PUBLISH_STRICT = os.getenv("INVENTORY_PUBLISH_STRICT", "0").lower() in ("1", "true", "yes", "on")
RABBIT_URL = os.getenv("RABBIT_URL", os.getenv("INVENTORY_RABBIT_URL", "amqp://guest:guest@localhost:5672/%2f"))

class Item(BaseModel):
    sku: str
    qty: int

class InventoryReq(BaseModel):
    order_id: str
    items: List[Item]

class InventoryResp(BaseModel):
    order_id: str
    status: str


def publish_inventory_updated(event: dict):
    if not PUBLISH_ENABLED:
        print("[inventory-service] publish disabled; skipping for", event.get("order_id"))
        return
    try:
        import pika  # lazy import
        params = pika.URLParameters(RABBIT_URL)
        conn = pika.BlockingConnection(params)
        ch = conn.channel()
        ch.queue_declare(queue='inventory.updated', durable=True)
        ch.basic_publish(
            exchange='',
            routing_key='inventory.updated',
            body=json.dumps(event),
            properties=pika.BasicProperties(content_type='application/json', delivery_mode=2),
        )
        print("[inventory-service] published inventory.updated for", event.get("order_id"))
        conn.close()
    except Exception as e:
        msg = f"[inventory-service] publish failed: {e}"
        if PUBLISH_STRICT:
            raise RuntimeError(msg)
        print(msg)


@app.get("/healthz")
def healthz():
    return {"ok": True, "db": bool(DATABASE_URL)}


@app.post("/inventory/apply", response_model=InventoryResp)
def apply_inventory(req: InventoryReq):
    if not req.items:
        raise HTTPException(status_code=400, detail="items required")
    # Simulate inventory processing
    time.sleep(0.3)
    # 75% success
    success = random.random() < 0.75
    status = "inventory.updated" if success else "inventory.failed"
    event = {"order_id": req.order_id, "status": status}
    publish_inventory_updated(event)
    return InventoryResp(order_id=req.order_id, status=status)


if __name__ == "__main__":
    import uvicorn
    host = os.getenv("HOST", "127.0.0.1")
    port = int(os.getenv("PORT", "8080"))
    uvicorn.run("main:app", host=host, port=port, reload=True)
