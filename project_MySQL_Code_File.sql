-- Objective Questions

-- 1.	Does any table have missing values or duplicates? If yes how would you handle it ?

--  for checking null values -- 
SELECT "album" AS table_name,
       SUM(CASE WHEN `album_id` IS NULL THEN 1 ELSE 0 END) AS album_id_nulls,
       SUM(CASE WHEN `title` IS NULL THEN 1 ELSE 0 END) AS title_nulls,
       SUM(CASE WHEN `artist_id` IS NULL THEN 1 ELSE 0 END) AS artist_id_nulls
FROM album;

-- for checking duplicates --  
SELECT 
    album_id,
    title,
    artist_id,
    COUNT(*) AS cnt
FROM album
GROUP BY album_id, title, artist_id
HAVING COUNT(*) > 1;

-- 2.	Find the top-selling tracks and top artist in the USA and identify their most famous genres.

WITH topSellingTrackandArtist AS (
	SELECT 
		t.name AS track_name,
        a.name AS artist_name,
        g.name AS genre_name,
        SUM(i.total) AS total_sales,
        COUNT(g.genre_id) AS genre_count,
        RANK() OVER(ORDER BY SUM(i.total) DESC) AS sales_rank
	FROM invoice i 
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist a ON al.artist_id = a.artist_id
    JOIN genre g ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
	GROUP BY t.name,a.name,g.name
    
),
MaxGenreCount AS (
	SELECT MAX(c) AS famous_genre FROM ( SELECT COUNT(DISTINCT genre_id) AS c FROM track t ) sub
)
SELECT * FROM topSellingTrackandArtist ORDER BY total_sales DESC;


-- 3.	What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?

SELECT 
	country,
	COALESCE(state,'N/A') AS state,
	city, 
	COUNT(customer_id) AS cust_count
FROM customer 
GROUP BY country, state, city
ORDER BY country ;

-- 4.	Calculate the total revenue and number of invoices for each country, state, and city:

SELECT 
	billing_country,
    billing_state,
    billing_city,
    SUM(total) AS total_revenue,
    COUNT(invoice_id) AS total_invoices
FROM invoice
GROUP BY billing_country, billing_state, billing_city
ORDER BY billing_country ASC,total_revenue DESC;

-- 5.	Find the top 5 customers by total revenue in each country

WITH customer_revenue AS (
    SELECT c.customer_id,
           CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
           c.country,
           SUM(i.total) AS total_revenue
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, customer_name, c.country
)
SELECT customer_name, country, total_revenue
FROM (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY country ORDER BY total_revenue DESC) AS rn
    FROM customer_revenue
) ranked
WHERE rn <= 5
ORDER BY country, total_revenue DESC;

-- 6.	Identify the top-selling track for each customer

WITH Customer_Track_Sales AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        t.track_id,
        t.name AS track_name,
        SUM(il.quantity) AS total_quantity,
        SUM(i.total) AS total_sales,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_id
            ORDER BY SUM(i.total) DESC
        ) AS sales_rank
    FROM customer c
    LEFT JOIN invoice i 
        ON c.customer_id = i.customer_id
    LEFT JOIN invoice_line il 
        ON i.invoice_id = il.invoice_id
    LEFT JOIN track t 
        ON il.track_id = t.track_id
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name,
        t.track_id,
        t.name
)
SELECT
    customer_id,
    CONCAT(first_name, ' ', last_name) AS customer_name,
    track_id,
    track_name,
    total_quantity,
    total_sales
FROM Customer_Track_Sales
WHERE sales_rank = 1
ORDER BY total_sales DESC;


-- 7.	Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?

-- frequency of purchases

WITH PurchaseFrequency AS (
	SELECT 
		c.customer_id, 
        CONCAT(c.first_name,' ',c.last_name) AS customer_name, 
		COUNT(i.invoice_id) AS total_purchases, 
		MIN(DATE(i.invoice_date)) AS first_purchase_date, 
		MAX(DATE(i.invoice_date)) AS latest_purchase_date,
		ROUND(
			DATEDIFF(MAX(DATE(i.invoice_date)),MIN(DATE(i.invoice_date))) / 
            COALESCE(COUNT(i.invoice_id)-1, 0),0) AS avg_days_bet_purchases
	FROM customer c 
	JOIN invoice i ON c.customer_id = i.customer_id
	GROUP BY customer_id , customer_name
)
SELECT * FROM PurchaseFrequency
ORDER BY avg_days_bet_purchases, total_purchases DESC;

