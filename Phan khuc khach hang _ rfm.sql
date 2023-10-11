--TÍNH NGÀY MUA GẦN NHẤT (R)

SELECT 
	recency, 
	COUNT(*) cnt
INTO #rfm
FROM 
	(SELECT 
		CustomerID
		,DATEDIFF(DAY, MAX(OrderDate), '2014-01-01') recency
	FROM Sales.SalesOrderHeader
	WHERE YEAR(OrderDate) = 2013
    GROUP BY CustomerID) h --Khách hàng mua trong thời gian gần nhất
GROUP BY recency
ORDER BY recency
--cách 1: dùng patero
SELECT 
	*,
	SUM(cnt) OVER(ORDER BY recency) running_Total,
	SUM(cnt) OVER() cnt_Total,
	FORMAT((SUM(cnt) OVER(ORDER BY recency)) * 1.0/SUM(cnt) OVER(),'P2') perc,
	FLOOR(((SUM(cnt) OVER(ORDER BY recency)) * 1.0/((SUM(cnt) OVER())+1))*5+1) quintiles
FROM rfm
ORDER BY recency 

--Cách 2:dùng ntile
SELECT 
	h.* 
	,NTILE(5) OVER (ORDER BY recency) --hàm ntile để chia đều
	,PERCENTILE_DISC(0.8) WITHIN GROUP (ORDER BY recency) OVER () --hàm để test thử đến số bao nhiêu
FROM 
	(SELECT 
		CustomerID, 
		DATEDIFF(DAY, MAX(OrderDate), '2014-01-01') recency
	FROM Sales.SalesOrderHeader
    WHERE YEAR(OrderDate) = 2013
    GROUP BY CustomerID) h 

---* TÍNH TẦN SUẤT MUA (F)

SELECT 
	DATEDIFF(DAY, min_Date, '2014-01-01')/num_Orders frequency
	,COUNT(*) cnt_Cust	
INTO #rfm02
FROM 
	(SELECT 
		CustomerID
		,MIN(OrderDate) min_Date, --ngày mua đầu tiên
		COUNT(*) num_Orders							
	FROM Sales.SalesOrderHeader				
    WHERE YEAR(OrderDate) = 2013							
    GROUP BY CustomerID) h							
GROUP BY DATEDIFF(DAY, min_Date, '2014-01-01')/num_Orders							
ORDER BY frequency

SELECT *,
	SUM(cnt_Cust) OVER(ORDER BY frequency) running_Total,
	SUM(cnt_Cust) OVER() cnt_Total,
	FORMAT((SUM(cnt_Cust) OVER(ORDER BY frequency)) * 1.0/SUM(cnt_Cust) OVER(),'P2') perc,
	FLOOR(((SUM(cnt_Cust) OVER(ORDER BY frequency)) * 1.0/((SUM(cnt_Cust) OVER())+1))*5+1) quintiles
FROM rfm02
order by frequency

--SỐ TIỀN KHÁCH MUA (M)

SELECT CustomerID,
	COUNT(*) cnt,
	SUM(subtotal) sum_Amt,
	AVG(subtotal) avg_Amt,
	RANK() OVER (ORDER BY AVG(subtotal) DESC) rnk,
	COUNT(*) OVER () num_Custs,
	CAST(5 * (RANK() OVER (ORDER BY AVG(subtotal) DESC) - 1)/COUNT(*) OVER () as INT) + 1 as monetary
FROM Sales.SalesOrderHeader	
WHERE YEAR(OrderDate) = 2013	
GROUP BY CustomerID

--------------------------------------------------------------------------
--THỐNG KÊ TỔNG HỢP

SELECT rb * 100 + fb * 10 + mb as rfm, COUNT(*) num_Custs
FROM (
	SELECT CustomerID,
		(CASE WHEN r <= 34 THEN 1 WHEN r >= 34 THEN 2
              WHEN r <= 113 THEN 3 WHEN r >= 113 AND r <= 162 THEN 4
              ELSE 5 END) as rb,
         (CASE WHEN f <= 45 THEN 1 WHEN f >= 77 THEN 2
               WHEN f <= 119 THEN 3 WHEN f >= 119 AND f <= 165 THEN 4
               ELSE 5 END) as fb,
         (CASE WHEN m >= 805 and m <= 2274 THEN 1 WHEN m >= 805 THEN 2
               WHEN m <= 78 THEN 3 WHEN m >= 37 THEN 4
               ELSE 5 END) as mb
FROM (SELECT CustomerID,
			DATEDIFF(day, MAX(OrderDate), '2014-01-01') r,
			DATEDIFF(day, MIN(OrderDate), '2014-01-01') / COUNT(*) f,
			SUM(SubTotal) / COUNT(*) m
      FROM Sales.SalesOrderHeader
      WHERE YEAR(OrderDate) = 2013
      GROUP BY CustomerID) a 
	) b
