USE bidzone_db;
GO

-- 1. Reset
DELETE FROM shipping_details; DBCC CHECKIDENT ('shipping_details', RESEED, 0);
DELETE FROM payments; DBCC CHECKIDENT ('payments', RESEED, 0);
DELETE FROM winning_bids; DBCC CHECKIDENT ('winning_bids', RESEED, 0);
DELETE FROM watchlists; DBCC CHECKIDENT ('watchlists', RESEED, 0);
DELETE FROM bids; DBCC CHECKIDENT ('bids', RESEED, 0);
DELETE FROM item_images; DBCC CHECKIDENT ('item_images', RESEED, 0);
DELETE FROM auction_items; DBCC CHECKIDENT ('auction_items', RESEED, 0);
DELETE FROM bidders; DBCC CHECKIDENT ('bidders', RESEED, 0);
DELETE FROM sellers; DBCC CHECKIDENT ('sellers', RESEED, 0);
DELETE FROM item_categories; DBCC CHECKIDENT ('item_categories', RESEED, 0);
GO

-- 2. Insert Categories
INSERT INTO item_categories (category_name, description) VALUES
(N'รถยนต์', N'ยานยนต์ รถยนต์ อะไหล่ และอุปกรณ์ตกแต่ง'),
(N'อิเล็กทรอนิกส์', N'อุปกรณ์ไอที สมาร์ทโฟน และแล็ปท็อป'),
(N'ของสะสม', N'ของหายาก เหรียญสะสม และสินค้าวินเทจ');
GO

-- 3. Insert Sellers
DECLARE @i INT = 1;
WHILE @i <= 20
BEGIN
    INSERT INTO sellers (first_name, last_name, email, password, phone, bank_account_number, rating, review_count, created_at)
    VALUES (
        CONCAT('SellerFn_', @i),
        CONCAT('SellerLn_', @i),
        CONCAT('seller', @i, '@example.com'),
        '$2b$10$e8.Z/vG5S8q0pI9XJ5kE.O3rE4u/W4x.zP9',
        CONCAT('081', RIGHT('0000000' + CAST(@i AS VARCHAR), 7)),
        CONCAT('123-4-567', RIGHT('00' + CAST(@i AS VARCHAR), 2), '-9'),
        CAST(4.0 + (@i % 10) * 0.1 AS DECIMAL(3,2)),
        10 + @i,
        GETDATE()
    );
    SET @i = @i + 1;
END;
GO

-- 4. Insert Bidders
DECLARE @i INT = 1;
WHILE @i <= 30
BEGIN
    INSERT INTO bidders (first_name, last_name, email, password, phone, created_at)
    VALUES (
        CONCAT('BidderFn_', @i),
        CONCAT('BidderLn_', @i),
        CONCAT('bidder', @i, '@example.com'),
        '$2b$10$e8.Z/vG5S8q0pI9XJ5kE.O3rE4u/W4x.zP9',
        CONCAT('089', RIGHT('0000000' + CAST(@i AS VARCHAR), 7)),
        GETDATE()
    );
    SET @i = @i + 1;
END;
GO

-- 5. Insert Auction Items
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO auction_items (seller_id, category_id, title, description, condition, brand, starting_price, current_price, bid_increment, start_time, end_time, status)
    VALUES (
        (@i % 20) + 1,
        (@i % 3) + 1,
        CONCAT('Auction Product Item #', @i),
        CONCAT('Detailed description for product number ', @i),
        CASE WHEN @i % 2 = 0 THEN 'Brand New' ELSE 'Used - Like New' END,
        CASE WHEN @i % 3 = 0 THEN 'Toyota' WHEN @i % 3 = 1 THEN 'Sony' ELSE 'Rolex' END,
        CAST(100.00 + (@i * 50) AS DECIMAL(10,2)),
        CAST(100.00 + (@i * 50) AS DECIMAL(10,2)),
        50.00,
        DATEADD(DAY, -5, GETDATE()),
        CASE 
            WHEN @i <= 30 THEN DATEADD(DAY, -1, GETDATE())
            WHEN @i <= 90 THEN DATEADD(DAY, 3, GETDATE())
            ELSE DATEADD(MINUTE, 2, GETDATE())
        END,
        CASE 
            WHEN @i <= 30 THEN 'closed'
            ELSE 'active'
        END
    );
    SET @i = @i + 1;