-- Average Order Value

WITH Customer_Purchases AS (
	SELECT 
		c.customer_id,
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
		SUM(i.total) AS total_order_value, 
        COUNT(i.invoice_id) AS total_purchases,
        ROUND(AVG(i.total), 2) AS avg_order_value
	FROM customer c 
    LEFT JOIN invoice i 
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, customer_name
)
SELECT * 
FROM Customer_Purchases
ORDER BY avg_order_value DESC;


-- 8.	What is the customer churn rate?

WITH last_purchase AS (
    SELECT 
        c.customer_id,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    LEFT JOIN invoice i 
        ON c.customer_id = i.customer_id
    GROUP BY c.customer_id
),
max_date AS (
    SELECT MAX(invoice_date) AS dataset_last_date
    FROM invoice
)
SELECT
    COUNT(*) AS total_customers,
    SUM(CASE 
        WHEN lp.last_purchase_date < DATE_SUB(md.dataset_last_date, INTERVAL 6 MONTH)
        THEN 1 ELSE 0 
    END) AS churned_customers,
    SUM(CASE 
        WHEN lp.last_purchase_date >= DATE_SUB(md.dataset_last_date, INTERVAL 6 MONTH)
        THEN 1 ELSE 0 
    END) AS active_customers,
    ROUND(
        SUM(CASE 
            WHEN lp.last_purchase_date < DATE_SUB(md.dataset_last_date, INTERVAL 6 MONTH)
            THEN 1 ELSE 0 
        END) * 100.0 / COUNT(*), 2
    ) AS churn_rate_percentage
FROM last_purchase lp
CROSS JOIN max_date md;


-- 9.	Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.

WITH Sales_Genre_Rank_USA AS (
	SELECT
		g.name AS genre, ar.name AS artist, SUM(i.total) AS genre_sales,
        DENSE_RANK() OVER( PARTITION BY g.name ORDER BY SUM(i.total) DESC) AS genre_rank	
	FROM genre g
    LEFT JOIN track t ON g.genre_id = t.genre_id
    LEFT JOIN invoice_line il ON t.track_id = il.track_id
    LEFT JOIN invoice i ON il.invoice_id = i.invoice_id
    LEFT JOIN album a ON t.album_id = a.album_id
    LEFT JOIN artist ar ON a.artist_id = ar.artist_id
    WHERE i.billing_country = 'USA'
    GROUP BY genre , artist
),
Total_Sales_USA AS (
	SELECT 
		SUM(i.total) AS total_sales
	FROM invoice_line il 
    LEFT JOIN invoice i ON il.invoice_id = i.invoice_id
    WHERE i.billing_country = 'USA'
)
SELECT s.genre,s.artist,s.genre_sales,t.total_sales, ROUND((s.genre_sales / t.total_sales)* 100,2) AS percent_sales
FROM Sales_Genre_Rank_USA s JOIN Total_Sales_USA t
ORDER BY s.genre_sales DESC, s.genre ASC;

-- 10.	Find customers who have purchased tracks from at least 3 different genres

SELECT 
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    COUNT(DISTINCT t.genre_id) AS distinct_genres_purchased
FROM customer c
JOIN invoice i 
    ON c.customer_id = i.customer_id
JOIN invoice_line il 
    ON i.invoice_id = il.invoice_id
JOIN track t 
    ON il.track_id = t.track_id
GROUP BY c.customer_id, customer_name
HAVING COUNT(DISTINCT t.genre_id) >= 3
ORDER BY distinct_genres_purchased DESC;

-- 11.	Rank genres based on their sales performance in the USA

WITH usa_genre_sales AS (
    SELECT
        g.genre_id,
        g.name AS genre_name,
        SUM(il.unit_price * il.quantity) AS total_sales
    FROM invoice i
    JOIN invoice_line il 
        ON i.invoice_id = il.invoice_id
    JOIN track t 
        ON il.track_id = t.track_id
    JOIN genre g 
        ON t.genre_id = g.genre_id
    WHERE i.billing_country = 'USA'
    GROUP BY g.genre_id, g.name
),

ranked_genres AS (
    SELECT
        genre_name,
        total_sales,
        RANK() OVER (ORDER BY total_sales DESC) AS genre_rank
    FROM usa_genre_sales
)

SELECT *
FROM ranked_genres
ORDER BY genre_rank;

-- 12.	Identify customers who have not made a purchase in the last 3 months

