INSERT INTO products (name, price, available)
SELECT demo.name, demo.price, true
FROM (VALUES
  ('Empanadas de queso', 3900),
  ('Papas rústicas', 4200),
  ('Pastel de choclo', 8500),
  ('Hamburguesa de la casa', 8900),
  ('Ensalada de quinoa', 6900),
  ('Limonada con menta', 2900),
  ('Brownie con helado', 4500),
  ('Flan casero', 3500)
) AS demo(name, price)
WHERE NOT EXISTS (
  SELECT 1 FROM products WHERE lower(products.name) = lower(demo.name)
);
