import { useEffect, useMemo, useState } from "react";
import { CatalogItems, CartSnapshot, OrderResponse } from "./types";
import { ServiceCard } from "./components/ServiceCard";
import { fetchCatalog, fetchCart, addCartItem, checkoutCart, createOrder } from "./services/api";

const DEFAULT_USER = "demo-user";

export default function App() {
  const config = useMemo(() => {
    const fallback = import.meta.env;
    return {
      catalogApi: __APP_CONFIG__.catalogApi || fallback.VITE_CATALOG_API || "",
      cartApi: __APP_CONFIG__.cartApi || fallback.VITE_CART_API || "",
      orderApi: __APP_CONFIG__.orderApi || fallback.VITE_ORDER_API || "",
    };
  }, []);

  const [catalog, setCatalog] = useState<CatalogItems | null>(null);
  const [cart, setCart] = useState<CartSnapshot | null>(null);
  const [orderResult, setOrderResult] = useState<OrderResponse | null>(null);
  const [isLoadingCatalog, setIsLoadingCatalog] = useState(false);
  const [isLoadingCart, setIsLoadingCart] = useState(false);
  const [isOrdering, setIsOrdering] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!config.catalogApi) {
      setError("Falta configurar VITE_CATALOG_API");
    }
  }, [config.catalogApi]);

  const refreshCatalog = async () => {
    if (!config.catalogApi) return;
    setError(null);
    setIsLoadingCatalog(true);
    try {
      const data = await fetchCatalog(config.catalogApi);
      setCatalog(data);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsLoadingCatalog(false);
    }
  };

  const refreshCart = async () => {
    if (!config.cartApi) return;
    setError(null);
    setIsLoadingCart(true);
    try {
      const data = await fetchCart(config.cartApi, DEFAULT_USER);
      setCart(data);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsLoadingCart(false);
    }
  };

  const handleAddItem = async (sku: string, price: number) => {
    if (!config.cartApi) return;
    setError(null);
    try {
      const updated = await addCartItem(config.cartApi, DEFAULT_USER, sku, price);
      setCart(updated);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const handleCheckout = async () => {
    if (!config.cartApi) return;
    setError(null);
    try {
      const updated = await checkoutCart(config.cartApi, DEFAULT_USER);
      setCart(updated);
    } catch (err) {
      setError((err as Error).message);
    }
  };

  const handleCreateOrder = async () => {
    if (!config.orderApi || !cart || cart.items.length === 0) return;
    setIsOrdering(true);
    setError(null);
    try {
      const order = await createOrder(config.orderApi, DEFAULT_USER, cart);
      setOrderResult(order);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setIsOrdering(false);
    }
  };

  return (
    <div className="app">
      <header>
        <h1>Bookstore Control Panel</h1>
        <p className="subtitle">
          UI ligera para probar los microservicios principales. Configura las URLs en las variables
          <code> VITE_CATALOG_API</code>,<code> VITE_CART_API</code> y <code>VITE_ORDER_API</code>.
        </p>
      </header>

      {error && <div className="error">{error}</div>}

      <main className="grid">
        <ServiceCard
          title="Catálogo"
          description="Consulta los productos publicados."
          endpoint={config.catalogApi}
          cta={{ label: "Cargar catálogo", onClick: refreshCatalog, loading: isLoadingCatalog }}
        >
          {catalog ? (
            <ul className="list">
              {catalog.items.map((item) => (
                <li key={item.sku} className="list-item">
                  <div>
                    <strong>{item.title}</strong>
                    <small>SKU: {item.sku}</small>
                    <small>Precio: ${item.price.toFixed(2)}</small>
                  </div>
                  <button
                    type="button"
                    onClick={() => handleAddItem(item.sku, item.price)}
                    className="primary"
                    disabled={!config.cartApi}
                  >
                    Añadir al carrito
                  </button>
                </li>
              ))}
            </ul>
          ) : (
            <p className="placeholder">Sin datos. Pulsa "Cargar catálogo" para empezar.</p>
          )}
        </ServiceCard>

        <ServiceCard
          title="Carrito"
          description="Vista del carrito del usuario demo."
          endpoint={config.cartApi}
          cta={{ label: "Refrescar carrito", onClick: refreshCart, loading: isLoadingCart }}
        >
          {cart ? (
            <div className="stack">
              <ul className="list">
                {cart.items.map((item) => (
                  <li key={item.productId} className="list-item">
                    <div>
                      <strong>{item.productId}</strong>
                      <small>Cantidad: {item.quantity}</small>
                      <small>Total: ${item.total.toFixed(2)}</small>
                    </div>
                  </li>
                ))}
              </ul>
              <div className="totals">
                <span>Items: {cart.itemCount}</span>
                <span>Subtotal: ${cart.subtotal.toFixed(2)}</span>
              </div>
              <div className="actions">
                <button type="button" className="secondary" onClick={handleCheckout}>
                  Vaciar carrito (checkout)
                </button>
                <button
                  type="button"
                  className="primary"
                  onClick={handleCreateOrder}
                  disabled={!cart.items.length || isOrdering || !config.orderApi}
                >
                  Crear orden
                </button>
              </div>
            </div>
          ) : (
            <p className="placeholder">Todavía no se ha cargado ningún carrito.</p>
          )}
        </ServiceCard>

        <ServiceCard
          title="Órdenes"
          description="Dispara la lógica de order-service usando el carrito actual."
          endpoint={config.orderApi}
          cta={{
            label: "Crear orden",
            onClick: handleCreateOrder,
            loading: isOrdering,
            disabled: !cart || !cart.items.length,
          }}
        >
          {orderResult ? (
            <div className="order-result">
              <p>Orden creada correctamente.</p>
              <dl>
                <dt>ID</dt>
                <dd>{orderResult.orderId}</dd>
                <dt>Total</dt>
                <dd>${orderResult.total.toFixed(2)}</dd>
                <dt>Estado</dt>
                <dd>{orderResult.status}</dd>
              </dl>
            </div>
          ) : (
            <p className="placeholder">Aún no se generó ninguna orden.</p>
          )}
        </ServiceCard>
      </main>
    </div>
  );
}