GROUP BY rb*100+fb*10+mb
ORDER BY rfm

-- KIỂM TRA SỰ CHUYỂN DỊCH KHÁCH HÀNG QUA 2 NĂM
SELECT 
	rfm.rb2012*100+rfm.fb2012*10+rfm.mb2012 as rfm_201x,
    rfm.rb2013*100+rfm.fb2013*10+rfm.mb2013 as rfm_201x,
    COUNT(*) transition
FROM (SELECT CustomerID,
             (CASE WHEN r2013 <= 34 THEN 1 WHEN r2013 >= 34 THEN 2
                   WHEN r2013 <= 113 THEN 3 WHEN r2013 >= 113 AND r2013 <= 162 THEN 4
                   ELSE 5 END) as rb2013,
             (CASE WHEN f2013 <= 45 THEN 1 WHEN f2013 >= 77 THEN 2
                   WHEN f2013 <= 119 THEN 3 WHEN f2013 >= 119 AND f2013 <= 165 THEN 4
                   ELSE 5 END) as fb2013,
             (CASE WHEN m2013 >= 805 and m2013 <= 2274 THEN 1 WHEN m2013 >= 805 THEN 2
                   WHEN m2013 <= 78 THEN 3 WHEN m2013 >= 37 THEN 4
                   ELSE 5 END) as mb2013,
             (CASE WHEN r2012 is null THEN null
                   WHEN r2012 <= 174 THEN 1 WHEN r2012 <= 420 THEN 2
                   WHEN r2012 <= 807 THEN 3 WHEN r2012 <= 1400 THEN 4
                   ELSE 5 END) as rb2012,
             (CASE WHEN f2012 IS NULL THEN NULL
                   WHEN f2012 <= 192 THEN 1 WHEN f2012 <= 427 THEN 2
                   WHEN f2012 <= 807 THEN 3 WHEN f2012 <= 1400 THEN 4
                   ELSE 5 END) as fb2012,
             (CASE WHEN m2012 >= 54.95 THEN 1 WHEN m2012 >= 29.23 THEN 2
                   WHEN m2012 >= 20.25 THEN 3 WHEN m2012 >= 14.95 THEN 4
                   ELSE 5 END) as mb2012
      FROM (SELECT CustomerID,
            DATEDIFF(DAY, MAX(CASE WHEN OrderDate < '2012-12-31' THEN OrderDate END),
                            '2013-01-01') as r2012,
            FLOOR(DATEDIFF(DAY,MIN(CASE WHEN OrderDate < '2012-12-31' THEN OrderDate END),
                           '2013-01-01')/ SUM(CASE WHEN OrderDate < '2012-12-31' THEN 1.0 END)) as f2012,
            (SUM(CASE WHEN OrderDate < '2012-12-31' THEN SubTotal END) /
             SUM (CASE WHEN OrderDate < '2012-12-31' THEN 1.0 END )) as m2012,
             
			 DATEDIFF(day, MAX(OrderDate),'2014-01-01') r2013,
             FLOOR(DATEDIFF(DAY, MIN(OrderDate), '2014-01-01') /COUNT(*)) f2013, AVG(SubTotal) m2013
            FROM Sales.SalesOrderHeader
            WHERE YEAR(OrderDate) IN (2012, 2013)
            GROUP BY CustomerID) h
      ) rfm
GROUP BY rfm.rb2012*100+rfm.fb2012*10+rfm.mb2012,
        rfm.rb2013*100+rfm.fb2013*10+rfm.mb2013
HAVING rfm.rb2012*100+rfm.fb2012*10+rfm.mb2012 is not null
ORDER BY COUNT(*) DESC
