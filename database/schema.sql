-- 1. กลุ่มผู้ใช้งานระบบ (User Management)
CREATE TABLE sellers (
    seller_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    bank_account_number VARCHAR(50),
    rating DECIMAL(3,2) DEFAULT 0.00,
    review_count INT DEFAULT 0,
    created_at DATETIME DEFAULT GETDATE()
);

CREATE TABLE bidders (
    bidder_id INT IDENTITY(1,1) PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    phone VARCHAR(20),
    created_at DATETIME DEFAULT GETDATE()
);

-- 2. กลุ่มสินค้าและหมวดหมู่ (Product & Category)
CREATE TABLE item_categories (
    category_id INT IDENTITY(1,1) PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL,
    description VARCHAR(MAX)
);

CREATE TABLE auction_items (
    item_id INT IDENTITY(1,1) PRIMARY KEY,
    seller_id INT NOT NULL,
    category_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description VARCHAR(MAX),
    condition VARCHAR(50), 
    brand VARCHAR(100), 
    starting_price DECIMAL(10,2) NOT NULL,
    current_price DECIMAL(10,2) NOT NULL,
    bid_increment DECIMAL(10,2) NOT NULL,
    start_time DATETIME NOT NULL,
    end_time DATETIME NOT NULL,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'closed', 'cancelled')),
    FOREIGN KEY (seller_id) REFERENCES sellers(seller_id),
    FOREIGN KEY (category_id) REFERENCES item_categories(category_id)
);

CREATE TABLE item_images (
    image_id INT IDENTITY(1,1) PRIMARY KEY,
    item_id INT NOT NULL,
    image_url VARCHAR(255) NOT NULL,
    is_primary BIT DEFAULT 0,
    FOREIGN KEY (item_id) REFERENCES auction_items(item_id) ON DELETE CASCADE
);

-- 3. กลุ่มระบบการประมูล (Bidding Engine)
CREATE TABLE bids (
    bid_id INT IDENTITY(1,1) PRIMARY KEY,
    item_id INT NOT NULL,
    bidder_id INT NOT NULL,
    bid_amount DECIMAL(10,2) NOT NULL,
    bid_time DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (item_id) REFERENCES auction_items(item_id),
    FOREIGN KEY (bidder_id) REFERENCES bidders(bidder_id)
);

CREATE TABLE watchlists (
    watchlist_id INT IDENTITY(1,1) PRIMARY KEY,
    bidder_id INT NOT NULL,
    item_id INT NOT NULL,
    added_at DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (bidder_id) REFERENCES bidders(bidder_id),
    FOREIGN KEY (item_id) REFERENCES auction_items(item_id),
    CONSTRAINT UQ_watchlist UNIQUE (bidder_id, item_id)
);

-- 4. กลุ่มหลังจบการประมูล (Post-Auction & Checkout)
CREATE TABLE winning_bids (
    winning_id INT IDENTITY(1,1) PRIMARY KEY,
    item_id INT UNIQUE NOT NULL,
    bidder_id INT NOT NULL,
    winning_price DECIMAL(10,2) NOT NULL,
    won_at DATETIME DEFAULT GETDATE(),
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'expired')),
    FOREIGN KEY (item_id) REFERENCES auction_items(item_id),
    FOREIGN KEY (bidder_id) REFERENCES bidders(bidder_id)
);

CREATE TABLE payments (
    payment_id INT IDENTITY(1,1) PRIMARY KEY,
    winning_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50),
    payment_time DATETIME,
    status VARCHAR(20) DEFAULT 'completed' CHECK (status IN ('completed', 'failed', 'refunded')),
    FOREIGN KEY (winning_id) REFERENCES winning_bids(winning_id)
);

CREATE TABLE shipping_details (
    shipping_id INT IDENTITY(1,1) PRIMARY KEY,
    winning_id INT NOT NULL,
    recipient_name VARCHAR(150) NOT NULL,
    shipping_address VARCHAR(MAX) NOT NULL,
    carrier_name VARCHAR(100),
    tracking_number VARCHAR(100),
    shipping_status VARCHAR(20) DEFAULT 'pending' CHECK (shipping_status IN ('pending', 'shipped', 'delivered')),
    FOREIGN KEY (winning_id) REFERENCES winning_bids(winning_id)
);