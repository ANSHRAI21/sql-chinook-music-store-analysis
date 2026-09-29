-- =====================================================================
-- Chinook Digital Music Store: Business Analysis in SQL (SQLite)
-- Author: Ansh Rai
-- Concepts: JOINs, GROUP BY/HAVING, CTEs, window functions
--           (RANK, ROW_NUMBER, LAG, SUM OVER), CASE, subqueries, date functions
-- =====================================================================

-- Q1. Overall business KPIs
SELECT COUNT(DISTINCT i.InvoiceId)                       AS total_orders,
       COUNT(DISTINCT i.CustomerId)                      AS customers,
       ROUND(SUM(i.Total), 2)                            AS total_revenue,
       ROUND(SUM(i.Total) * 1.0 / COUNT(DISTINCT i.InvoiceId), 2) AS avg_order_value
FROM Invoice i;

-- Q2. Revenue by year with year-over-year growth (window function LAG)
WITH yearly AS (
    SELECT strftime('%Y', InvoiceDate) AS year, ROUND(SUM(Total), 2) AS revenue
    FROM Invoice GROUP BY year
)
SELECT year, revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY year)) * 100.0
             / LAG(revenue) OVER (ORDER BY year), 2) AS yoy_growth_pct
FROM yearly;

-- Q3. Top 10 countries by revenue, with share of total
SELECT BillingCountry AS country,
       COUNT(DISTINCT CustomerId) AS customers,
       ROUND(SUM(Total), 2) AS revenue,
       ROUND(SUM(Total) * 100.0 / (SELECT SUM(Total) FROM Invoice), 2) AS revenue_share_pct
FROM Invoice
GROUP BY BillingCountry
ORDER BY revenue DESC
LIMIT 10;

-- Q4. Best-selling genres by revenue and units
SELECT g.Name AS genre,
       SUM(il.Quantity) AS units_sold,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Genre g ON g.GenreId = t.GenreId
GROUP BY g.Name
ORDER BY revenue DESC
LIMIT 10;

-- Q5. Top 10 artists by revenue
SELECT ar.Name AS artist, ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
       COUNT(DISTINCT il.InvoiceId) AS orders
FROM InvoiceLine il
JOIN Track t  ON t.TrackId  = il.TrackId
JOIN Album al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY ar.Name
ORDER BY revenue DESC
LIMIT 10;

-- Q6. Top 10 customers by lifetime value, with their support rep
SELECT c.FirstName || ' ' || c.LastName AS customer, c.Country,
       e.FirstName || ' ' || e.LastName AS support_rep,
       ROUND(SUM(i.Total), 2) AS lifetime_value,
       COUNT(i.InvoiceId) AS orders
FROM Customer c
JOIN Invoice i  ON i.CustomerId = c.CustomerId
JOIN Employee e ON e.EmployeeId = c.SupportRepId
GROUP BY c.CustomerId
ORDER BY lifetime_value DESC
LIMIT 10;

-- Q7. Sales performance of each support agent
SELECT e.FirstName || ' ' || e.LastName AS sales_agent, e.HireDate,
       COUNT(DISTINCT c.CustomerId) AS customers_managed,
       ROUND(SUM(i.Total), 2) AS revenue,
       RANK() OVER (ORDER BY SUM(i.Total) DESC) AS revenue_rank
FROM Employee e
JOIN Customer c ON c.SupportRepId = e.EmployeeId
JOIN Invoice i  ON i.CustomerId  = c.CustomerId
GROUP BY e.EmployeeId;

-- Q8. Most popular genre in each country (ROW_NUMBER to pick the top genre)
WITH genre_country AS (
    SELECT i.BillingCountry AS country, g.Name AS genre, SUM(il.Quantity) AS units,
           ROW_NUMBER() OVER (PARTITION BY i.BillingCountry ORDER BY SUM(il.Quantity) DESC) AS rn
    FROM InvoiceLine il
    JOIN Invoice i ON i.InvoiceId = il.InvoiceId
    JOIN Track t   ON t.TrackId   = il.TrackId
    JOIN Genre g   ON g.GenreId   = t.GenreId
    GROUP BY country, genre
)
SELECT country, genre AS top_genre, units
FROM genre_country WHERE rn = 1
ORDER BY units DESC
LIMIT 10;

