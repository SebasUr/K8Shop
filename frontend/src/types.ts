export type CatalogItem = {
  id: string;
  sku: string;
  title: string;
  price: number;
  stock?: number;
  tags?: string[];
};

export type CatalogItems = {
  items: CatalogItem[];
  count: number;
};

export type CartItem = {
  productId: string;
  quantity: number;
  price: number;
  total: number;
};

export type CartSnapshot = {
  userId: string;
  items: CartItem[];
  itemCount: number;
  subtotal: number;
};

export type OrderResponse = {
  orderId: string;
  status: string;
  total: number;
};
