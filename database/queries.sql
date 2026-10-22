-- ============================================================
-- File: queries.sql
-- Description: 10 Complex SQL Queries for Online Auction System
-- Project Topic 15: Online Real-Time Auction System
-- ============================================================

-- ============================================================
-- หมวดที่ 1: Multi-table JOIN (>= 3 ตาราง) - จำนวน 2 ข้อ
-- ============================================================

-- [Query 1]: ดึงรายละเอียดสินค้าประมูล + ชื่อผู้ขาย + หมวดหมู่ + รูปภาพหลัก
-- การนำไปใช้: ใช้แสดงผลบนหน้าเว็บ "รายการสินค้าประมูลทั้งหมด (Catalog Page)"
SELECT 
    i.item_id,
    i.title AS product_name,
    c.category_name,
    CONCAT(s.first_name, ' ', s.last_name) AS seller_name,
    s.rating AS seller_rating,
    i.starting_price,
    i.current_price,
    i.end_time,
    img.image_url
FROM auction_items i
INNER JOIN item_categories c ON i.category_id = c.category_id
INNER JOIN sellers s ON i.seller_id = s.seller_id
LEFT JOIN item_images img ON i.item_id = img.item_id AND img.is_primary = 1;


-- [Query 2]: ดึงข้อมูลผู้ชนะการประมูล + รายละเอียดสินค้า + การชำระเงิน + สถานะจัดส่ง (5 ตาราง)
-- การนำไปใช้: ใช้แสดงผลในหน้า "ประวัติการชนะประมูลและการจัดส่ง (My Winning Orders)"
SELECT 
    w.winning_id,
    i.title AS item_title,
    CONCAT(b.first_name, ' ', b.last_name) AS winner_name,
    w.winning_price,
    p.payment_method,
    p.status AS payment_status,
    sd.carrier_name,
    sd.tracking_number,
    sd.shipping_status
FROM winning_bids w
INNER JOIN auction_items i ON w.item_id = i.item_id
INNER JOIN bidders b ON w.bidder_id = b.bidder_id
LEFT JOIN payments p ON w.winning_id = p.winning_id
LEFT JOIN shipping_details sd ON w.winning_id = sd.winning_id;


-- ============================================================
-- หมวดที่ 2: GROUP BY + HAVING - จำนวน 3 ข้อ
-- ============================================================

-- [Query 3]: หา Bidders ที่ทำการเคาะราคาประมูลรวมกันมากกว่า 2 ครั้งขึ้นไป
-- การนำไปใช้: ใช้ในระบบจัดอันดับผู้ใช้ที่มีความกระตือรือร้นในการประมูลสูง (Active Bidders)
SELECT 
    b.bidder_id,
    CONCAT(b.first_name, ' ', b.last_name) AS bidder_name,
    b.email,
    COUNT(bd.bid_id) AS total_bids_placed,
    MAX(bd.bid_amount) AS highest_bid_placed
FROM bidders b
INNER JOIN bids bd ON b.bidder_id = bd.bidder_id
GROUP BY b.bidder_id, b.first_name, b.last_name, b.email
HAVING COUNT(bd.bid_id) >= 2;


-- [Query 4]: หาหมวดหมู่สินค้าที่มีมูลค่าราคาสูงสุดรวมกันเกิน 50,000 บาท
-- การนำไปใช้: สรุปรายงานวิเคราะห์หมวดหมู่สินค้าที่ทำรายได้สูงให้ผู้บริหาร (High-value Categories)
SELECT 
    c.category_id,
    c.category_name,
    COUNT(i.item_id) AS total_items,
    SUM(i.current_price) AS category_total_value,
    AVG(i.current_price) AS category_avg_price
FROM item_categories c
INNER JOIN auction_items i ON c.category_id = i.category_id
GROUP BY c.category_id, c.category_name
HAVING SUM(i.current_price) > 50000.00;


-- [Query 5]: หาผู้ขาย (Sellers) ที่ลงขายสินค้าเกิน 1 ชิ้น และมีคะแนนเรตติ้งเฉลี่ยตั้งแต่ 4.5 ขึ้นไป
-- การนำไปใช้: ค้นหาผู้ขายระดับพรีเมียม (Top Rated Sellers) เพื่อติดป้ายสัญลักษณ์บนหน้าเว็บ
SELECT 
    s.seller_id,
    CONCAT(s.first_name, ' ', s.last_name) AS seller_name,
    s.rating,
    COUNT(i.item_id) AS total_listed_items
FROM sellers s
INNER JOIN auction_items i ON s.seller_id = i.seller_id
GROUP BY s.seller_id, s.first_name, s.last_name, s.rating
HAVING COUNT(i.item_id) >= 1 AND s.rating >= 4.5;