WITH CustomerLastPurchase AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        MIN(DATE(i.invoice_date)) AS first_purchase_date,
        MAX(DATE(i.invoice_date)) AS last_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.first_name, c.last_name
),
CustomerPurchases AS (
    SELECT 
        c.customer_id,
        c.first_name,
        c.last_name,
        DATE(i.invoice_date) AS invoice_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
)
SELECT 
    clp.customer_id, 
    clp.first_name, 
    clp.last_name, 
    clp.first_purchase_date,
    clp.last_purchase_date
FROM CustomerLastPurchase clp
LEFT JOIN CustomerPurchases cp ON clp.customer_id = cp.customer_id 
AND cp.invoice_date BETWEEN clp.last_purchase_date - INTERVAL 3 MONTH AND clp.last_purchase_date - INTERVAL 1 DAY
WHERE cp.invoice_date IS NULL
ORDER BY clp.customer_id;



-- Subjective Questions


-- 1.	Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

SELECT 
    al.title AS album_name,
    g.name AS genre_name,
    SUM(il.quantity * il.unit_price) AS total_sales_usa
FROM invoice i
JOIN invoice_line il 
    ON i.invoice_id = il.invoice_id
JOIN track t 
    ON il.track_id = t.track_id
JOIN album al 
    ON t.album_id = al.album_id
JOIN genre g 
    ON t.genre_id = g.genre_id
WHERE i.billing_country = 'USA'
GROUP BY al.album_id, al.title, g.name
ORDER BY total_sales_usa DESC
LIMIT 3;

-- 2.	Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

-- -- Top Selling Genres in countries other than USA? -- --
SELECT
	g.genre_id,
    g.name AS genre_name,
    c.country,
    SUM(il.quantity) AS quantity_sold
FROM
	genre g 
    INNER JOIN track t ON g.genre_id = t.genre_id
	INNER JOIN invoice_line il ON t.track_id = il.track_id
    INNER JOIN invoice i ON il.invoice_id = i.invoice_id
	INNER JOIN customer c ON i.customer_id = c.customer_id 
WHERE 
	country <> 'USA'
GROUP BY
	g.genre_id, genre_name, c.country
ORDER BY 
	quantity_sold DESC;

-- -- Top Selling Genres in countries in USA? -- --
SELECT
	g.genre_id,
    g.name AS genre_name,
    c.country,
    SUM(il.quantity) AS quantity_sold
FROM
	genre g 
    INNER JOIN track t ON g.genre_id = t.genre_id
	INNER JOIN invoice_line il ON t.track_id = il.track_id
    INNER JOIN invoice i ON il.invoice_id = i.invoice_id
	INNER JOIN customer c ON i.customer_id = c.customer_id 
WHERE 
	country = 'USA'
GROUP BY
	g.genre_id, genre_name, c.country
ORDER BY 
	quantity_sold DESC;

-- 3.	Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

-- Customer First Purchase Date

SELECT 
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS full_names,
    MIN(DATE(i.invoice_date)) AS first_payment
FROM customer c
JOIN invoice i 
    ON c.customer_id = i.customer_id
GROUP BY 
    c.customer_id,
    full_names
ORDER BY 
    first_payment DESC;

-- Long-Term vs New Customer Purchasing Behavior

SELECT 
    CASE
        WHEN YEAR(i.invoice_date) IN (2017, 2018)
            THEN 'Long-Term Users'
        ELSE 'New Users'
    END AS customer_type,
    
    COUNT(DISTINCT i.invoice_id) AS total_orders,
    SUM(i.total) AS spending_amount,
    AVG(i.total) AS avg_spent_value
FROM invoice i
JOIN customer c
    ON i.customer_id = c.customer_id
GROUP BY 
    customer_type;



-- 4.	Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?

-- Top Genre Pairs Purchased Together

WITH invoice_genres AS (
    SELECT 
        i.invoice_id,
        g.name AS genre
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN genre g ON t.genre_id = g.genre_id
),
genre_pairs AS (
    SELECT 
        ig1.genre AS genre_1,
        ig2.genre AS genre_2,
        COUNT(DISTINCT ig1.invoice_id) AS frequency
    FROM invoice_genres ig1
    JOIN invoice_genres ig2 
        ON ig1.invoice_id = ig2.invoice_id
        AND ig1.genre < ig2.genre
    GROUP BY ig1.genre, ig2.genre
)
SELECT * 
FROM genre_pairs
ORDER BY frequency DESC
LIMIT 10;

