\set ON_ERROR_STOP on

-- Upsert base catalog products (idempotent)
WITH upserted AS (
  INSERT INTO catalog.products (sku, title, description, price, image_url, tags)
  VALUES
    ('SKU-100', 'Wireless Mouse', '2.4GHz wireless mouse with ergonomic design', 19.99, 'https://example.com/images/sku-100.jpg', ARRAY['peripheral','mouse']),
    ('SKU-101', 'Mechanical Keyboard', 'Full-size mechanical keyboard with blue switches', 79.50, 'https://example.com/images/sku-101.jpg', ARRAY['peripheral','keyboard']),
    ('SKU-102', 'USB-C Cable', '1m braided USB-C charging and data cable', 9.90, 'https://example.com/images/sku-102.jpg', ARRAY['cable','usb-c']),
    ('SKU-103', '27" Monitor', '1440p 27-inch IPS monitor', 239.00, 'https://example.com/images/sku-103.jpg', ARRAY['monitor','display'])
  ON CONFLICT (sku) DO UPDATE
    SET title = EXCLUDED.title,
        description = EXCLUDED.description,
        price = EXCLUDED.price,
        image_url = EXCLUDED.image_url,
        tags = EXCLUDED.tags,
        updated_at = now()
  RETURNING id, sku
)
INSERT INTO catalog.product_inventory (product_id, available)
SELECT id, CASE sku
  WHEN 'SKU-100' THEN 120
  WHEN 'SKU-101' THEN 45
  WHEN 'SKU-102' THEN 300
  ELSE 25
END
FROM upserted
ON CONFLICT (product_id) DO UPDATE
  SET available = EXCLUDED.available,
      updated_at = now();

-- Sample order and items referencing catalog entries
WITH prod_mouse AS (
  SELECT id, price FROM catalog.products WHERE sku = 'SKU-100'
), prod_keyboard AS (
  SELECT id, price FROM catalog.products WHERE sku = 'SKU-101'
), new_order AS (
  INSERT INTO "order".orders (user_id, status, total_amount)
  SELECT 'user-0001', 'completed', (pm.price + pk.price)
  FROM prod_mouse pm, prod_keyboard pk
  ON CONFLICT DO NOTHING
  RETURNING id
)
INSERT INTO "order".order_items (order_id, sku, quantity, unit_price)
SELECT o.id, 'SKU-100', 1, pm.price
FROM new_order o, prod_mouse pm
UNION ALL
SELECT o.id, 'SKU-101', 1, pk.price
FROM new_order o, prod_keyboard pk
ON CONFLICT DO NOTHING;

-- Seed a payment record for the sample order
INSERT INTO payment.payments (order_id, status, amount, transaction_ref)
SELECT o.id, 'payment.succeeded', o.total_amount, 'demo-ref-001'
FROM "order".orders o
WHERE o.user_id = 'user-0001'
ON CONFLICT (order_id) DO NOTHING;

-- Optional: log a recommendation response for analytics demo
INSERT INTO recommendation.recommendation_logs (product_id, user_id, strategy, payload)
VALUES
  ('SKU-100', 'user-0001', 'popular', '{"recommended": ["SKU-101","SKU-102"]}'::jsonb)
ON CONFLICT DO NOTHING;
