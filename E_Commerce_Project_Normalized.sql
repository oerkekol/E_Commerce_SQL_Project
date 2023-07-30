

-- Cleaning Order_id, Customer_id, Shipping_Id

UPDATE e_commerce
SET
	Ord_ID  = CAST(SUBSTRING(Ord_ID, CHARINDEX('_', Ord_ID) + 1, LEN(Ord_ID)) AS INT),
    Cust_ID = CAST(SUBSTRING(Cust_ID, CHARINDEX('_', Cust_ID) + 1, LEN(Cust_ID)) AS INT),
    Prod_ID = CAST(SUBSTRING(Prod_ID, CHARINDEX('_', Prod_ID) + 1, LEN(Prod_ID)) AS INT),
    Ship_ID = CAST(SUBSTRING(Ship_ID, CHARINDEX('_', Ship_ID) + 1, LEN(Ship_ID)) AS INT);

SELECT *
FROM e_commerce

---- Creating Orders column and eliminating dublicate entries and adding neccessary constraints

SELECT  DISTINCT [Ord_ID], [Cust_ID], [Prod_ID], [Order_Date], [Ship_ID], [Order_Quantity], [Sales], [Order_Priority] 
INTO orders
FROM e_commerce

ALTER TABLE orders
ALTER COLUMN [Ord_ID] INT NOT NULL

ALTER TABLE orders
ALTER COLUMN [Prod_ID] INT NOT NULL

ALTER TABLE orders
ADD CONSTRAINT Pk_order  PRIMARY KEY ([Ord_ID],[Prod_ID])

---- Creating Customers column and eliminating dublicate entries and adding neccessary constraints

SELECT DISTINCT [Cust_ID], [Customer_Name], [Province], [Region], [Customer_Segment]
INTO Customer
FROM e_commerce

ALTER TABLE Customer 
ALTER COLUMN [Cust_ID] INT NOT NULL

ALTER TABLE Customer
ADD CONSTRAINT Pk_cust  PRIMARY KEY ([Cust_ID])

--- Creating Shipping column and adding necessary constraints
SELECT DISTINCT Ship_ID, Ship_Date, DaysTakenForShipping
INTO shipping
FROM e_commerce

ALTER TABLE shipping
ALTER COLUMN [Ship_ID] INT NOT NULL

ALTER TABLE shipping
ADD CONSTRAINT Pk_ship  PRIMARY KEY ([Ship_ID])


--------- Building reference keys

--- Customer and Orders tables
ALTER TABLE orders
ALTER COLUMN [cust_id] INT NOT NULL

ALTER TABLE orders
ADD CONSTRAINT fk_cust FOREIGN KEY ([cust_id]) REFERENCES Customer([cust_id])

-- Orders and Shipping tables
ALTER TABLE orders
ALTER COLUMN [ship_id] INT NOT NULL

ALTER TABLE orders
ADD CONSTRAINT fk_ship FOREIGN KEY ([ship_id]) REFERENCES shipping([ship_id])


--- Nonclustered index for Customer_Name 

CREATE NONCLUSTERED INDEX cust_index ON customer(Customer_Name)


-- Analyzing



-- Top 3 customers who have ordered the most


SELECT DISTINCT  TOP 3 WITH TIES c.Cust_ID, c.Customer_Name, 
COUNT(Ord_ID) OVER(PARTITION BY c.Cust_ID) Count_Order
FROM orders o
INNER JOIN Customer c ON c.Cust_ID=o.Cust_ID
ORDER BY Count_Order DESC


-- the customer whose order took the maximum time to get shipping.

SELECT *
FROM ( 
		SELECT c.Cust_ID, o.Ord_ID, o.Order_Date, s.Ship_Date, s.DaysTakenForShipping, 
			   MAX(DaysTakenForShipping) OVER() Max_Ship_Date 
		FROM orders o
		INNER JOIN shipping s ON s.Ship_ID=o.Ship_ID
		INNER JOIN Customer c ON c.Cust_ID=o.Cust_ID) subq
