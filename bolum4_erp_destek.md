# Bölüm 4: ERP Destek Senaryosu Çözüm Dokümanı

## Bildirilen Problem:
> *"100 adetlik satınalma siparişi oluşturduk. Ürün teslim alındı ancak stok ekranında yalnızca 60 adet görünüyor."*

---

## 1. Olası Nedenler Nelerdir?

Bu tutarsızlığın arkasında 4 ana eksende olası nedenler bulunabilir:

### A) Tedarikçi ve Sevkiyat Kaynaklı Nedenler
* **Kısmi Teslimat (Partial Delivery):** Tedarikçi siparişin tamamını değil, yalnızca 60 adedini göndermiş olabilir (kalan 40 adet daha sonra teslim edilecektir).
* **Kalite Kontrol / Hasarlı Ürün:** 100 adet ürün gelmiş, ancak 40 adedi kalite kontrolden geçemediği için kabul edilmemiş veya karantinaya ayrılmış olabilir.

### B) Operasyonel ve Kullanıcı Hataları
* **Hatalı Mal Kabul Girişi:** Depo personeli fiziksel olarak 100 adet teslim almasına rağmen sisteme girerken klavye hatasıyla 60 yazmış olabilir.
* **Farklı Depo/Lokasyon Girişi:** Ürünlerin 60 adedi Ana Depo'ya, 40 adedi Yedek/Karantina Deposu'na kaydedilmiş olabilir. Kullanıcı yalnızca Ana Depo bakiyesini görüntülüyor olabilir.
* **Birim Çevrim Hatası:** Ürün koli/adet gibi farklı birimlerle yönetiliyorsa, birim çevrim katsayısı yanlış uygulanmış olabilir.

### C) Süreç ve Tüketim Kaynaklı Nedenler
* **Hızlı Tüketim/Çıkış:** 100 adet ürün stoğa eksiksiz girmiş, ancak aynı gün üretim veya satış tarafından 40 adet çıkış (`StockTransaction.OUT`) yapılmış olabilir. Kalan güncel bakiye bu nedenle 60 görünmektedir.

### D) Sistemsel ve Teknik Nedenler
* **Önbellek (Cache) / Ekran Yenileme:** Kullanıcının ekranı güncel veriyi çekmemiş olabilir.
* **Transaction/Entegrasyon Hatası:** Mal kabul kaydedilirken veritabanı katmanında stok hareketi oluşturma esnasında bir hata meydana gelmiş olabilir.

---

## 2. Hangi Ekranlar Kontrol Edilir?

1. **Satınalma Sipariş Detay Ekranı:**
   * Sipariş edilen miktar (`OrderedQty = 100`) doğrulanır.
   * Sipariş durumu kontrol edilir (`PartiallyReceived` / `Received`).
   * Sipariş üzerindeki teslim alınan toplam miktar (`ReceivedQty`) incelenir.

2. **Mal Kabul (İrsaliye) Giriş Ekranı:**
   * İlgili siparişe bağlı kesilmiş Mal Kabul Belgeleri (Goods Receipts) listelenir.
   * Fiziksel basılı irsaliye kopyası ile ekrandaki irsaliye miktarı karşılaştırılır.

3. **Stok Kartı / Stok Hareketleri Ekranı (Ekstre):**
   * Ürünün giriş-çıkış hareket dökümüne bakılır.
   * Giriş yapılan miktar ve varsa çıkış yapılmış hareketler (üretim emri, fire, transfer) incelenir.

---

## 3. Hangi Veritabanı Tabloları Kontrol Edilir?

| Tablo | Kontrol Edilecek Alanlar | Kontrol Amacı |
|---|---|---|
| `PurchaseOrder` & `PurchaseOrderLine` | `PONumber`, `OrderedQty`, `ReceivedQty`, `Status` | Sipariş edilen miktar ile siparişte görünen teslimat miktarını karşılaştırmak. |
| `GoodsReceipt` & `GoodsReceiptLine` | `GRNumber`, `ReceivedQty`, `ReceiptDate` | Gerçekte sisteme kaç adetlik mal kabul belgesi girildiğini doğrulamak. |
| `StockTransaction` | `TransactionType`, `Quantity`, `ReferenceType`, `ReferenceID` | Mal kabulün stoğa giriş (IN) yapıp yapmadığını ve arada başka bir çıkış (OUT) olup olmadığını tespit etmek. |
| `Item` | `ItemCode`, `Unit` | Birim hatası veya ürün kartı tutarsızlığını kontrol etmek. |

---

## 4. Teşhis İçin Çalıştırılacak SQL Sorguları

### Sorgu A: Sipariş ile Mal Kabul Karşılaştırması
Siparişe bağlı tüm mal kabul hareketlerini listeler:

