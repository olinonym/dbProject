-- Store Procedure : spPlaceBid
CREATE OR ALTER PROCEDURE sp_PlaceBid
    @p_item_id INT,
    @p_bidder_id INT,
    @p_bid_amount DECIMAL(10,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @v_current_price DECIMAL(10,2);
        DECLARE @v_bid_increment DECIMAL(10,2);
        DECLARE @v_end_time DATETIME;
        DECLARE @v_status VARCHAR(20);

        -- ล็อกแถวข้อมูลเพื่อป้องกัน Race Condition (UPDLOCK)
        SELECT @v_current_price = current_price,
               @v_bid_increment = bid_increment,
               @v_end_time = end_time,
               @v_status = status
        FROM auction_items WITH (UPDLOCK)
        WHERE item_id = @p_item_id;

        -- ตรวจสอบสถานะและเวลาประมูล
        IF @v_status <> 'active' OR GETDATE() > @v_end_time
        BEGIN
            RAISERROR('รายการนี้ปิดการประมูลแล้ว หรือไม่อยู่ในสถานะเปิดประมูล', 16, 1);
        END

        -- ตรวจสอบราคาเสนอใหม่ ต้องสูงกว่าราคาปัจจุบัน + Bid Increment
        IF @p_bid_amount < (@v_current_price + @v_bid_increment)
        BEGIN
            RAISERROR('ราคาเสนอประมูลต่ำกว่าราคาปัจจุบัน + ขั้นต่ำการเคาะราคา', 16, 1);
        END

        -- บันทึก Bid ใหม่
        INSERT INTO bids (item_id, bidder_id, bid_amount, bid_time)
        VALUES (@p_item_id, @p_bidder_id, @p_bid_amount, GETDATE());

        -- อัปเดตราคาสูงสุดในตารางสินค้า
        UPDATE auction_items
        SET current_price = @p_bid_amount
        WHERE item_id = @p_item_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        THROW;
    END CATCH
END;

-- Trigger : trg_ExtendAuctionOnLateBid
CREATE OR ALTER TRIGGER trg_ExtendAuctionOnLateBid
ON bids
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @v_item_id INT;
    DECLARE @v_bid_time DATETIME;
    DECLARE @v_end_time DATETIME;

    SELECT @v_item_id = item_id, @v_bid_time = bid_time FROM inserted;

    SELECT @v_end_time = end_time
    FROM auction_items
    WHERE item_id = @v_item_id;

    -- ตรวจสอบว่าเคาะราคาในช่วง 3 นาทีสุดท้าย (180 วินาที) ก่อนหมดเวลาหรือไม่
    IF DATEDIFF(SECOND, @v_bid_time, @v_end_time) BETWEEN 0 AND 180
    BEGIN
        UPDATE auction_items
        SET end_time = DATEADD(MINUTE, 5, end_time)
        WHERE item_id = @v_item_id;
    END
END;

-- Report View : vw_AuctionPerformanceMetrics
CREATE OR ALTER VIEW vw_AuctionPerformanceMetrics AS
SELECT 
    c.category_name,
    COUNT(i.item_id) AS total_items,
    COUNT(CASE WHEN i.status = 'closed' AND i.current_price > i.starting_price THEN 1 END) AS successful_auctions,
    ROUND(
        (COUNT(CASE WHEN i.status = 'closed' AND i.current_price > i.starting_price THEN 1 END) * 100.0 / NULLIF(COUNT(i.item_id), 0)), 
        2
    ) AS success_rate_percentage,
    AVG(i.starting_price) AS avg_starting_price,
    AVG(i.current_price) AS avg_final_price,
    AVG(i.current_price - i.starting_price) AS avg_price_increase,
    SUM(CASE WHEN i.status = 'closed' THEN i.current_price ELSE 0 END) AS total_sales_volume
FROM item_categories c
LEFT JOIN auction_items i ON c.category_id = i.category_id
GROUP BY c.category_id, c.category_name;