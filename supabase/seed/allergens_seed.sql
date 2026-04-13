-- Allergens seed data
-- 63 allergens covering EU 14 major allergens + common others
-- Schema: id TEXT PRIMARY KEY, name_en TEXT, name_tr TEXT, category TEXT, icon_name TEXT, severity_note TEXT

INSERT INTO allergens (id, name_en, name_tr, category, icon_name, severity_note) VALUES

-- 1. Gluten-containing cereals (6)
('wheat_gluten',   'Wheat (Gluten)',  'Buğday Gluteni',  'gluten', 'wheat',   'Major EU allergen; found in bread, pasta, baked goods'),
('rye_gluten',     'Rye (Gluten)',    'Çavdar Gluteni',  'gluten', 'wheat',   'Major EU allergen; found in rye bread and crispbreads'),
('barley_gluten',  'Barley (Gluten)', 'Arpa Gluteni',    'gluten', 'wheat',   'Major EU allergen; found in beer, malt products'),
('oats_gluten',    'Oats (Gluten)',   'Yulaf Gluteni',   'gluten', 'wheat',   'Major EU allergen; may be tolerated by some celiacs'),
('spelt_gluten',   'Spelt (Gluten)',  'Spelta Gluteni',  'gluten', 'wheat',   'Major EU allergen; ancient wheat variety'),
('kamut_gluten',   'Kamut (Gluten)',  'Kamut Gluteni',   'gluten', 'wheat',   'Major EU allergen; Khorasan wheat variety'),

-- 2. Crustaceans (4)
('shrimp',    'Shrimp',    'Karides',  'crustacean', 'shrimp', 'Major EU allergen; cross-reactivity with other shellfish'),
('crab',      'Crab',      'Yengeç',   'crustacean', 'shrimp', 'Major EU allergen; cross-reactivity with other shellfish'),
('lobster',   'Lobster',   'Istakoz',  'crustacean', 'shrimp', 'Major EU allergen; high risk for severe reactions'),
('crayfish',  'Crayfish',  'Kerevit',  'crustacean', 'shrimp', 'Major EU allergen; freshwater crustacean'),

-- 3. Eggs (2)
('chicken_egg',  'Chicken Egg',  'Tavuk Yumurtası',  'egg', 'egg', 'Major EU allergen; found in baked goods, mayonnaise, pasta'),
('duck_egg',     'Duck Egg',     'Ördek Yumurtası',  'egg', 'egg', 'Cross-reactivity with chicken egg common'),

-- 4. Fish (9)
('cod',      'Cod',      'Morina Balığı',  'fish', 'fish', 'Major EU allergen; common in fish and chips, fish sticks'),
('salmon',   'Salmon',   'Somon Balığı',   'fish', 'fish', 'Major EU allergen; found in sushi, smoked fish'),
('tuna',     'Tuna',     'Ton Balığı',     'fish', 'fish', 'Major EU allergen; found in canned goods, sushi'),
('herring',  'Herring',  'Ringa Balığı',   'fish', 'fish', 'Major EU allergen; common in Scandinavian cuisine'),
('mackerel', 'Mackerel', 'Uskumru',        'fish', 'fish', 'Major EU allergen; high histamine content'),
('sardine',  'Sardine',  'Sardalya',       'fish', 'fish', 'Major EU allergen; found in canned goods'),
('anchovy',  'Anchovy',  'Hamsi/Ançüez',   'fish', 'fish', 'Major EU allergen; found in Worcestershire sauce, pizza'),
('plaice',   'Plaice',   'Pisi Balığı',    'fish', 'fish', 'Major EU allergen; flatfish'),
('pike',     'Pike',     'Turna Balığı',   'fish', 'fish', 'Major EU allergen; freshwater fish'),

-- 5. Peanuts (1)
('peanut',  'Peanut',  'Yer Fıstığı',  'peanut', 'peanut', 'Major EU allergen; high risk for anaphylaxis; found in sauces, baked goods'),

-- 6. Soybeans (1)
('soybean',  'Soybean',  'Soya Fasulyesi',  'soy', 'soy', 'Major EU allergen; found in tofu, soy sauce, meat substitutes'),

-- 7. Milk / Lactose (3)
('cow_milk',    'Cow Milk',    'İnek Sütü',   'milk', 'milk', 'Major EU allergen; found in dairy products, baked goods'),
('goat_milk',   'Goat Milk',   'Keçi Sütü',   'milk', 'milk', 'Cross-reactivity with cow milk possible'),
('sheep_milk',  'Sheep Milk',  'Koyun Sütü',  'milk', 'milk', 'Cross-reactivity with cow milk possible'),

