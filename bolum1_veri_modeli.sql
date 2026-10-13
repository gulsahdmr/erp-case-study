-- ============================================================
-- Satınalma ve Stok Yönetimi Modülü - Veritabanı Şeması
-- SQL Server (MSSQL)
-- ============================================================

-- 1. Ürün Kartları
CREATE TABLE Item (
    ItemID       INT IDENTITY(1,1) PRIMARY KEY,
    ItemCode     VARCHAR(50) NOT NULL UNIQUE,
    ItemName     NVARCHAR(200) NOT NULL,
    Description  NVARCHAR(500) NULL,
    Unit         VARCHAR(20) NOT NULL,
    UnitPrice    DECIMAL(18,4) NOT NULL DEFAULT 0,
    MinStockQty  DECIMAL(18,4) NOT NULL DEFAULT 0,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt    DATETIME NULL
);

-- 2. Tedarikçiler
CREATE TABLE Supplier (
    SupplierID   INT IDENTITY(1,1) PRIMARY KEY,
    SupplierCode VARCHAR(50) NOT NULL UNIQUE,
    SupplierName NVARCHAR(200) NOT NULL,
    ContactName  NVARCHAR(100) NULL,
    Phone        VARCHAR(20) NULL,
    Email        VARCHAR(100) NULL,
    Address      NVARCHAR(500) NULL,
    TaxNumber    VARCHAR(20) NULL,
    IsActive     BIT NOT NULL DEFAULT 1,
    CreatedAt    DATETIME NOT NULL DEFAULT GETDATE()
);

-- 3. Satınalma Siparişi (Header)
-- Status: Draft, Approved, PartiallyReceived, Received, Cancelled
CREATE TABLE PurchaseOrder (
    PurchaseOrderID      INT IDENTITY(1,1) PRIMARY KEY,
    PONumber             VARCHAR(50) NOT NULL UNIQUE,
    SupplierID           INT NOT NULL,
    OrderDate            DATE NOT NULL DEFAULT GETDATE(),
    ExpectedDeliveryDate DATE NULL,
    Status               VARCHAR(20) NOT NULL DEFAULT 'Draft',
    TotalAmount          DECIMAL(18,4) NOT NULL DEFAULT 0,
    Notes                NVARCHAR(500) NULL,
    CreatedBy            NVARCHAR(100) NULL,
    CreatedAt            DATETIME NOT NULL DEFAULT GETDATE(),
    UpdatedAt            DATETIME NULL,

    CONSTRAINT FK_PurchaseOrder_Supplier 
        FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID)
);

-- 4. Satınalma Sipariş Kalemleri (Lines)
CREATE TABLE PurchaseOrderLine (
    POLineID        INT IDENTITY(1,1) PRIMARY KEY,
    PurchaseOrderID INT NOT NULL,
    ItemID          INT NOT NULL,
    LineNumber      INT NOT NULL,
    OrderedQty      DECIMAL(18,4) NOT NULL,
    ReceivedQty     DECIMAL(18,4) NOT NULL DEFAULT 0,
    UnitPrice       DECIMAL(18,4) NOT NULL,
    LineTotal       AS (OrderedQty * UnitPrice) PERSISTED,

    CONSTRAINT FK_POLine_PurchaseOrder 
        FOREIGN KEY (PurchaseOrderID) REFERENCES PurchaseOrder(PurchaseOrderID),
    CONSTRAINT FK_POLine_Item 
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID),
    CONSTRAINT UQ_POLine_Order_Item 
        UNIQUE (PurchaseOrderID, ItemID)
);

-- 5. Mal Kabul (Header)
CREATE TABLE GoodsReceipt (
    GoodsReceiptID  INT IDENTITY(1,1) PRIMARY KEY,
    GRNumber        VARCHAR(50) NOT NULL UNIQUE,
    PurchaseOrderID INT NOT NULL,
    ReceiptDate     DATE NOT NULL DEFAULT GETDATE(),
    ReceivedBy      NVARCHAR(100) NULL,
    Notes           NVARCHAR(500) NULL,
    CreatedAt       DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_GoodsReceipt_PurchaseOrder 
        FOREIGN KEY (PurchaseOrderID) REFERENCES PurchaseOrder(PurchaseOrderID)
);

-- 6. Mal Kabul Kalemleri (Lines)
CREATE TABLE GoodsReceiptLine (
    GRLineID       INT IDENTITY(1,1) PRIMARY KEY,
    GoodsReceiptID INT NOT NULL,
    POLineID       INT NOT NULL,
    ItemID         INT NOT NULL,
    ReceivedQty    DECIMAL(18,4) NOT NULL,
    Notes          NVARCHAR(200) NULL,

    CONSTRAINT FK_GRLine_GoodsReceipt 
        FOREIGN KEY (GoodsReceiptID) REFERENCES GoodsReceipt(GoodsReceiptID),
    CONSTRAINT FK_GRLine_POLine 
        FOREIGN KEY (POLineID) REFERENCES PurchaseOrderLine(POLineID),
    CONSTRAINT FK_GRLine_Item 
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID)
);

-- 7. Stok Hareketleri
-- Stok bakiyesi = SUM(IN) - SUM(OUT)
CREATE TABLE StockTransaction (
    StockTransactionID INT IDENTITY(1,1) PRIMARY KEY,
    ItemID             INT NOT NULL,
    TransactionType    VARCHAR(20) NOT NULL, -- IN / OUT
    Quantity           DECIMAL(18,4) NOT NULL,
    TransactionDate    DATETIME NOT NULL DEFAULT GETDATE(),
    ReferenceType      VARCHAR(50) NULL,     -- GoodsReceipt, ProductionOrder vb.
    ReferenceID        INT NULL,             -- İlgili belgenin ID'si
    Notes              NVARCHAR(200) NULL,
    CreatedBy          NVARCHAR(100) NULL,
    CreatedAt          DATETIME NOT NULL DEFAULT GETDATE(),

    CONSTRAINT FK_StockTransaction_Item 
        FOREIGN KEY (ItemID) REFERENCES Item(ItemID),
    CONSTRAINT CK_StockTransaction_Qty 
        CHECK (Quantity > 0),
    CONSTRAINT CK_StockTransaction_Type 
        CHECK (TransactionType IN ('IN', 'OUT'))
);
