-- ============================================================
-- Satınalma ve Stok Modülü - SQL Sorguları
-- SQL Server (MSSQL)
-- ============================================================

-- ------------------------------------------------------------
-- Soru 1: Ürün bazında güncel stok miktarı
-- ------------------------------------------------------------
SELECT
    i.ItemCode                  AS [Ürün Kodu],
    i.ItemName                  AS [Ürün Adı],
    i.Unit                      AS [Birim],
    SUM(
        CASE
            WHEN st.TransactionType = 'IN'  THEN  st.Quantity
            WHEN st.TransactionType = 'OUT' THEN -st.Quantity
            ELSE 0
        END
    )                           AS [Güncel Stok]
FROM StockTransaction st
JOIN Item i ON st.ItemID = i.ItemID
GROUP BY i.ItemID, i.ItemCode, i.ItemName, i.Unit
ORDER BY i.ItemCode;


-- ------------------------------------------------------------
-- Soru 2: Son 30 gün içinde en fazla satın alınan ilk 10 ürün
-- ------------------------------------------------------------
SELECT TOP 10
    i.ItemCode                  AS [Ürün Kodu],
    i.ItemName                  AS [Ürün Adı],
    i.Unit                      AS [Birim],
    SUM(pol.OrderedQty)         AS [Toplam Sipariş Miktarı]
FROM PurchaseOrderLine pol
JOIN PurchaseOrder po ON pol.PurchaseOrderID = po.PurchaseOrderID
JOIN Item i           ON pol.ItemID = i.ItemID
WHERE po.OrderDate >= DATEADD(DAY, -30, CAST(GETDATE() AS DATE))
GROUP BY i.ItemID, i.ItemCode, i.ItemName, i.Unit
ORDER BY SUM(pol.OrderedQty) DESC;


-- ------------------------------------------------------------
-- Soru 3: Henüz tamamen teslim edilmemiş satınalma siparişleri
-- (Sipariş edilen > Teslim alınan)
-- ------------------------------------------------------------
SELECT
    po.PONumber                                 AS [Sipariş No],
    s.SupplierName                              AS [Tedarikçi],
    po.OrderDate                                AS [Sipariş Tarihi],
    SUM(pol.OrderedQty)                         AS [Sipariş Edilen],
    SUM(pol.ReceivedQty)                        AS [Teslim Alınan],
    SUM(pol.OrderedQty) - SUM(pol.ReceivedQty)  AS [Kalan Miktar]
FROM PurchaseOrderLine pol
JOIN PurchaseOrder po ON pol.PurchaseOrderID = po.PurchaseOrderID
JOIN Supplier s       ON po.SupplierID = s.SupplierID
GROUP BY po.PurchaseOrderID, po.PONumber, s.SupplierName, po.OrderDate
HAVING SUM(pol.OrderedQty) > SUM(pol.ReceivedQty)
ORDER BY po.OrderDate;


-- ------------------------------------------------------------
-- Soru 4: Son 90 gün içinde hiç hareket görmeyen ürünler
-- ------------------------------------------------------------
SELECT
    i.ItemCode AS [Ürün Kodu],
    i.ItemName AS [Ürün Adı],
    i.Unit     AS [Birim]
FROM Item i
WHERE NOT EXISTS (
    SELECT 1
    FROM StockTransaction st
    WHERE st.ItemID = i.ItemID
      AND st.TransactionDate >= DATEADD(DAY, -90, GETDATE())
)
ORDER BY i.ItemCode;