END;
GO

-- 6. Insert Item Images
DECLARE @i INT = 1;
WHILE @i <= 100
BEGIN
    INSERT INTO item_images (item_id, image_url, is_primary)
    VALUES (
        @i,
        CONCAT('https://picsum.photos/seed/item', @i, '/600/400'),
        1
    );
    SET @i = @i + 1;
END;
GO

-- 7. Insert Bids
DECLARE @i INT = 1;
DECLARE @target_item INT;
DECLARE @bidder_id INT;
DECLARE @step_amount DECIMAL(10,2);

WHILE @i <= 300
BEGIN
    SET @target_item = (@i % 100) + 1;
    SET @bidder_id = (@i % 30) + 1;
    SET @step_amount = 100.00 + (@i * 50) + ((@i % 5) * 50);

    INSERT INTO bids (item_id, bidder_id, bid_amount, bid_time)
    VALUES (
        @target_item,
        @bidder_id,
        @step_amount,
        DATEADD(MINUTE, -1000 + @i, GETDATE())
    );

    UPDATE auction_items 
    SET current_price = @step_amount 
    WHERE item_id = @target_item AND @step_amount > current_price;

    SET @i = @i + 1;
END;
GO

-- 8. Insert Watchlists
DECLARE @i INT = 1;
WHILE @i <= 50
BEGIN
    INSERT INTO watchlists (bidder_id, item_id, added_at)
    VALUES (
        (@i % 30) + 1,
        (@i % 100) + 1,
        DATEADD(DAY, -2, GETDATE())
    );
    SET @i = @i + 1;
END;
GO

-- 9. Insert Winning Bids
DECLARE @i INT = 1;
WHILE @i <= 30
BEGIN
    INSERT INTO winning_bids (item_id, bidder_id, winning_price, won_at, payment_status)
    SELECT TOP 1 
        item_id,
        ISNULL((SELECT TOP 1 bidder_id FROM bids WHERE item_id = @i ORDER BY bid_amount DESC), 1),
        current_price,
        end_time,
        'completed'
    FROM auction_items 
    WHERE item_id = @i;

    SET @i = @i + 1;
END;
GO

-- 10. Insert Payments
DECLARE @i INT = 1;
WHILE @i <= 30
BEGIN
    INSERT INTO payments (winning_id, amount, payment_method, payment_time, status)
    VALUES (
        @i,
        (SELECT winning_price FROM winning_bids WHERE winning_id = @i),
        CASE WHEN @i % 2 = 0 THEN 'Credit Card' ELSE 'PromptPay' END,
        DATEADD(HOUR, 1, GETDATE()),
        'completed'
    );
    SET @i = @i + 1;
END;
GO

-- 11. Insert Shipping Details
DECLARE @i INT = 1;
WHILE @i <= 30
BEGIN
    INSERT INTO shipping_details (winning_id, recipient_name, shipping_address, carrier_name, tracking_number, shipping_status)
    VALUES (
        @i,
        CONCAT('Bidder Winner #', @i),
        CONCAT(@i, '/123 Sukhumvit Road, Bangkok 10110'),
        CASE WHEN @i % 2 = 0 THEN 'Kerry Express' ELSE 'Thailand Post' END,
        CONCAT('TRACK', RIGHT('000000' + CAST(@i AS VARCHAR), 6)),
        CASE WHEN @i <= 15 THEN 'shipped' ELSE 'delivered' END
    );
    SET @i = @i + 1;
END;
GO

-- สรุปจำนวน Records ทั้งหมด
SELECT 'item_categories' AS table_name, COUNT(*) AS row_count FROM item_categories
UNION ALL SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL SELECT 'bidders', COUNT(*) FROM bidders
UNION ALL SELECT 'auction_items', COUNT(*) FROM auction_items
UNION ALL SELECT 'item_images', COUNT(*) FROM item_images
UNION ALL SELECT 'bids', COUNT(*) FROM bids
UNION ALL SELECT 'watchlists', COUNT(*) FROM watchlists
UNION ALL SELECT 'winning_bids', COUNT(*) FROM winning_bids
UNION ALL SELECT 'payments', COUNT(*) FROM payments
UNION ALL SELECT 'shipping_details', COUNT(*) FROM shipping_details;