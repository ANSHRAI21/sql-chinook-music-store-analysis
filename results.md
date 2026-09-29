# Query Results

Every result below comes from running `sql/analysis_queries.sql` against `data/chinook.sqlite` (SQLite 3).


## Q1. Overall business KPIs

```sql
SELECT COUNT(DISTINCT i.InvoiceId)                       AS total_orders,
       COUNT(DISTINCT i.CustomerId)                      AS customers,
       ROUND(SUM(i.Total), 2)                            AS total_revenue,
       ROUND(SUM(i.Total) * 1.0 / COUNT(DISTINCT i.InvoiceId), 2) AS avg_order_value
FROM Invoice i;
```

|   total_orders |   customers |   total_revenue |   avg_order_value |
|---------------:|------------:|----------------:|------------------:|
|            412 |          59 |          2328.6 |              5.65 |


## Q2. Revenue by year with year-over-year growth (window function LAG)

```sql
WITH yearly AS (
    SELECT strftime('%Y', InvoiceDate) AS year, ROUND(SUM(Total), 2) AS revenue
    FROM Invoice GROUP BY year
)
SELECT year, revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY year)) * 100.0
             / LAG(revenue) OVER (ORDER BY year), 2) AS yoy_growth_pct
FROM yearly;
```

|   year |   revenue |   yoy_growth_pct |
|-------:|----------:|-----------------:|
|   2021 |    449.46 |           nan    |
|   2022 |    481.45 |             7.12 |
|   2023 |    469.58 |            -2.47 |
|   2024 |    477.53 |             1.69 |
|   2025 |    450.58 |            -5.64 |


## Q3. Top 10 countries by revenue, with share of total

```sql
SELECT BillingCountry AS country,
       COUNT(DISTINCT CustomerId) AS customers,
       ROUND(SUM(Total), 2) AS revenue,
       ROUND(SUM(Total) * 100.0 / (SELECT SUM(Total) FROM Invoice), 2) AS revenue_share_pct
FROM Invoice
GROUP BY BillingCountry
ORDER BY revenue DESC
LIMIT 10;
```

| country        |   customers |   revenue |   revenue_share_pct |
|:---------------|------------:|----------:|--------------------:|
| USA            |          13 |    523.06 |               22.46 |
| Canada         |           8 |    303.96 |               13.05 |
| France         |           5 |    195.1  |                8.38 |
| Brazil         |           5 |    190.1  |                8.16 |
| Germany        |           4 |    156.48 |                6.72 |
| United Kingdom |           3 |    112.86 |                4.85 |
| Czech Republic |           2 |     90.24 |                3.88 |
| Portugal       |           2 |     77.24 |                3.32 |
| India          |           2 |     75.26 |                3.23 |
| Chile          |           1 |     46.62 |                2    |


## Q4. Best-selling genres by revenue and units

```sql
SELECT g.Name AS genre,
       SUM(il.Quantity) AS units_sold,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Genre g ON g.GenreId = t.GenreId
GROUP BY g.Name
ORDER BY revenue DESC
LIMIT 10;
```

| genre              |   units_sold |   revenue |
|:-------------------|-------------:|----------:|
| Rock               |          835 |    826.65 |
| Latin              |          386 |    382.14 |
| Metal              |          264 |    261.36 |
| Alternative & Punk |          244 |    241.56 |
| TV Shows           |           47 |     93.53 |
| Jazz               |           80 |     79.2  |
| Blues              |           61 |     60.39 |
| Drama              |           29 |     57.71 |
| R&B/Soul           |           41 |     40.59 |
| Classical          |           41 |     40.59 |


## Q5. Top 10 artists by revenue

```sql
SELECT ar.Name AS artist, ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
       COUNT(DISTINCT il.InvoiceId) AS orders
FROM InvoiceLine il
JOIN Track t  ON t.TrackId  = il.TrackId
JOIN Album al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY ar.Name
ORDER BY revenue DESC
LIMIT 10;
```

