CREATE DATABASE inventory;
USE inventory;

SELECT * FROM inventory_forecasting;

CREATE TABLE stores (
    store_id VARCHAR(10) PRIMARY KEY,
    region VARCHAR(20)
);
CREATE TABLE products (
    product_id VARCHAR(10) PRIMARY KEY,
    category VARCHAR(50),
    base_price FLOAT
);

CREATE TABLE sales (
    sale_date DATE,
    store_id VARCHAR(10),
    product_id VARCHAR(10),
    units_sold INT,
    discount INT,
    holiday_promotion TINYINT,
    competitor_pricing FLOAT,
    seasonality VARCHAR(20),
    PRIMARY KEY (sale_date, store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE inventory (
    date DATE,
    store_id VARCHAR(10),
    product_id VARCHAR(10),
    inventory_level INT,
    units_ordered INT,
    demand_forecast FLOAT,
    PRIMARY KEY (date, store_id, product_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE weather (
    date DATE,
    store_id VARCHAR(10),
    weather_condition VARCHAR(20),
    PRIMARY KEY (date, store_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id)
);


CREATE TABLE raw_forecast_data (
    date DATE,
    store_id VARCHAR(10),
    product_id VARCHAR(10),
    category VARCHAR(50),
    region VARCHAR(20),
    inventory_level INT,
    units_sold INT,
    units_ordered INT,
    demand_forecast FLOAT,
    price FLOAT,
    discount INT,
    weather_condition VARCHAR(20),
    holiday_promotion TINYINT,
    competitor_pricing FLOAT,
    seasonality VARCHAR(20)
);

SELECT * FROM raw_forecast_data LIMIT 10;

INSERT INTO sales (sale_date, store_id, product_id, units_sold, discount, holiday_promotion, competitor_pricing, seasonality)
SELECT date, store_id, product_id,
       SUM(units_sold),
       AVG(discount),
       MAX(holiday_promotion),
       AVG(competitor_pricing),
       MIN(seasonality)
FROM raw_forecast_data
GROUP BY date, store_id, product_id;

INSERT INTO inventory (date, store_id, product_id, inventory_level, units_ordered, demand_forecast)
SELECT date, store_id, product_id,
       MAX(inventory_level),
       SUM(units_ordered),
       AVG(demand_forecast)
FROM raw_forecast_data
GROUP BY date, store_id, product_id;

INSERT INTO weather (date, store_id, weather_condition)
SELECT date, store_id, MIN(TRIM(weather_condition))
FROM raw_forecast_data
GROUP BY date, store_id;

INSERT INTO stores (store_id, region)
SELECT DISTINCT store_id, region FROM raw_forecast_data
ON DUPLICATE KEY UPDATE region = VALUES(region);

INSERT INTO products (product_id, category, base_price)
SELECT DISTINCT product_id, category, price FROM raw_forecast_data
ON DUPLICATE KEY UPDATE
  category = VALUES(category),
  base_price = VALUES(base_price);

SHOW WARNINGS;

SELECT ROW_COUNT();

SELECT * FROM stores LIMIT 5;
SELECT * FROM products LIMIT 5;

SELECT COUNT(DISTINCT store_id) FROM raw_forecast_data;
SELECT COUNT(*) FROM stores;

SELECT * FROM stores LIMIT 5;
SELECT * FROM products LIMIT 5;
SELECT * FROM sales LIMIT 5;

ALTER TABLE sales
ADD CONSTRAINT fk_sales_store
FOREIGN KEY (store_id) REFERENCES stores(store_id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE sales
ADD CONSTRAINT fk_sales_product
FOREIGN KEY (product_id) REFERENCES products(product_id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_store
FOREIGN KEY (store_id) REFERENCES stores(store_id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE inventory
ADD CONSTRAINT fk_inventory_product
FOREIGN KEY (product_id) REFERENCES products(product_id)
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE weather
ADD CONSTRAINT fk_weather_store
FOREIGN KEY (store_id) REFERENCES stores(store_id)
ON DELETE CASCADE ON UPDATE CASCADE;

SELECT table_name, constraint_name, referenced_table_name
FROM information_schema.referential_constraints
WHERE constraint_schema = 'your_database_name';

-- ** SQL QUUERIES **
-- STOCK LEVEL CALCULATION

SELECT 
    store_id, 
    product_id, 
    SUM(inventory_level) AS total_stock
FROM 
    inventory
GROUP BY 
    store_id, product_id;
   
-- LOW INVENTORY DETECTION

ALTER TABLE products
ADD COLUMN reorder_threshold INT DEFAULT 50;

   
SELECT 
    i.store_id, 
    i.product_id, 
    i.inventory_level, 
    p.reorder_threshold
FROM 
    inventory i
JOIN 
    products p ON i.product_id = p.product_id
WHERE 
    i.inventory_level < p.reorder_threshold;


-- REORDER POINT ESTIMATION

SELECT COUNT(*) FROM sales;

SELECT MIN(sale_date) AS oldest, MAX(sale_date) AS newest FROM sales;

SELECT 
    product_id,
    ROUND(AVG(units_sold) * 30, 2) AS estimated_monthly_demand
FROM 
    sales
WHERE 
    sale_date >= '2022-01-01'
GROUP BY 
    product_id;


SELECT 
    product_id,
    ROUND(AVG(units_sold) * 30, 2) AS estimated_monthly_demand
FROM 
    sales
WHERE 
    sale_date >= CURDATE() - INTERVAL 30 DAY
GROUP BY 
    product_id;


-- INVENTORY TURNOVER ANALYSIS

WITH daily_product_stats AS (     
SELECT          
s.product_id,         
s.sale_date,         
SUM(s.units_sold) AS daily_units_sold,         
AVG(i.inventory_level) AS daily_inventory     
FROM          
sales s     
JOIN          
 inventory i ON s.product_id = i.product_id                    
     AND s.store_id = i.store_id                    
     AND s.sale_date = i.date     
GROUP BY          
s.product_id, s.sale_date )  

SELECT      
product_id,     
ROUND(AVG(daily_units_sold), 2) AS avg_daily_sales,     
ROUND(AVG(daily_inventory), 2) AS avg_daily_inventory,     
ROUND(AVG(daily_units_sold) / NULLIF(AVG(daily_inventory), 0), 2) AS turnover_ratio 
FROM      
daily_product_stats 
GROUP BY      
product_id;
    
    
-- KPI SUMMARY REPORT 

SELECT
    product_id, 
    ROUND(AVG(inventory_level), 2) AS avg_stock_level
FROM 
    inventory
GROUP BY 
    product_id;

SELECT 
    product_id, 
    ROUND(SUM(CASE WHEN inventory_level = 0 THEN 1 ELSE 0 END) / COUNT(*), 2) AS stockout_rate
FROM 
    inventory
GROUP BY 
    product_id;

SELECT 
    product_id, 
    DATEDIFF(CURDATE(), MIN(date)) AS inventory_age_days
FROM 
    inventory
WHERE 
    inventory_level > 0
GROUP BY 
    product_id;


-- ** DATABASE OPTIMIZATION **

-- sales references
ALTER TABLE sales
ADD FOREIGN KEY (store_id) REFERENCES stores(store_id),
ADD FOREIGN KEY (product_id) REFERENCES products(product_id);

-- inventory references
ALTER TABLE inventory
ADD FOREIGN KEY (store_id) REFERENCES stores(store_id),
ADD FOREIGN KEY (product_id) REFERENCES products(product_id);

-- weather references
ALTER TABLE weather
ADD FOREIGN KEY (store_id) REFERENCES stores(store_id);



-- INDEXING

CREATE INDEX idx_sales_store_product ON sales(store_id, product_id);
CREATE INDEX idx_inventory_product_store ON inventory(product_id, store_id);
CREATE INDEX idx_weather_store ON weather(store_id);

-- ** ANALYTICAL INSIGHTS **

-- fast-selling vs slow-moving products
SELECT 
    s.store_id,
    p.product_id,
    SUM(s.units_sold) AS total_units_sold,
    st.region
FROM 
    sales s
JOIN 
    stores st ON s.store_id = st.store_id
JOIN 
    products p ON s.product_id = p.product_id
GROUP BY 
    s.store_id, p.product_id
ORDER BY 
    total_units_sold DESC
LIMIT 10;

-- Overstocked Products (Slow-Moving)

SELECT 
    i.store_id,
    i.product_id,
    MAX(i.inventory_level) AS inventory_level,  -- Aggregated
    COALESCE(SUM(s.units_sold), 0) AS total_sold_last_30_days
FROM 
    inventory i
LEFT JOIN 
    sales s ON i.product_id = s.product_id 
           AND i.store_id = s.store_id
           AND s.sale_date >= CURDATE() - INTERVAL 30 DAY
WHERE 
    i.inventory_level > 100
GROUP BY 
    i.store_id, i.product_id
ORDER BY 
    inventory_level DESC;

--  supplier performance inconsistencies if we have supplier data

CREATE TABLE supplier_orders (
    supplier_id VARCHAR(10),
    product_id VARCHAR(10),
    order_id INT PRIMARY KEY,
    expected_delivery DATE,
    delivery_date DATE
);

-- Insert some sample data
INSERT INTO supplier_orders VALUES
('SUP001', 'P001', 1, '2025-06-15', '2025-06-16'),  -- Delayed
('SUP001', 'P002', 2, '2025-06-15', '2025-06-14'),  -- On time
('SUP002', 'P003', 3, '2025-06-15', '2025-06-20'),  -- Delayed
('SUP002', 'P004', 4, '2025-06-15', '2025-06-15');  -- On time

SELECT 
    supplier_id,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN delivery_date > expected_delivery THEN 1 ELSE 0 END) AS delayed_orders,
    ROUND(SUM(CASE WHEN delivery_date > expected_delivery THEN 1 ELSE 0 END)/COUNT(*) * 100, 2) AS delay_rate
FROM 
    supplier_orders
GROUP BY 
    supplier_id
HAVING 
    delay_rate > 50;

-- forecast demand trends 

SELECT 
    product_id,
    seasonality,
    SUM(units_sold) AS total_units_sold
FROM 
    sales
GROUP BY 
    product_id, seasonality
ORDER BY 
    product_id, seasonality;

WITH seasonal_sales AS (
  SELECT 
    product_id,
    seasonality,
    SUM(units_sold) AS seasonal_demand,
    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY SUM(units_sold) DESC) AS rn
  FROM 
    sales
GROUP BY 
    product_id, seasonality
)
SELECT 
    product_id,
    seasonality,
    seasonal_demand
FROM 
    seasonal_sales
WHERE 
    rn = 1;


SELECT 
    product_id,
    seasonality,
    ROUND(AVG(units_sold) * 30, 2) AS projected_monthly_demand
FROM 
    sales
WHERE 
    seasonality = 'Winter'  -- change based on the upcoming season
GROUP BY 
    product_id, seasonality;
    
    
-- ow Inventory Detection based on reorder points

SELECT 
    i.store_id,
    i.product_id,
    i.inventory_level,
    p.reorder_threshold,
    (p.reorder_threshold - i.inventory_level) AS units_below_threshold
FROM 
    inventory i
JOIN 
    products p ON i.product_id = p.product_id
WHERE 
    i.inventory_level < p.reorder_threshold
ORDER BY 
    units_below_threshold DESC;
    
-- Recommend stock adjustments to reduce holding costs

SELECT 
    i.store_id,
    i.product_id,
    AVG(i.inventory_level) AS avg_stock,
    AVG(s.units_sold) AS avg_sales,
    ROUND((AVG(i.inventory_level) - AVG(s.units_sold)), 2) AS surplus_estimate
FROM 
    inventory i
JOIN 
    sales s ON i.store_id = s.store_id AND i.product_id = s.product_id AND i.date = s.sale_date
GROUP BY 
    i.store_id, i.product_id
HAVING 
    avg_stock > 100 AND avg_sales < 10
ORDER BY 
    surplus_estimate DESC;


-- ADDITIONAL QUERY INSIGHTS 

-- Monthly Sales Trend per Product

SELECT 
    product_id,
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    SUM(units_sold) AS total_sold
FROM 
    sales
GROUP BY 
    product_id, month
ORDER BY 
    product_id, month;

-- Top 10 Products by Sales Volatility

SELECT 
    product_id,
    ROUND(STDDEV(units_sold), 2) AS sales_volatility,
    ROUND(AVG(units_sold), 2) AS avg_sales
FROM 
    sales
GROUP BY 
    product_id
ORDER BY 
    sales_volatility DESC
LIMIT 10;

-- Weather-Driven Sales Impact

SELECT 
    w.weather_condition,
    ROUND(AVG(s.units_sold), 2) AS avg_units_sold
FROM 
    sales s
JOIN 
    weather w ON s.store_id = w.store_id AND s.sale_date = w.date
GROUP BY 
    w.weather_condition
ORDER BY 
    avg_units_sold DESC;
    
    