WHERE DaysTakenForShipping=Max_Ship_Date


-- Number of customers who placed order in january 2011 count of retention monthly 


SELECT COUNT(DISTINCT c.Cust_ID) Customer_Count
FROM Customer c 
INNER JOIN orders o ON o.Cust_ID=c.Cust_ID
WHERE YEAR(Order_Date) = 2011 AND MONTH(Order_Date) = 01 
 GO


-- Number of customers who placed order in january 2011 count of retention monthly 


WITH T1 AS 
(
	SELECT o.Cust_ID, MONTH(Order_Date) Month, COUNT(DISTINCT ord_id) Order_Count
	FROM orders o, 
	(
	SELECT DISTINCT Cust_ID 
	FROM e_commerce
	WHERE YEAR(Order_Date)=2011 AND MONTH(Order_Date)=01) subq  
	WHERE subq.Cust_ID=o.Cust_ID AND YEAR(Order_Date)=2011     -- Customer in January 2011 Has been filtered with subq
	GROUP BY o.Cust_ID, MONTH(o.Order_Date)
	)
SELECT MONTH, COUNT(DISTINCT Cust_ID) Cust_Retention
FROM t1
GROUP BY MONTH


-- It has been concluded that 94 customers who have placed order in Januray 2011 none of them placed order all other months continously

-------------------------


/*
for each user the time elapsed 
between the first purchasing and the third purchasing, in ascending order by Customer ID. 
*/

WITH T1 AS (
		SELECT c.Cust_ID, o.Ord_ID, o.Order_Date, 
			LEAD(o.Order_Date, 2) OVER(PARTITION BY c.Cust_ID ORDER BY Order_Date) Next_Order 
		FROM orders o
		INNER JOIN Customer c ON c.Cust_ID=o.Cust_ID), 
T2 AS (
		SELECT T1.Cust_ID, 
			MIN(Order_date) First_Order_Date
		FROM T1
		GROUP BY T1.Cust_ID)
SELECT t2.Cust_ID, t2.First_Order_Date, Next_Order AS Third_Order_Date, 
	   DATEDIFF(Day, t2.First_Order_Date, Next_Order) Date_Diff
FROM T1, T2
WHERE t1.Order_Date = t2.First_Order_Date
ORDER BY Cust_ID ASC



/* customers who purchased both product 11 and product 14, 
as well as the ratio of these products to the total number of products purchased by the customer. */


-- Total quantity ordered according to each customer and each product for t1
-- Total quantity ordered according to each customer for t1

WITH T1 AS (
SELECT DISTINCT c.Cust_ID, Prod_ID, 
	SUM(Order_Quantity) OVER(PARTITION BY Prod_ID, c.Cust_ID) AS Quantity_Product_by_Customer,  
	SUM(Order_Quantity) OVER(PARTITION BY c.Cust_ID) AS Total_Quantity_by_Customer
FROM orders AS o
INNER JOIN Customer AS c ON o.Cust_ID=c.Cust_ID
WHERE c.Cust_id IN                       -- customers who ordered products 11 and 14 
(
SELECT Cust_ID
FROM e_commerce
WHERE Prod_ID=14  
INTERSECT
SELECT Cust_ID
FROM e_commerce
WHERE Prod_ID=11)),    -- Total quantity of products 11-14 ordered by each customer
T2 AS 
(
SELECT cust_id, SUM(Quantity_Product_by_Customer) Total_11_14
FROM T1
WHERE prod_id IN (11,14)
GROUP BY cust_id
) -- ratio of order quantities of 11-14 over total ordered quantity by each customer
SELECT DISTINCT t1.Cust_ID, Total_11_14, Total_Quantity_by_Customer, 
	   CAST((1.0*Total_11_14)/(1.0*Total_Quantity_by_Customer) AS DECIMAL (10,2)) AS Rate
FROM T1, T2
WHERE T1.Cust_ID=t2.Cust_ID


--  Customer Segmentation

