const express = require('express');
const sql = require('mssql');
const cors = require('cors');
const path = require('path');
require('dotenv').config();

const app = express();
app.use(express.json());
app.use(cors());

// เสิร์ฟไฟล์หน้าเว็บ static (HTML, CSS, JS)
app.use(express.static(path.join(__dirname)));

// ------------------------------------------------------------
// การตั้งค่าเชื่อมต่อกับ SQL Server (SSMS)
// ------------------------------------------------------------
const dbConfig = {
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    server: process.env.DB_SERVER,
    database: process.env.DB_NAME,
    options: {
        encrypt: false, // สำหรับใช้งานบน Local MS SQL Server
        trustServerCertificate: true
    }
};

// เชื่อมต่อ SQL Server
sql.connect(dbConfig)
    .then(pool => {
        if (pool.connecting) console.log('Connecting to database...');
        if (pool.connected) console.log('Connected to SQL Server Successfully!');
    })
    .catch(err => console.error('Database Connection Failed! Bad Config: ', err));

// ------------------------------------------------------------
// API Route 1: ดึงรายการสินค้าทั้งหมด
// ------------------------------------------------------------
app.get('/api/items', async (req, res) => {
    try {
        const pool = await sql.connect(dbConfig);
        const result = await pool.request().query(`
            SELECT 
                i.item_id,
                i.title AS product_name,
                c.category_name,
                i.starting_price,
                i.current_price,
                i.end_time,
                i.status,
                img.image_url
            FROM auction_items i
            INNER JOIN item_categories c ON i.category_id = c.category_id
            LEFT JOIN item_images img ON i.item_id = img.item_id AND img.is_primary = 1
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ------------------------------------------------------------
// API Route 2: ปุ่มกดเคาะราคา
// ------------------------------------------------------------
app.post('/api/place-bid', async (req, res) => {
    const { item_id, bidder_id, bid_amount } = req.body;
    try {
        const pool = await sql.connect(dbConfig);
        await pool.request()
            .input('p_item_id', sql.Int, item_id)
            .input('p_bidder_id', sql.Int, bidder_id)
            .input('p_bid_amount', sql.Decimal(10, 2), bid_amount)
            .execute('sp_PlaceBid');

        res.json({ success: true, message: "เคาะราคาเรียบร้อยแล้ว!" });
    } catch (err) {
        // หาก sp_PlaceBid ส่ง RAISERROR กลับมา จะจับได้ตรงนี้
        res.status(400).json({ success: false, message: err.message });
    }
});

// ------------------------------------------------------------
// API Route 3: แสดงข้อมูล Analytics สรุปผลผู้บริหาร
// ------------------------------------------------------------
app.get('/api/analytics', async (req, res) => {
    try {
        const pool = await sql.connect(dbConfig);
        const result = await pool.request().query('SELECT * FROM vw_AuctionPerformanceMetrics');
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ------------------------------------------------------------
// API Route 4: แสดง Leaderboard Top 3 คนเคาะราคาสูงสุด
// ------------------------------------------------------------
app.get('/api/leaderboard', async (req, res) => {
    try {
        const pool = await sql.connect(dbConfig);
        const result = await pool.request().query(`
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
            WHERE bid_rank <= 3
        `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// ------------------------------------------------------------
// API Route 5: ดึงรายการการเสนอราคาของผู้ใช้
// ------------------------------------------------------------
app.get('/api/bids/user/:bidderId', async (req, res) => {
    try {
        const bidderId = req.params.bidderId;
        const pool = await sql.connect(dbConfig);
        const result = await pool.request()
            .input('bidderId', sql.Int, bidderId)
            .query(`
                WITH LatestUserBids AS (
                    SELECT 
                        b.item_id,
                        MAX(b.bid_amount) AS my_last_bid,
                        MAX(b.bid_time) AS my_last_bid_time
                    FROM bids b
                    WHERE b.bidder_id = @bidderId
                    GROUP BY b.item_id
                )
                SELECT 
                    i.item_id,
                    i.title AS product_name,
                    c.category_name,
                    i.current_price,
                    i.end_time,
                    i.status,
                    ub.my_last_bid,
                    img.image_url,
                    CASE 
                        WHEN i.current_price = ub.my_last_bid THEN N'คุณเป็นผู้นำ'
                        ELSE N'ถูกเสนอแซง'
                    END AS bid_status
                FROM LatestUserBids ub
                INNER JOIN auction_items i ON ub.item_id = i.item_id
                INNER JOIN item_categories c ON i.category_id = c.category_id
                LEFT JOIN item_images img ON i.item_id = img.item_id AND img.is_primary = 1
                ORDER BY ub.my_last_bid_time DESC
            `);
        res.json(result.recordset);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// เปิด Server ที่ Port 3000
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Server running on port ${PORT}`));