-- Top Artist Pairs Purchased Together

WITH invoice_artists AS (
    SELECT 
        i.invoice_id,
        ar.artist_id,
        ar.name AS artist_name
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
    JOIN artist ar ON al.artist_id = ar.artist_id
),
artist_pairs AS (
    SELECT 
        ia1.artist_name AS artist_1,
        ia2.artist_name AS artist_2,
        COUNT(DISTINCT ia1.invoice_id) AS frequency
    FROM invoice_artists ia1
    JOIN invoice_artists ia2 
        ON ia1.invoice_id = ia2.invoice_id
        AND ia1.artist_id < ia2.artist_id
    GROUP BY ia1.artist_name, ia2.artist_name
)
SELECT * 
FROM artist_pairs
ORDER BY frequency DESC
LIMIT 10;

-- Top Album Pairs Purchased Together

WITH invoice_albums AS (
    SELECT 
        i.invoice_id,
        al.album_id,
        al.title AS album_title
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    JOIN track t ON il.track_id = t.track_id
    JOIN album al ON t.album_id = al.album_id
),
album_pairs AS (
    SELECT 
        ia1.album_title AS album_1,
        ia2.album_title AS album_2,
        COUNT(DISTINCT ia1.invoice_id) AS frequency
    FROM invoice_albums ia1
    JOIN invoice_albums ia2 
        ON ia1.invoice_id = ia2.invoice_id
        AND ia1.album_id < ia2.album_id
    GROUP BY ia1.album_title, ia2.album_title
)
SELECT * 
FROM album_pairs
ORDER BY frequency DESC
LIMIT 10;

-- 5.	Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?

-- Customer Purchasing Behaviors by Region
-- Step 1: Calculate purchase metrics per customer

WITH purchase_frequency AS (
    SELECT customer_id,COUNT(invoice_id) AS total_purchase_freq,
        SUM(total) AS total_spending,AVG(total) AS avg_order_value
    FROM invoice
    GROUP BY customer_id
),
-- Step 2: Combine customer info with their purchase metrics

customer_region_summary AS (
    SELECT c.customer_id,c.country,COALESCE(c.state,'N.A') AS state,c.city,pf.total_purchase_freq,
        pf.total_spending,pf.avg_order_value
    FROM customer c
    JOIN purchase_frequency pf ON c.customer_id = pf.customer_id
),
-- Step 3: Aggregate metrics at the region (country/state/city) level

regional_summary AS (
    SELECT country,state,city,
        COUNT(DISTINCT customer_id) AS total_customers,
        SUM(total_purchase_freq) AS total_purchases,
        SUM(total_spending) AS total_spending,
        ROUND(AVG(avg_order_value),2) AS avg_order_value,
        ROUND(AVG(total_purchase_freq),2) AS avg_purchase_frequency
    FROM customer_region_summary
    GROUP BY country, state, city
)
-- Step 4: Final output of purchasing behavior per region

SELECT *
FROM regional_summary
ORDER BY total_spending DESC;

-- Customer Churn Rate by Region
-- Step 1: Find the last invoice date in the dataset

WITH max_invoice_date AS (
    SELECT MAX(invoice_date) AS dataset_last_date
    FROM invoice
),
-- Step 2: Get each customer's last purchase date

last_purchase AS (
    SELECT c.customer_id,c.country,COALESCE(c.state,'N.A') AS state,c.city,
        MAX(i.invoice_date) AS last_purchase_date
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, c.country, c.state, c.city
),
-- Step 3: Identify customers who have not purchased in the last 6 months

churned_customers AS (
    SELECT lp.country,lp.state,lp.city,
        COUNT(lp.customer_id) AS churned_customers
    FROM last_purchase lp
    CROSS JOIN max_invoice_date md
    WHERE lp.last_purchase_date < DATE_SUB(md.dataset_last_date, INTERVAL 6 MONTH)
    GROUP BY lp.country, lp.state, lp.city
)
-- Step 4: Calculate churn rate per region

SELECT cc.country,cc.state,cc.city,cc.churned_customers,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    ROUND((cc.churned_customers / COUNT(DISTINCT c.customer_id)) * 100,2) AS churn_rate
FROM churned_customers cc
JOIN customer c ON cc.country = c.country
   AND cc.state = COALESCE(c.state,'N.A')
   AND cc.city = c.city