-- Montly Visit logs of customers 
GO
CREATE VIEW Montly_Visit_Log AS
SELECT Cust_ID, Year, Month
FROM (
SELECT  DISTINCT o.Cust_ID, o.ord_id, 
	YEAR(Order_date) Year, Month(o.Order_date) Month
FROM orders AS o
INNER JOIN Customer as c ON c.Cust_ID = o.Cust_ID) subq
GO

SELECT *
FROM Montly_Visit_Log
ORDER BY 1


--Montly Number of Visits Customers

CREATE VIEW Montly_Visits_users AS
SELECT  
	Year, Month, 
	COUNT(*) order_count
FROM Montly_Visit_Log
GROUP BY YEAR, Month
GO

SELECT *
FROM Montly_Visits_users
ORDER BY 1, 2

--- Next Customer Visit Calculation

CREATE VIEW next_log_customer AS 
SELECT  DISTINCT o.Cust_ID, o.order_date,
	YEAR(Order_date) Year, Month(Order_date) Month, 
	LEAD(Order_Date) OVER (PARTITION BY c.cust_id ORDER BY order_date) AS Next_Order
FROM orders AS o
INNER JOIN Customer as c ON c.Cust_ID = o.Cust_ID
GO

SELECT *
FROM next_log_customer
ORDER BY 1, 2


--- Montly Gap Calculation

CREATE VIEW Montly_Gap AS 
SELECT *,YEAR(Next_order) AS Next_order_year,
		 MONTH(Next_order) AS Next_order_month,
		 DATEDIFF(MONTH, order_date, Next_order) AS Montly_Gap
FROM [dbo].next_log_customer
GO

SELECT *
FROM Montly_Gap
ORDER BY 1,2 

-- Customer Type Categorisation

SELECT Cust_ID, COALESCE(Avg_Gap, -100) as AVG_Gap,
	CASE 
		WHEN Avg_Gap <= 5 THEN 'LOYAL'
		WHEN Avg_Gap >= 6 THEN 'NEED BASED'
		WHEN Avg_Gap IS NULL THEN 'CHURN'
	END AS Customer_Type 
FROM (
	SELECT Cust_ID, AVG(Montly_Gap) Avg_Gap
	FROM Montly_Gap
	GROUP BY Cust_ID
	) Avg_Montly_Gap
GO



-- Month-Wise Retention Rate 


-- Montly Number of retained customer
CREATE VIEW  Montly_Retained_Customers AS
	SELECT Next_order_year AS Year, Next_order_month AS Month, COUNT(Cust_ID) Retained_Customer
	FROM Montly_Gap
	WHERE Montly_Gap=1
	GROUP BY Next_order_year, Next_order_month
GO


SELECT *
FROM Montly_Retained_Customers
ORDER BY 1, 2


-- Number of customer visits in current mont
CREATE VIEW Curent_Month_Customer AS
	SELECT YEAR(order_date) Year, MONTH(Order_Date) Month, COUNT(DISTINCT Cust_ID) Current_Customer
	FROM orders
	GROUP BY YEAR(order_date), MONTH(Order_Date)
GO

SELECT *
FROM Curent_Month_Customer
ORDER BY 1, 2

-- Retention Rate Calculation
CREATE VIEW Montwise_Retention AS
	SELECT mrc.Year, crc.Month, Retained_Customer, Current_Customer, 
		CAST((1.0*Retained_Customer)/(1.0*Current_Customer) AS DECIMAL (10, 2)) AS Montly_Retention
	FROM Montly_Retained_Customers AS mrc, Curent_Month_Customer AS crc
	WHERE mrc.Year=crc.year AND mrc.Month=crc.Month
GO

SELECT *
FROM Montwise_Retention
ORDER BY 1, 2

---- Pivot Table For Month-Wise Customer Retention Rate
SELECT *
FROM (
	SELECT Year, Month, Montly_Retention
	FROM Montwise_Retention) Source_table
PIVOT(
	SUM(Montly_Retention)
	FOR YEAR IN ([2009], [2010], [2011],[2012])) AS pv_table