-- ============================================================
-- หมวดที่ 3: Subqueries / Correlated Subqueries - จำนวน 3 ข้อ
-- ============================================================

-- [Query 6]: ค้นหาการเคาะราคาสูงสุดของสินค้าแต่ละรายการ (Correlated Subquery)
-- การนำไปใช้: ดึงประวัติผู้ชนะ/ผู้ถือราคาสูงสุด ณ ปัจจุบันของสินค้าแต่ละชิ้นไปโชว์ในหน้ารายละเอียดสินค้า
SELECT 
    b.bid_id,
    b.item_id,
    i.title AS item_title,
    CONCAT(bd.first_name, ' ', bd.last_name) AS highest_bidder,
    b.bid_amount,
    b.bid_time
FROM bids b
INNER JOIN auction_items i ON b.item_id = i.item_id
INNER JOIN bidders bd ON b.bidder_id = bd.bidder_id
WHERE b.bid_amount = (
    SELECT MAX(sub_b.bid_amount)
    FROM bids sub_b
    WHERE sub_b.item_id = b.item_id
);


-- [Query 7]: ค้นหาสินค้าที่มีราคาจบ/ปัจจุบัน สูงกว่าราคาเฉลี่ยของสินค้าทั้งหมดในระบบ (Subquery in WHERE)
-- การนำไปใช้: ดึงรายการสินค้าที่เป็นกระแสหรือแข่งขันสูง (Trending / Hot Items)
SELECT 
    item_id,
    title,
    current_price,
    starting_price,
    (current_price - starting_price) AS price_gain
FROM auction_items
WHERE current_price > (
    SELECT AVG(current_price) 
    FROM auction_items
);


-- [Query 8]: ค้นหา Bidders ที่กดติดตามสินค้า (Watchlist) ไว้ แต่ยังไม่เคยทำการเคาะราคาจริงในสินค้านั้นเลย (Subquery with NOT EXISTS)
-- การนำไปใช้: ระบบส่งการแจ้งเตือน (Push Notification/Email) กระตุ้นให้ผู้ใช้เข้ามาเคาะราคาประมูล
SELECT 
    w.bidder_id,
    CONCAT(b.first_name, ' ', b.last_name) AS bidder_name,
    b.email,
    i.item_id,
    i.title AS watched_item_title
FROM watchlists w
INNER JOIN bidders b ON w.bidder_id = b.bidder_id
INNER JOIN auction_items i ON w.item_id = i.item_id
WHERE NOT EXISTS (
    SELECT 1 
    FROM bids bd 
    WHERE bd.bidder_id = w.bidder_id 
      AND bd.item_id = w.item_id
);


-- ============================================================
-- หมวดที่ 4: Window Functions (RANK, ROW_NUMBER, OVER) - จำนวน 2 ข้อ
-- ============================================================

-- [Query 9]: จัดอันดับผู้เสนอราคาสูงสุด 3 อันดับแรกของแต่ละสินค้า (DENSE_RANK() OVER)
-- การนำไปใช้: แสดงตารางอันดับผู้นำราคา (Leaderboard) บนหน้าจอเคาะราคาประมูล
WITH RankedBids AS (
    SELECT 
        b.item_id,
        i.title AS item_title,
        CONCAT(bd.first_name, ' ', bd.last_name) AS bidder_name,
        b.bid_amount,
        b.bid_time,
        DENSE_RANK() OVER (
            PARTITION BY b.item_id 
            ORDER BY b.bid_amount DESC
        ) AS bid_rank
    FROM bids b
    INNER JOIN auction_items i ON b.item_id = i.item_id
    INNER JOIN bidders bd ON b.bidder_id = bd.bidder_id
)
SELECT item_id, item_title, bidder_name, bid_amount, bid_time, bid_rank
FROM RankedBids
WHERE bid_rank <= 3;


-- [Query 10]: ลำดับประวัติการเคาะราคาของผู้ใช้แต่ละคนตามลำดับเวลา (ROW_NUMBER() OVER)
-- การนำไปใช้: แสดงไทม์ไลน์ประวัติกิจกรรมย้อนหลังของผู้ใช้ (User Activity Log / Bidding Timeline)
SELECT 
    b.bidder_id,
    CONCAT(bd.first_name, ' ', bd.last_name) AS bidder_name,
    i.title AS item_title,
    b.bid_amount,
    b.bid_time,
    ROW_NUMBER() OVER (
        PARTITION BY b.bidder_id 
        ORDER BY b.bid_time ASC
    ) AS user_bid_sequence
FROM bids b
INNER JOIN bidders bd ON b.bidder_id = bd.bidder_id
INNER JOIN auction_items i ON b.item_id = i.item_id;