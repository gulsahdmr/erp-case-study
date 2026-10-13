# Bölüm 3: REST API Tasarımı
# ERP Sistemi — Satınalma ve Stok Yönetimi Modülü

---

## Genel Kurallar

| HTTP Metod | Ne yapar? |
|------------|-----------|
| GET        | Veri getirir |
| POST       | Yeni kayıt oluşturur |

| HTTP Kod | Anlamı |
|----------|--------|
| 200      | Başarılı |
| 201      | Başarıyla oluşturuldu |
| 400      | Geçersiz istek (eksik veya hatalı veri) |
| 404      | Kayıt bulunamadı |
| 409      | Çakışma (zaten var) |
| 500      | Sunucu hatası |

---

## 1. GET /api/items
**Amaç:** Sistemdeki tüm ürünleri listeler.

**Request:**
```
GET /api/items
```

**Response (200 OK):**
```json
[
  {
    "itemId": 1,
    "itemCode": "ITM-001",
    "itemName": "Vida M8",
    "unit": "Adet",
    "unitPrice": 0.50
  },
  {
    "itemId": 2,
    "itemCode": "ITM-002",
    "itemName": "Somun M8",
    "unit": "Adet",
    "unitPrice": 0.30
  }
]
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 200 | Başarılı, liste döndü |
| 500 | Sunucu hatası (veritabanına bağlanamadı) |

---

## 2. GET /api/items/{id}
**Amaç:** Belirtilen ID'ye sahip tek bir ürünün detayını getirir.

**Request:**
```
GET /api/items/1
```

**Response (200 OK):**
```json
{
  "itemId": 1,
  "itemCode": "ITM-001",
  "itemName": "Vida M8",
  "unit": "Adet",
  "unitPrice": 0.50,
  "minStockQty": 100,
  "isActive": true
}
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 200 | Başarılı |
| 404 | Belirtilen ID'ye sahip ürün bulunamadı |
| 500 | Sunucu hatası |

---

## 3. POST /api/items
**Amaç:** Sisteme yeni bir ürün kartı ekler.

**Request:**
```json
{
  "itemCode": "ITM-003",
  "itemName": "Boru 1/2",
  "unit": "Metre",
  "unitPrice": 12.50,
  "minStockQty": 50
}
```

**Response (201 Created):**
```json
{
  "itemId": 3,
  "message": "Ürün başarıyla oluşturuldu."
}
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 201 | Başarıyla oluşturuldu |
| 400 | Zorunlu alan eksik (itemCode veya itemName boş) |
| 409 | Bu ürün kodu zaten mevcut |
| 500 | Sunucu hatası |

---

## 4. POST /api/purchase-orders
**Amaç:** Yeni bir satınalma siparişi oluşturur.
Sipariş başlığı ve kalemleri tek istekte gönderilir.

**Request:**
```json
{
  "supplierId": 1,
  "orderDate": "2026-10-12",
  "notes": "Acil sipariş",
  "lines": [
    {
      "itemId": 1,
      "orderedQty": 100,
      "unitPrice": 0.50
    },
    {
      "itemId": 2,
      "orderedQty": 200,
      "unitPrice": 0.30
    }
  ]
}
```

**Response (201 Created):**
```json
{
  "purchaseOrderId": 5,
  "poNumber": "PO-2026-005",
  "message": "Sipariş başarıyla oluşturuldu."
}
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 201 | Sipariş başarıyla oluşturuldu |
| 400 | Kalem listesi boş veya miktar sıfır gönderildi |
| 404 | Belirtilen supplierId veya itemId bulunamadı |
| 500 | Sunucu hatası |

---

## 5. GET /api/purchase-orders/{id}
**Amaç:** Belirtilen siparişin tüm detayını ve kalemlerini getirir.

**Request:**
```
GET /api/purchase-orders/5
```