-- 8. Tree Nuts (10)
('almond',        'Almond',         'Badem',            'nut', 'nut', 'Major EU allergen; found in marzipan, baked goods'),
('hazelnut',      'Hazelnut',       'Fındık',           'nut', 'nut', 'Major EU allergen; found in chocolate spreads, pralines'),
('walnut',        'Walnut',         'Ceviz',            'nut', 'nut', 'Major EU allergen; found in baked goods, salads'),
('cashew',        'Cashew',         'Kaju Fıstığı',     'nut', 'nut', 'Major EU allergen; cross-reactivity with pistachio'),
('pecan',         'Pecan',          'Pikan Cevizi',     'nut', 'nut', 'Major EU allergen; cross-reactivity with walnut'),
('pistachio',     'Pistachio',      'Antep Fıstığı',    'nut', 'nut', 'Major EU allergen; cross-reactivity with cashew'),
('brazil_nut',    'Brazil Nut',     'Brezilya Cevizi',  'nut', 'nut', 'Major EU allergen; high risk for severe reactions'),
('macadamia',     'Macadamia Nut',  'Makademya Cevizi', 'nut', 'nut', 'Major EU allergen'),
('pine_nut',      'Pine Nut',       'Çam Fıstığı',      'nut', 'nut', 'Major EU allergen; may cause pine mouth syndrome'),
('chestnut',      'Chestnut',       'Kestane',          'nut', 'nut', 'Major EU allergen; latex-fruit cross-reactivity'),

-- 9. Celery (1)
('celery',  'Celery',  'Kereviz',  'celery', 'celery', 'Major EU allergen; found in soups, spice mixes, salads'),

-- 10. Mustard (1)
('mustard',  'Mustard',  'Hardal',  'mustard', 'mustard', 'Major EU allergen; found in condiments, dressings, marinades'),

-- 11. Sesame Seeds (1)
('sesame',  'Sesame',  'Susam',  'sesame', 'sesame', 'Major EU allergen; found in tahini, hummus, bread toppings'),

-- 12. Sulphur Dioxide / Sulphites (1)
('sulphites',  'Sulphur Dioxide / Sulphites',  'Kükürt Dioksit / Sülfitler',  'sulphite', 'sulphite', 'Major EU allergen; >10 mg/kg or mg/L; found in wine, dried fruits'),

-- 13. Lupin (1)
('lupin',  'Lupin',  'Acı Bakla (Lupin)',  'lupin', 'lupin', 'Major EU allergen; cross-reactivity with peanut; found in flour, pasta'),

-- 14. Molluscs (6)
('squid',    'Squid',    'Kalamar',       'mollusc', 'mollusc', 'Major EU allergen; includes calamari'),
('octopus',  'Octopus',  'Ahtapot',       'mollusc', 'mollusc', 'Major EU allergen'),
('clam',     'Clam',     'Midye İstiridye (Küçük)', 'mollusc', 'mollusc', 'Major EU allergen'),
('oyster',   'Oyster',   'İstiridye',     'mollusc', 'mollusc', 'Major EU allergen'),
('mussel',   'Mussel',   'Midye',         'mollusc', 'mollusc', 'Major EU allergen'),
('scallop',  'Scallop',  'Tarak Deniz Tarağı', 'mollusc', 'mollusc', 'Major EU allergen'),

-- 15. Additional / Other (16)
('corn_maize',  'Corn / Maize',  'Mısır',          'other', 'wheat',   'Common allergen; found in cornstarch, popcorn, corn syrup'),
('kiwi',        'Kiwi',          'Kivi',            'other', 'mollusc', 'Oral allergy syndrome; latex-fruit cross-reactivity'),
('avocado',     'Avocado',       'Avokado',         'other', 'mollusc', 'Latex-fruit syndrome; cross-reactivity with latex'),
('banana',      'Banana',        'Muz',             'other', 'mollusc', 'Latex-fruit syndrome; oral allergy syndrome possible'),
('latex_chestnut', 'Chestnut (Latex-fruit)', 'Kestane (Lateks-meyve)', 'other', 'nut', 'Latex-fruit syndrome; distinct from tree nut allergy'),
('apple',       'Apple',         'Elma',            'other', 'mollusc', 'Oral allergy syndrome; birch pollen cross-reactivity'),
('peach',       'Peach',         'Şeftali',         'other', 'mollusc', 'Oral allergy syndrome; LTP allergen in southern Europe'),
('strawberry',  'Strawberry',    'Çilek',           'other', 'mollusc', 'Oral allergy syndrome; pseudo-allergic reactions'),
('tomato',      'Tomato',        'Domates',         'other', 'mollusc', 'Cross-reactivity with grass pollen; oral allergy syndrome'),
('carrot',      'Carrot',        'Havuç',           'other', 'celery',  'Oral allergy syndrome; birch pollen cross-reactivity'),
('garlic',      'Garlic',        'Sarımsak',        'other', 'celery',  'Cross-reactivity with onion; contact dermatitis risk'),
('onion',       'Onion',         'Soğan',           'other', 'celery',  'Cross-reactivity with garlic'),
('mango',       'Mango',         'Mango',           'other', 'mollusc', 'Contact allergy to urushiol; cross-reactivity with latex'),
('buckwheat',   'Buckwheat',     'Karabuğday',      'other', 'wheat',   'Non-gluten grain; common allergen in Asia'),
('lentil',      'Lentil',        'Mercimek',        'other', 'peanut',  'Legume family; cross-reactivity with peanut/soy possible'),
('chickpea',    'Chickpea',      'Nohut',           'other', 'peanut',  'Legume family; cross-reactivity with peanut/soy possible')

ON CONFLICT (id) DO UPDATE SET
  name_en         = EXCLUDED.name_en,
  name_tr         = EXCLUDED.name_tr,
  category        = EXCLUDED.category,
  icon_name       = EXCLUDED.icon_name,
  severity_note   = EXCLUDED.severity_note;
