import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { CatalogItems, CartSnapshot, OrderResponse } from "./types";
import { fetchCatalog, fetchCart, addCartItem, checkoutCart, createOrder } from "./services/api";

const DEFAULT_USER = "demo-user";

type Toast = {
  type: "success" | "error" | "info";
  message: string;
};

export default function App() {
  const config = useMemo(() => {
    const fallback = import.meta.env;
    const normalizeBase = (value: string | undefined, segment: string) => {
      const base = (value || "").trim();
      if (!base) return "";
      const cleaned = base.replace(/\/+$/, "");
      const suffix = `/${segment}`;
      return cleaned.endsWith(suffix) ? cleaned.slice(0, -suffix.length) : cleaned;
    };

    const defaultBase = "/api";
    const catalogApi = normalizeBase(__APP_CONFIG__.catalogApi || fallback.VITE_CATALOG_API || defaultBase, "catalog");
    const cartApi = normalizeBase(__APP_CONFIG__.cartApi || fallback.VITE_CART_API || defaultBase, "cart");
    const orderApi = normalizeBase(__APP_CONFIG__.orderApi || fallback.VITE_ORDER_API || defaultBase, "orders");

    return {
      catalogApi,
      cartApi,
      orderApi,
      services: [
        {
          key: "catalog",
          name: "Catálogo",
          endpoint: catalogApi,
          description: "Node.js + PostgreSQL (catalog-service)",
        },
        {
          key: "cart",
          name: "Carrito",
          endpoint: cartApi,
          description: "FastAPI + Redis TLS (cart-service)",
        },
        {
          key: "orders",
          name: "Órdenes",
          endpoint: orderApi,
          description: "FastAPI + DynamoDB/RDS (order-service)",
        },
      ],
    };
  }, []);

  const [catalog, setCatalog] = useState<CatalogItems | null>(null);
  const [cart, setCart] = useState<CartSnapshot | null>(null);
  const [orderResult, setOrderResult] = useState<OrderResponse | null>(null);
  const [isLoadingCatalog, setIsLoadingCatalog] = useState(false);
  const [isLoadingCart, setIsLoadingCart] = useState(false);
  const [isOrdering, setIsOrdering] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<Toast | null>(null);

  const showToast = useCallback((type: Toast["type"], message: string) => {
    setToast({ type, message });
  }, []);

  const catalogRequestSeq = useRef(0);
  const cartRequestSeq = useRef(0);

  const catalogLookup = useMemo(() => {
    const map = new Map<string, CatalogItems["items"][number]>();
    if (catalog?.items?.length) {
      for (const item of catalog.items) {
        map.set(item.sku, item);
      }
    }
    return map;
  }, [catalog]);

  const cartLines = useMemo(() => {
    if (!cart) return [];
    return cart.items.map((item) => {
      const meta = catalogLookup.get(item.productId);
      return {
        ...item,
        title: meta?.title ?? item.productId,
        unitPrice: meta?.price ?? item.price,
      };
    });
  }, [cart, catalogLookup]);

  const orderLines = useMemo(() => {
    if (!orderResult?.items || orderResult.items.length === 0) return [];
    return orderResult.items.map((line) => {
      const legacy = line as unknown as { quantity?: number; qty?: number };
      const quantity = legacy.quantity ?? legacy.qty ?? 0;
      const meta = catalogLookup.get(line.sku);
      return {
        ...line,
        quantity,
        title: meta?.title ?? line.sku,
      };
    });
  }, [orderResult, catalogLookup]);

  const orderItemCount = useMemo(() => {
    if (orderResult?.itemCount !== undefined) {
      return orderResult.itemCount;
    }
    return orderLines.reduce((acc, line) => acc + line.quantity, 0);
  }, [orderResult, orderLines]);

  const orderCreatedAt = useMemo(() => {
    if (!orderResult?.createdAt) return null;
    const date = new Date(orderResult.createdAt);
    if (Number.isNaN(date.getTime())) return null;
    return date.toLocaleString();
  }, [orderResult]);

  useEffect(() => {
    if (!toast) return;
    const timer = setTimeout(() => setToast(null), 4000);
    return () => clearTimeout(timer);
  }, [toast]);

  useEffect(() => {
    if (!config.catalogApi) {
      setError("Falta configurar VITE_CATALOG_API");
    }
  }, [config.catalogApi]);

  const refreshCatalog = useCallback(
    async (silent = false) => {
      if (!config.catalogApi) return;
      setError(null);
      const requestId = ++catalogRequestSeq.current;
      setIsLoadingCatalog(true);
      try {
        const data = await fetchCatalog(config.catalogApi);
        if (requestId !== catalogRequestSeq.current) return;
        setCatalog(data);
        if (!silent) {
          showToast("success", "Catálogo actualizado");
        }
      } catch (err) {
        const message = (err as Error).message;
        if (requestId !== catalogRequestSeq.current) return;
        setError(message);
        showToast("error", message);
      } finally {
        if (requestId === catalogRequestSeq.current) {
          setIsLoadingCatalog(false);
        }
      }
    },
    [config.catalogApi, showToast]
  );

  const refreshCart = useCallback(
    async (silent = false) => {
      if (!config.cartApi) return;
      setError(null);
      const requestId = ++cartRequestSeq.current;
      setIsLoadingCart(true);
      try {
        const data = await fetchCart(config.cartApi, DEFAULT_USER);
        if (requestId !== cartRequestSeq.current) return;
        setCart(data);
        if (!silent) {
          showToast("success", "Carrito sincronizado");
        }
      } catch (err) {
        const message = (err as Error).message;
        if (requestId !== cartRequestSeq.current) return;
        setError(message);
        showToast("error", message);
      } finally {
        if (requestId === cartRequestSeq.current) {
          setIsLoadingCart(false);
        }
      }
    },
    [config.cartApi, showToast]
  );

  useEffect(() => {
    if (config.catalogApi) {
      refreshCatalog(true).catch(() => undefined);
    }
    if (config.cartApi) {
      refreshCart(true).catch(() => undefined);
    }
  }, [config.catalogApi, config.cartApi, refreshCatalog, refreshCart]);

  const handleAddItem = async (sku: string, price: number, title: string) => {
    if (!config.cartApi) return;
    setError(null);
    const requestId = ++cartRequestSeq.current;
    setIsLoadingCart(true);
    try {
      const updated = await addCartItem(config.cartApi, DEFAULT_USER, sku, price);
      if (requestId !== cartRequestSeq.current) return;
      setCart(updated);
      showToast("success", `Añadido "${title}" al carrito`);
    } catch (err) {
      const message = (err as Error).message;
      if (requestId !== cartRequestSeq.current) return;
      setError(message);
      showToast("error", message);
    }
    finally {
      if (requestId === cartRequestSeq.current) {
        setIsLoadingCart(false);
      }
    }
  };

  const handleCheckout = async () => {
    if (!config.cartApi) return;
    setError(null);
    const requestId = ++cartRequestSeq.current;
    setIsLoadingCart(true);
    try {
      const updated = await checkoutCart(config.cartApi, DEFAULT_USER);
      if (requestId !== cartRequestSeq.current) return;
      setCart(updated);
      showToast("info", "Checkout ejecutado: carrito limpio");
      refreshCart(true).catch(() => undefined);
    } catch (err) {
      const message = (err as Error).message;
      if (requestId !== cartRequestSeq.current) return;
      setError(message);
      showToast("error", message);
    }
    finally {
      if (requestId === cartRequestSeq.current) {
        setIsLoadingCart(false);
      }
    }
  };

  const handleCreateOrder = async () => {
    if (!config.orderApi || !cart || cart.items.length === 0) return;
    setIsOrdering(true);
    setError(null);
    try {
      const order = await createOrder(config.orderApi, DEFAULT_USER, cart);
      setOrderResult(order);
       showToast("success", `Orden ${order.orderId.slice(0, 8)} creada`);
    } catch (err) {
      const message = (err as Error).message;
      setError(message);
      showToast("error", message);
    } finally {
      setIsOrdering(false);
    }
  };

  return (
    <div className="page">
      {toast && <div className={`toast toast--${toast.type}`}>{toast.message}</div>}
      <div className="page__inner">
        <header className="hero">
          <div className="hero__content">
            <span className="badge">K8Shop demo</span>
            <h1>Bookstore Dashboard</h1>
            <p>
              Panel ligero para demostrar los microservicios desplegados en el clúster de Kubernetes.
              Usa el usuario demo para validar flujo completo: catálogo → carrito → orden.
            </p>
            <div className="hero__actions">
              <button
                type="button"
                className="btn btn--contrast"
                onClick={() => refreshCatalog()}
                disabled={isLoadingCatalog || !config.catalogApi}
              >
                {isLoadingCatalog ? "Cargando catálogo" : "Actualizar catálogo"}
              </button>
              <button
                type="button"
                className="btn btn--ghost"
                onClick={() => refreshCart()}
                disabled={isLoadingCart || !config.cartApi}
              >
                {isLoadingCart ? "Sincronizando carrito" : "Sincronizar carrito"}
              </button>
            </div>
            <dl className="hero__meta">
              <div>
                <dt>Usuario demo</dt>
                <dd>{DEFAULT_USER}</dd>
              </div>
              <div>
                <dt>Productos</dt>
                <dd>{catalog?.count ?? "--"}</dd>
              </div>
              <div>
                <dt>Items en carrito</dt>
                <dd>{cart?.itemCount ?? 0}</dd>
              </div>
            </dl>
          </div>
          <div className="hero__panel">
            <h3>Estado rápido</h3>
            <ul className="hero__status">
              {config.services.map((svc) => (
                <li key={svc.key}>
                  <span className={`dot ${svc.endpoint ? "dot--ok" : "dot--warn"}`} />
                  <div>
                    <strong>{svc.name}</strong>
                    <small>{svc.endpoint || "Endpoint no configurado"}</small>
                  </div>
                </li>
              ))}
            </ul>
            <p className="hero__hint">Los endpoints se inyectan vía ConfigMap y secrets del clúster.</p>
          </div>
        </header>

        {error && <div className="callout callout--error">{error}</div>}

        <section className="section">
          <div className="section__head">
            <div>
              <h2>Catálogo de libros</h2>
              <p>Productos publicados por el microservicio catalog-service respaldado por PostgreSQL.</p>
            </div>
            <button
              type="button"
              className="btn btn--primary"
              onClick={() => refreshCatalog()}
              disabled={isLoadingCatalog || !config.catalogApi}
            >
              {isLoadingCatalog ? "Actualizando..." : "Refrescar catálogo"}
            </button>
          </div>

          {isLoadingCatalog && !catalog ? (
            <div className="skeleton">Cargando catálogo...</div>
          ) : (
            <div className="product-grid">
              {catalog && catalog.items.length ? (
                catalog.items.map((item) => (
                  <article key={item.sku} className="product-card">
                    <div className="product-card__tags">
                      {(item.tags || []).slice(0, 3).map((tag) => (
                        <span key={tag} className="chip">
                          {tag}
                        </span>
                      ))}
                    </div>
                    <h3>{item.title}</h3>
                    <p className="product-card__meta">SKU {item.sku}</p>
                    <p className="product-card__price">${item.price.toFixed(2)}</p>
                    <p className="product-card__stock">
                      {typeof item.stock === "number" ? `${item.stock} en stock` : "Inventario sin sincronizar"}
                    </p>
                    <button
                      type="button"
                      className="btn btn--primary"
                      onClick={() => handleAddItem(item.sku, item.price, item.title)}
                      disabled={!config.cartApi}
                    >
                      Añadir al carrito
                    </button>
                  </article>
                ))
              ) : (
                <div className="empty">No hay productos todavía. Corre el script de seed si es necesario.</div>
              )}
            </div>
          )}
        </section>

        <section className="section">
          <div className="section__head">
            <div>
              <h2>Operaciones rápidas</h2>
              <p>Comprueba que Redis y order-service respondan al flujo completo.</p>
            </div>
          </div>

          <div className="columns">
            <article className="panel">
              <div className="panel__head">
                <div>
                  <h3>Carrito de {DEFAULT_USER}</h3>
                  <p>Datos almacenados en ElastiCache Redis con TLS.</p>
                </div>
                <button
                  type="button"
                  className="btn btn--ghost"
                  onClick={() => refreshCart()}
                  disabled={isLoadingCart || !config.cartApi}
                >
                  {isLoadingCart ? "Actualizando..." : "Actualizar"}
                </button>
              </div>

              {isLoadingCart && !cart ? (
                <div className="skeleton">Cargando carrito...</div>
              ) : cartLines.length ? (
                <div className="cart">
                  <ul className="cart__list">
                    {cartLines.map((item) => (
                      <li key={item.productId}>
                        <div>
                          <strong>{item.title}</strong>
                          <small>
                            SKU {item.productId} · {item.quantity} uds × ${item.unitPrice.toFixed(2)}
                          </small>
                        </div>
                        <span>${item.total.toFixed(2)}</span>
                      </li>
                    ))}
                  </ul>
                  <div className="cart__totals">
                    <span>{cart?.itemCount ?? 0} artículos</span>
                    <strong>${(cart?.subtotal ?? 0).toFixed(2)}</strong>
                  </div>
                  <div className="cart__actions">
                    <button type="button" className="btn btn--ghost" onClick={handleCheckout}>
                      Checkout
                    </button>
                    <button
                      type="button"
                      className="btn btn--primary"
                      onClick={handleCreateOrder}
                      disabled={!cartLines.length || isOrdering || !config.orderApi}
                    >
                      {isOrdering ? "Creando orden..." : "Crear orden"}
                    </button>
                  </div>
                </div>
              ) : (
                <div className="empty">Sin items todavía. Agrega uno desde el catálogo.</div>
              )}
            </article>

            <article className="panel">
              <div className="panel__head">
                <div>
                  <h3>Orden más reciente</h3>
                  <p>Respuesta de order-service (y notificaciones a RabbitMQ).</p>
                </div>
              </div>

              {orderResult ? (
                <div className="order">
                  <div className="order__cover">
                    <span>#{orderResult.orderId.slice(0, 8)}</span>
                  </div>
                  {orderLines.length > 0 && (
                    <ul className="order__items">
                      {orderLines.map((line) => (
                        <li key={line.sku}>
                          <div>
                            <strong>{line.title}</strong>
                            <small>
                              SKU {line.sku} · {line.quantity} uds × ${line.price.toFixed(2)}
                            </small>
                          </div>
                          <span>${line.total.toFixed(2)}</span>
                        </li>
                      ))}
                    </ul>
                  )}
                  <dl>
                    <div>
                      <dt>Estado</dt>
                      <dd>{orderResult.status}</dd>
                    </div>
                    <div>
                      <dt>Items</dt>
                      <dd>{orderItemCount}</dd>
                    </div>
                    <div>
                      <dt>Total</dt>
                      <dd>${orderResult.total.toFixed(2)}</dd>
                    </div>
                    {orderCreatedAt && (
                      <div>
                        <dt>Creada</dt>
                        <dd>{orderCreatedAt}</dd>
                      </div>
                    )}
                    <div>
                      <dt>Referencia</dt>
                      <dd>{orderResult.orderId}</dd>
                    </div>
                  </dl>
                </div>
              ) : (
                <div className="empty">Genera una orden desde el carrito para ver el resultado.</div>
              )}
            </article>
          </div>
        </section>

        <section className="section">
          <div className="section__head">
            <div>
              <h2>Servicios desplegados</h2>
              <p>Endpoints expuestos por el clúster de Kubernetes.</p>
            </div>
          </div>

          <div className="service-grid">
            {config.services.map((svc) => (
              <article key={svc.key} className="service-card">
                <h3>{svc.name}</h3>
                <p>{svc.description}</p>
                <span className={`chip ${svc.endpoint ? "chip--ok" : "chip--warn"}`}>
                  {svc.endpoint || "Sin configurar"}
                </span>
              </article>
            ))}
          </div>
        </section>
      </div>
    </div>
  );
}