```sql
SELECT 
    po.PONumber                        AS 'Sipariş No',
    i.ItemCode                         AS 'Ürün Kodu',
    pol.OrderedQty                     AS 'Sipariş Edilen',
    pol.ReceivedQty                    AS 'Sipariş Satırı Teslim',
    gr.GRNumber                        AS 'Mal Kabul No',
    grl.ReceivedQty                    AS 'Mal Kabuldeki Miktar',
    gr.ReceiptDate                     AS 'Teslim Tarihi'
FROM PurchaseOrderLine pol
JOIN PurchaseOrder po          ON pol.PurchaseOrderID = po.PurchaseOrderID
JOIN Item i                   ON pol.ItemID = i.ItemID
LEFT JOIN GoodsReceiptLine grl ON pol.POLineID = grl.POLineID
LEFT JOIN GoodsReceipt gr      ON grl.GoodsReceiptID = gr.GoodsReceiptID
WHERE po.PONumber = 'PO-2024-001'; -- İncelenen sipariş numarası
```

### Sorgu B: Mal Kabul ile Stok Hareketi Doğrulaması
Mal kabul belgesinin stok hareketine doğru yansıyıp yansımadığını kontrol eder:

```sql
SELECT 
    gr.GRNumber                        AS 'Mal Kabul No',
    grl.ReceivedQty                    AS 'Mal Kabul Miktarı',
    st.Quantity                        AS 'Stok Hareket Miktarı',
    st.TransactionType                 AS 'Hareket Tipi',
    st.TransactionDate                 AS 'İşlem Tarihi'
FROM GoodsReceiptLine grl
JOIN GoodsReceipt gr          ON grl.GoodsReceiptID = gr.GoodsReceiptID
LEFT JOIN StockTransaction st ON st.ReferenceID = gr.GoodsReceiptID 
                             AND st.ReferenceType = 'GoodsReceipt'
WHERE gr.GoodsReceiptID = 3; -- İlgili mal kabul ID
```

### Sorgu C: Ürünün Detaylı Stok Ekstresi
Ürünün güncel bakiyesine ulaşana kadar gerçekleşen tüm hareketleri dökümler:

```sql
SELECT 
    st.TransactionDate                 AS 'Tarih',
    st.TransactionType                 AS 'Tip (IN/OUT)',
    st.Quantity                        AS 'Miktar',
    st.ReferenceType                   AS 'Kaynak Belge Tipi',
    st.ReferenceID                     AS 'Belge No/ID',
    st.CreatedBy                       AS 'İşlemi Yapan',
    st.Notes                           AS 'Açıklama'
FROM StockTransaction st
JOIN Item i ON st.ItemID = i.ItemID
WHERE i.ItemCode = 'ITM-001'
ORDER BY st.TransactionDate ASC;
```

---

## 5. Kök Neden Analizi (Root Cause Analysis Metodolojisi)

Problem sadece o anki stoğu manuel düzelterek kapatılmaz; hatanın tekrar etmesini engelleyecek metodolojik yaklaşım uygulanır:

### 5 Neden (5 Whys) Analizi
1. **Neden stokta 60 görünüyor?**  
   Depo personeli sisteme 60 adet mal kabul girişi yapmış.
2. **Neden 100 gelmişken 60 girilmiş?**  
   İrsaliye üzerindeki miktar manuel klavyeyle yazılırken sehven eksik tuşlanmış.
3. **Neden miktar manuel girildi?**  
   Depoda barkod/el terminali entegrasyonu bulunmadığı için girişler manuel yapılmaktadır.
4. **Neden sistem bu eksik girişi onay sormadan kabul etti?**  
   Mal kabul arayüzünde "Sipariş ile irsaliye miktarı uyuşmazlığında uyarı çıkarma" kontrolü aktif değildi.
5. **KÖK NEDEN:** Manuel veri girişi bağımlılığı ve sistemsel onay/doğrulama kontrolünün eksik olması.

### Kalıcı ve Önleyici Aksiyonlar (CAPA)
1. **UI Doğrulama Kontrolü:** Sipariş miktarından farklı bir değer girildiğinde:  
   *"Sipariş miktarı 100, girilen miktar 60. Kısmi mal kabul yapmak istediğinize emin misiniz?"* onay modalı zorunlu kılınmalı.
2. **Barkod Okuyucu Entegrasyonu:** Mal kabul işlemlerinde barkod okutma zorunlu tutularak insani hata minimize edilmeli.
3. **Otomatik Uyarı Mekanizması:** Kısmi teslimat gerçekleştiğinde Satınalma Uzmanına sistemden otomatik bildirim iletilmeli.
4. **Gece Mutabakat Raporu (Reconciliation Job):** Her gece çalışan otomatik SQL işi ile `OrderedQty > ReceivedQty` durumundaki tüm açık veya tutarsız kayıtlar ilgili yöneticilere raporlanmalı.