| artist                  |   revenue |   orders |
|:------------------------|----------:|---------:|
| Iron Maiden             |    138.6  |       30 |
| U2                      |    105.93 |       32 |
| Metallica               |     90.09 |       28 |
| Led Zeppelin            |     86.13 |       28 |
| Lost                    |     81.59 |       12 |
| The Office              |     49.75 |       10 |
| Os Paralamas Do Sucesso |     44.55 |       16 |
| Deep Purple             |     43.56 |       10 |
| Faith No More           |     41.58 |       11 |
| Eric Clapton            |     39.6  |       17 |


## Q6. Top 10 customers by lifetime value, with their support rep

```sql
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
```

| customer           | Country        | support_rep   |   lifetime_value |   orders |
|:-------------------|:---------------|:--------------|-----------------:|---------:|
| Helena Holý        | Czech Republic | Steve Johnson |            49.62 |        7 |
| Richard Cunningham | USA            | Margaret Park |            47.62 |        7 |
| Luis Rojas         | Chile          | Steve Johnson |            46.62 |        7 |
| Ladislav Kovács    | Hungary        | Jane Peacock  |            45.62 |        7 |
| Hugh O'Reilly      | Ireland        | Jane Peacock  |            45.62 |        7 |
| Frank Ralston      | USA            | Jane Peacock  |            43.62 |        7 |
| Julia Barnett      | USA            | Steve Johnson |            43.62 |        7 |
| Fynn Zimmermann    | Germany        | Jane Peacock  |            43.62 |        7 |
| Astrid Gruber      | Austria        | Steve Johnson |            42.62 |        7 |
| Victor Stevens     | USA            | Steve Johnson |            42.62 |        7 |


## Q7. Sales performance of each support agent

```sql
SELECT e.FirstName || ' ' || e.LastName AS sales_agent, e.HireDate,
       COUNT(DISTINCT c.CustomerId) AS customers_managed,
       ROUND(SUM(i.Total), 2) AS revenue,
       RANK() OVER (ORDER BY SUM(i.Total) DESC) AS revenue_rank
FROM Employee e
JOIN Customer c ON c.SupportRepId = e.EmployeeId
JOIN Invoice i  ON i.CustomerId  = c.CustomerId
GROUP BY e.EmployeeId;
```

| sales_agent   | HireDate            |   customers_managed |   revenue |   revenue_rank |
|:--------------|:--------------------|--------------------:|----------:|---------------:|
| Jane Peacock  | 2002-04-01 00:00:00 |                  21 |    833.04 |              1 |
| Margaret Park | 2003-05-03 00:00:00 |                  20 |    775.4  |              2 |
| Steve Johnson | 2003-10-17 00:00:00 |                  18 |    720.16 |              3 |


## Q8. Most popular genre in each country (ROW_NUMBER to pick the top genre)

```sql
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
```

| country        | top_genre   |   units |
|:---------------|:------------|--------:|
| USA            | Rock        |     157 |
| Canada         | Rock        |     107 |
| Brazil         | Rock        |      81 |
| France         | Rock        |      65 |
| Germany        | Rock        |      62 |
| United Kingdom | Rock        |      37 |
| Portugal       | Rock        |      31 |
| Czech Republic | Rock        |      25 |
| India          | Rock        |      25 |
| Australia      | Rock        |      22 |


## Q9. Monthly revenue with running total (cumulative SUM OVER) for 2025

```sql
SELECT strftime('%Y-%m', InvoiceDate) AS month,
       ROUND(SUM(Total), 2) AS revenue,
       ROUND(SUM(SUM(Total)) OVER (ORDER BY strftime('%Y-%m', InvoiceDate)), 2) AS running_total
FROM Invoice
WHERE strftime('%Y', InvoiceDate) = '2025'
GROUP BY month;
```

| month   |   revenue |   running_total |
|:--------|----------:|----------------:|
| 2025-01 |     37.62 |           37.62 |
| 2025-02 |     27.72 |           65.34 |
| 2025-03 |     37.62 |          102.96 |
| 2025-04 |     33.66 |          136.62 |
| 2025-05 |     37.62 |          174.24 |
| 2025-06 |     37.62 |          211.86 |
| 2025-07 |     37.62 |          249.48 |
| 2025-08 |     37.62 |          287.1  |
| 2025-09 |     37.62 |          324.72 |
| 2025-10 |     37.62 |          362.34 |
| 2025-11 |     49.62 |          411.96 |
| 2025-12 |     38.62 |          450.58 |