GROUP BY cc.country, cc.state, cc.city
ORDER BY churn_rate DESC;


-- 6.	Customer Risk Profiling: Based on customer profiles (age, gender, location, purchase history), which customer segments are more likely to churn or pose a higher risk of reduced spending? What factors contribute to this risk?

-- Step 1: Find each customer's last purchase date
WITH last_purchase AS (
    SELECT customer_id,MAX(DATE(invoice_date)) AS last_bought
    FROM invoice
    GROUP BY customer_id
),
-- Step 2: Assign churn / risk status using a 90-day rule
churn_status AS (
    SELECT lp.customer_id,lp.last_bought,
        CASE
            WHEN lp.last_bought < DATE_SUB((SELECT MAX(DATE(invoice_date)) FROM invoice),INTERVAL 90 DAY)
            THEN 'High Risk - Churned'ELSE 'Low Risk - Active'
        END AS risk_status
    FROM last_purchase lp
),
-- Step 3: Calculate customer spending behavior
customer_spending AS (
    SELECT i.customer_id,c.country,
        COUNT(i.invoice_id) AS total_orders,SUM(i.total) AS total_spent,
        ROUND(AVG(i.total), 2) AS avg_order_value
    FROM invoice i
    JOIN customer c ON i.customer_id = c.customer_id
    GROUP BY i.customer_id, c.country
)
-- Step 4: Combine risk status with spending profile
SELECT 
    cs.customer_id,cs.country,cs.total_orders,
    cs.total_spent,cs.avg_order_value,cr.risk_status
FROM customer_spending cs
JOIN churn_status cr ON cs.customer_id = cr.customer_id
ORDER BY 
    cr.risk_status DESC,cs.total_spent ASC;

-- 7.	Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments?
-- This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

-- Build complete customer-level metrics for CLV analysis
WITH full_customer_details AS (
    SELECT c.customer_id,CONCAT(c.first_name,' ', c.last_name) AS user_name,
        MIN(DATE(i.invoice_date)) AS first_purchase,MAX(DATE(i.invoice_date)) AS last_purchase,
        DATEDIFF(MAX(DATE(i.invoice_date)),MIN(DATE(i.invoice_date))) AS tenure_days,
		SUM(i.total) AS total_spend,AVG(i.total) AS avg_spend,COUNT(i.invoice_id) AS purchase_frequency
    FROM customer c
    JOIN invoice i ON c.customer_id = i.customer_id
    GROUP BY c.customer_id, user_name
),
-- Identify customers who purchased in the last 90 days
active_customers AS (
    SELECT DISTINCT customer_id
    FROM invoice
    WHERE invoice_date >= DATE_SUB('2020-12-30', INTERVAL 90 DAY)
),
-- Assign customer status based on recent activity
final_cte AS (
    SELECT fcd.*,
        CASE 
            WHEN fcd.customer_id IN (SELECT customer_id FROM active_customers)
            THEN 'Active'ELSE 'Churned'END AS customer_status
    FROM full_customer_details fcd
)
SELECT *
FROM final_cte
ORDER BY total_spend DESC, tenure_days DESC;

-- 8.	If data on promotional campaigns (discounts, events, email marketing) is available, how could you measure their impact on customer acquisition, retention, and overall sales?

-- Answer in word file

-- 9.	How would you approach this problem, if the objective and subjective questions weren't given?

-- Answer in word file

-- 10.	How can you alter the "Albums" table to add a new column named "ReleaseYear" of type INTEGER to store the release year of each album?

ALTER TABLE Albums
ADD ReleaseYear INTEGER;

-- 11.	Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country,
-- along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.

WITH customer_purchase_summary AS (
    SELECT i.customer_id,SUM(i.total) AS total_spent,COUNT(il.track_id) AS total_tracks
    FROM invoice i
    JOIN invoice_line il ON i.invoice_id = il.invoice_id
    GROUP BY i.customer_id
),
country_level_metrics AS (
    SELECT c.country,c.customer_id,cps.total_spent,cps.total_tracks
    FROM customer c
    JOIN customer_purchase_summary cps ON c.customer_id = cps.customer_id
)
SELECT
    country,COUNT(DISTINCT customer_id) AS number_of_customers,
	ROUND(AVG(total_spent), 2) AS avg_total_spent_per_customer,ROUND(AVG(total_tracks), 2) AS avg_tracks_per_customer
FROM country_level_metrics
GROUP BY country
ORDER BY avg_total_spent_per_customer DESC;