-- Q9. Monthly revenue with running total (cumulative SUM OVER) for 2025
SELECT strftime('%Y-%m', InvoiceDate) AS month,
       ROUND(SUM(Total), 2) AS revenue,
       ROUND(SUM(SUM(Total)) OVER (ORDER BY strftime('%Y-%m', InvoiceDate)), 2) AS running_total
FROM Invoice
WHERE strftime('%Y', InvoiceDate) = '2025'
GROUP BY month;

-- Q10. Customer segmentation by lifetime value (CASE)
WITH ltv AS (
    SELECT CustomerId, SUM(Total) AS value FROM Invoice GROUP BY CustomerId
)
SELECT CASE WHEN value >= 45 THEN 'High (>= $45)'
            WHEN value >= 38 THEN 'Medium ($38-45)'
            ELSE 'Low (< $38)' END AS segment,
       COUNT(*) AS customers,
       ROUND(AVG(value), 2) AS avg_value,
       ROUND(SUM(value), 2) AS revenue
FROM ltv
GROUP BY segment
ORDER BY avg_value DESC;

-- Q11. Media type share: do customers still buy MPEG audio files?
SELECT m.Name AS media_type, SUM(il.Quantity) AS units,
       ROUND(SUM(il.Quantity) * 100.0 / (SELECT SUM(Quantity) FROM InvoiceLine), 2) AS unit_share_pct
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN MediaType m ON m.MediaTypeId = t.MediaTypeId
GROUP BY m.Name
ORDER BY units DESC;

-- Q12. Catalogue health: how many tracks have never been sold?
SELECT COUNT(*) AS total_tracks,
       SUM(CASE WHEN il.TrackId IS NULL THEN 1 ELSE 0 END) AS never_sold,
       ROUND(SUM(CASE WHEN il.TrackId IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS never_sold_pct
FROM Track t
LEFT JOIN (SELECT DISTINCT TrackId FROM InvoiceLine) il ON il.TrackId = t.TrackId;

-- Q13. Albums bought in full vs individual tracks
WITH invoice_album AS (
    SELECT il.InvoiceId, t.AlbumId, COUNT(*) AS tracks_bought
    FROM InvoiceLine il JOIN Track t ON t.TrackId = il.TrackId
    GROUP BY il.InvoiceId, t.AlbumId
), album_size AS (
    SELECT AlbumId, COUNT(*) AS album_tracks FROM Track GROUP BY AlbumId
)
SELECT CASE WHEN ia.tracks_bought = a.album_tracks THEN 'Full album' ELSE 'Individual tracks' END AS purchase_type,
       COUNT(*) AS invoice_album_combos,
       ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM invoice_album), 2) AS pct
FROM invoice_album ia JOIN album_size a ON a.AlbumId = ia.AlbumId
GROUP BY purchase_type;

-- Q14. Quarterly revenue trend by year (pivot with CASE)
SELECT strftime('%Y', InvoiceDate) AS year,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 1 AND 3  THEN Total END), 2) AS Q1,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 4 AND 6  THEN Total END), 2) AS Q2,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 7 AND 9  THEN Total END), 2) AS Q3,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 10 AND 12 THEN Total END), 2) AS Q4
FROM Invoice GROUP BY year;

-- Q15. Customers whose spend is above their country's average (correlated subquery)
SELECT c.FirstName || ' ' || c.LastName AS customer, c.Country, ROUND(SUM(i.Total), 2) AS spend
FROM Customer c JOIN Invoice i ON i.CustomerId = c.CustomerId
GROUP BY c.CustomerId
HAVING SUM(i.Total) > (
    SELECT AVG(cust_total) FROM (
        SELECT SUM(i2.Total) AS cust_total
        FROM Invoice i2 JOIN Customer c2 ON c2.CustomerId = i2.CustomerId
        WHERE c2.Country = c.Country GROUP BY c2.CustomerId))
ORDER BY spend DESC
LIMIT 10;