## Q10. Customer segmentation by lifetime value (CASE)

```sql
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
```

| segment         |   customers |   avg_value |   revenue |
|:----------------|------------:|------------:|----------:|
| High (>= $45)   |           5 |       47.02 |    235.1  |
| Medium ($38-45) |          23 |       40.36 |    928.26 |
| Low (< $38)     |          31 |       37.59 |   1165.24 |


## Q11. Media type share: do customers still buy MPEG audio files?

```sql
SELECT m.Name AS media_type, SUM(il.Quantity) AS units,
       ROUND(SUM(il.Quantity) * 100.0 / (SELECT SUM(Quantity) FROM InvoiceLine), 2) AS unit_share_pct
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN MediaType m ON m.MediaTypeId = t.MediaTypeId
GROUP BY m.Name
ORDER BY units DESC;
```

| media_type                  |   units |   unit_share_pct |
|:----------------------------|--------:|-----------------:|
| MPEG audio file             |    1976 |            88.21 |
| Protected AAC audio file    |     146 |             6.52 |
| Protected MPEG-4 video file |     111 |             4.96 |
| Purchased AAC audio file    |       4 |             0.18 |
| AAC audio file              |       3 |             0.13 |


## Q12. Catalogue health: how many tracks have never been sold?

```sql
SELECT COUNT(*) AS total_tracks,
       SUM(CASE WHEN il.TrackId IS NULL THEN 1 ELSE 0 END) AS never_sold,
       ROUND(SUM(CASE WHEN il.TrackId IS NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS never_sold_pct
FROM Track t
LEFT JOIN (SELECT DISTINCT TrackId FROM InvoiceLine) il ON il.TrackId = t.TrackId;
```

|   total_tracks |   never_sold |   never_sold_pct |
|---------------:|-------------:|-----------------:|
|           3503 |         1519 |            43.36 |


## Q13. Albums bought in full vs individual tracks

```sql
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
```

| purchase_type     |   invoice_album_combos |   pct |
|:------------------|-----------------------:|------:|
| Full album        |                     49 |  3.76 |
| Individual tracks |                   1254 | 96.24 |


## Q14. Quarterly revenue trend by year (pivot with CASE)

```sql
SELECT strftime('%Y', InvoiceDate) AS year,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 1 AND 3  THEN Total END), 2) AS Q1,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 4 AND 6  THEN Total END), 2) AS Q2,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 7 AND 9  THEN Total END), 2) AS Q3,
       ROUND(SUM(CASE WHEN CAST(strftime('%m', InvoiceDate) AS INT) BETWEEN 10 AND 12 THEN Total END), 2) AS Q4
FROM Invoice GROUP BY year;
```

|   year |     Q1 |     Q2 |     Q3 |     Q4 |
|-------:|-------:|-------:|-------:|-------:|
|   2021 | 110.88 | 112.86 | 112.86 | 112.86 |
|   2022 | 143.86 | 112.86 | 111.87 | 112.86 |
|   2023 | 112.86 | 144.86 | 112.86 |  99    |
|   2024 | 112.86 | 112.86 | 133.95 | 117.86 |
|   2025 | 102.96 | 108.9  | 112.86 | 125.86 |


## Q15. Customers whose spend is above their country's average (correlated subquery)

```sql
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
```

| customer           | Country        |   spend |
|:-------------------|:---------------|--------:|
| Helena Holý        | Czech Republic |   49.62 |
| Richard Cunningham | USA            |   47.62 |
| Frank Ralston      | USA            |   43.62 |
| Julia Barnett      | USA            |   43.62 |
| Fynn Zimmermann    | Germany        |   43.62 |
| Victor Stevens     | USA            |   42.62 |
| Isabelle Mercier   | France         |   40.62 |
| Luís Gonçalves     | Brazil         |   39.62 |
| François Tremblay  | Canada         |   39.62 |
| João Fernandes     | Portugal       |   39.62 |
