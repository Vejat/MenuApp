WITH demo(name, category, price) AS (VALUES
  ('Empanadas de queso', 'Entradas', 3900),
  ('Papas rústicas', 'Acompañamientos', 4200),
  ('Pastel de choclo', 'Platos principales', 8500),
  ('Hamburguesa de la casa', 'Platos principales', 8900),
  ('Ensalada de quinoa', 'Entradas', 6900),
  ('Limonada con menta', 'Bebidas sin alcohol', 2900),
  ('Agua mineral', 'Bebidas sin alcohol', 1800),
  ('Cerveza lager', 'Cervezas', 3900),
  ('Copa de vino tinto', 'Vinos y cócteles', 4500),
  ('Mojito', 'Vinos y cócteles', 5200),
  ('Brownie con helado', 'Postres', 4500),
  ('Flan casero', 'Postres', 3500)
)
UPDATE products p SET category = demo.category
FROM demo WHERE lower(p.name) = lower(demo.name);

INSERT INTO products (name, category, price, available)
SELECT demo.name, demo.category, demo.price, true
FROM (VALUES
  ('Empanadas de queso', 'Entradas', 3900),
  ('Papas rústicas', 'Acompañamientos', 4200),
  ('Pastel de choclo', 'Platos principales', 8500),
  ('Hamburguesa de la casa', 'Platos principales', 8900),
  ('Ensalada de quinoa', 'Entradas', 6900),
  ('Limonada con menta', 'Bebidas sin alcohol', 2900),
  ('Agua mineral', 'Bebidas sin alcohol', 1800),
  ('Cerveza lager', 'Cervezas', 3900),
  ('Copa de vino tinto', 'Vinos y cócteles', 4500),
  ('Mojito', 'Vinos y cócteles', 5200),
  ('Brownie con helado', 'Postres', 4500),
  ('Flan casero', 'Postres', 3500)
) AS demo(name, category, price)
WHERE NOT EXISTS (
  SELECT 1 FROM products WHERE lower(products.name) = lower(demo.name)
);
