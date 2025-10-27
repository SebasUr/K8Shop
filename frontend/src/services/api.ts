import { CatalogItems, CartSnapshot, OrderResponse } from "../types";

const JSON_HEADERS = { "Content-Type": "application/json" } as const;

function withBase(url: string, path: string) {
  return `${url.replace(/\/$/, "")}${path}`;
}

async function handleResponse<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const message = await res.text();
    throw new Error(message || `Error HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function fetchCatalog(baseUrl: string): Promise<CatalogItems> {
  const apiUrl = withBase(baseUrl, "/catalog");
  const res = await fetch(apiUrl);
  return handleResponse<CatalogItems>(res);
}

export async function fetchCart(baseUrl: string, userId: string): Promise<CartSnapshot> {
  const apiUrl = withBase(baseUrl, `/cart/${encodeURIComponent(userId)}`);
  const res = await fetch(apiUrl);
  return handleResponse<CartSnapshot>(res);
}

export async function addCartItem(baseUrl: string, userId: string, sku: string, price: number) {
  const apiUrl = withBase(baseUrl, `/cart/${encodeURIComponent(userId)}/items`);
  const res = await fetch(apiUrl, {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify({ productId: sku, quantity: 1, price }),
  });
  return handleResponse<CartSnapshot>(res);
}

export async function checkoutCart(baseUrl: string, userId: string) {
  const apiUrl = withBase(baseUrl, `/cart/${encodeURIComponent(userId)}/checkout`);
  const res = await fetch(apiUrl, { method: "POST", headers: JSON_HEADERS });
  return handleResponse<CartSnapshot>(res);
}

export async function createOrder(baseUrl: string, userId: string, cart: CartSnapshot) {
  const apiUrl = withBase(baseUrl, "/orders");
  const payload = {
    userId,
    items: cart.items.map((item) => ({ sku: item.productId, qty: item.quantity, price: item.price })),
  };
  const res = await fetch(apiUrl, {
    method: "POST",
    headers: JSON_HEADERS,
    body: JSON.stringify(payload),
  });
  return handleResponse<OrderResponse>(res);
}