**Response (200 OK):**
```json
{
  "purchaseOrderId": 5,
  "poNumber": "PO-2026-005",
  "supplierName": "ABC Ltd",
  "orderDate": "2026-10-12",
  "status": "Approved",
  "totalAmount": 110.00,
  "lines": [
    {
      "itemName": "Vida M8",
      "orderedQty": 100,
      "receivedQty": 60,
      "unitPrice": 0.50
    },
    {
      "itemName": "Somun M8",
      "orderedQty": 200,
      "receivedQty": 200,
      "unitPrice": 0.30
    }
  ]
}
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 200 | Başarılı |
| 404 | Belirtilen ID'ye sahip sipariş bulunamadı |
| 500 | Sunucu hatası |

---

## 6. POST /api/goods-receipts
**Amaç:** Mal kabul kaydı oluşturur.
Depo personeli ürünleri teslim aldığında kullanılır.
**Otomatik olarak StockTransaction (stok hareketi) kaydı da oluşturur.**

> 💡 **ERP Notu (Kısmi Mal Kabul):** Sipariş edilen miktardan daha az ürün gelmesi sistem açısından bir "hata" değildir. Bu durum **"Kısmi Mal Kabul (Partial Receipt)"** olarak kabul edilir ve işlem başarıyla kaydedilir; sipariş durumu otomatik olarak `PartiallyReceived` yapılır ve kalan bakiye açık tutulur.

**Request:**
```json
{
  "purchaseOrderId": 5,
  "receiptDate": "2026-10-12",
  "receivedBy": "Ahmet Yılmaz",
  "notes": "İlk sevkiyat teslim alındı (kısmi teslimat)",
  "lines": [
    {
      "poLineId": 1,
      "itemId": 1,
      "receivedQty": 60
    }
  ]
}
```

**Response (201 Created):**
```json
{
  "goodsReceiptId": 3,
  "grNumber": "GR-2026-003",
  "purchaseOrderStatus": "PartiallyReceived",
  "message": "Kısmi mal kabul kaydedildi. Stok otomatik güncellendi.",
  "lines": [
    {
      "poLineId": 1,
      "itemId": 1,
      "receivedQty": 60,
      "remainingQty": 40,
      "isCompleted": false
    }
  ]
}
```

**Hata Durumları:**
| Kod | Senaryo | Açıklama |
|-----|---------|----------|
| 201 | Başarılı | Mal kabul başarıyla oluşturuldu (Tam veya kısmi teslimat). |
| 400 | Fazla Teslimat / Geçersiz Miktar | Teslim alınan miktar açık sipariş miktarını aşıyor veya `0` / negatif miktar girildi. |
| 400 | Kısmi Teslimat Kısıtlaması | Sipariş için "Yalnızca Tam Teslimat (Complete Delivery Only)" kuralı aktifse ve eksik miktar gelmişse işlem reddedilir. |
| 404 | Kayıt Bulunamadı | Belirtilen `purchaseOrderId` veya `poLineId` sistemde mevcut değil. |
| 409 | Durum Çakışması | Sipariş zaten kapalı (`Received`) veya iptal edilmiş (`Cancelled`) durumdaysa yeni mal kabul alınamaz. |
| 500 | Sunucu Hatası | Veritabanı transaction hatası (Stok hareketi oluşturulamadı veya geri alındı). |

---

## 7. GET /api/stock
**Amaç:** Tüm ürünlerin güncel stok miktarını listeler.
StockTransaction tablosundaki giriş-çıkış farkından hesaplanır.

**Request:**
```
GET /api/stock
```

**Response (200 OK):**
```json
[
  {
    "itemCode": "ITM-001",
    "itemName": "Vida M8",
    "unit": "Adet",
    "currentStock": 70
  },
  {
    "itemCode": "ITM-002",
    "itemName": "Somun M8",
    "unit": "Adet",
    "currentStock": 200
  }
]
```

**Hata Durumları:**
| Kod | Açıklama |
|-----|----------|
| 200 | Başarılı |
| 500 | Sunucu hatası |
