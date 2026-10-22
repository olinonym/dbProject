document.addEventListener("DOMContentLoaded", () => {
    
    // ------------------------------------------------------------
    // 1. ดึงรายการสินค้าจาก SQL Server ผ่าน API (/api/items)
    // ------------------------------------------------------------
    const productContainer = document.querySelector('.product-grid') || document.getElementById('product-list');

    async function fetchProducts() {
        if (!productContainer) return;

        try {
            const response = await fetch('http://localhost:3000/api/items');
            const items = await response.json();

            // ล้าง HTML Mock Data เก่าออก
            productContainer.innerHTML = '';

            items.forEach(item => {
                // คำนวณเวลาถอยหลังจาก end_time ในฐานข้อมูลจริง
                const now = new Date().getTime();
                const endTime = new Date(item.end_time).getTime();
                const secondsLeft = Math.max(0, Math.floor((endTime - now) / 1000));

                const itemCard = document.createElement('div');
                itemCard.className = 'product-card';
                itemCard.innerHTML = `
                    <div class="card-image">
                        <img src="${item.image_url || 'https://picsum.photos/600/400'}" alt="${item.product_name}">
                        <button class="heart-abs">🤍</button>
                    </div>
                    <div class="card-body">
                        <span class="category">${item.category_name}</span>
                        <h3>${item.product_name}</h3>
                        <p class="price">ราคาปัจจุบัน: <strong>฿${Number(item.current_price).toLocaleString()}</strong></p>
                        
                        <!-- Real-time Countdown Timer -->
                        <div class="countdown-timer" data-seconds="${secondsLeft}">
                            ⏱️ เหลือเวลา: <span class="hrs">00</span>:<span class="mins">00</span>:<span class="secs">00</span>
                        </div>

                        ${item.status === 'active' && secondsLeft > 0 ? `
                            <div class="bid-action" style="margin-top: 10px;">
                                <input type="number" id="bid-input-${item.item_id}" value="${item.current_price + 50}" step="50" style="width: 100px; padding: 5px;">
                                <button class="btn-bid" onclick="placeBid(${item.item_id})" style="padding: 5px 15px; cursor: pointer;">เคาะราคา</button>
                            </div>
                        ` : '<span class="status-closed" style="color: red; font-weight: bold;">ปิดการประมูลแล้ว</span>'}
                    </div>
                `;
                productContainer.appendChild(itemCard);
            });

            // เรียกใช้นับเวลาและระบบกดหัวใจให้ Card ที่เพิ่งสร้าง
            initCountdowns();
            initHearts();

        } catch (error) {
            console.error('Error fetching items:', error);
        }
    }

    // ------------------------------------------------------------
    // 2. ระบบนับเวลาถอยหลัง (Real-time Countdown Timer)
    // ------------------------------------------------------------
    function initCountdowns() {
        const timers = document.querySelectorAll('.countdown-timer');
        
        timers.forEach(timer => {
            if (timer.dataset.started) return; // ป้องกันการสร้าง Interval ซ้ำ
            timer.dataset.started = "true";

            let totalSeconds = parseInt(timer.getAttribute('data-seconds'), 10);
            
            const updateTimer = () => {
                if (totalSeconds <= 0) {
                    timer.innerHTML = "<span style='color:red; font-weight:bold;'>หมดเวลาประมูล!</span>";
                    return;
                }
                
                const h = Math.floor(totalSeconds / 3600);
                const m = Math.floor((totalSeconds % 3600) / 60);
                const s = totalSeconds % 60;
                
                const hoursEl = timer.querySelector('.hrs');
                const minsEl = timer.querySelector('.mins');
                const secsEl = timer.querySelector('.secs');
                
                if(hoursEl) hoursEl.textContent = String(h).padStart(2, '0');
                if(minsEl) minsEl.textContent = String(m).padStart(2, '0');
                if(secsEl) secsEl.textContent = String(s).padStart(2, '0');

                totalSeconds--;
            };
            
            updateTimer();
            setInterval(updateTimer, 1000);
        });
    }

    // ------------------------------------------------------------
    // 3. ปุ่มกดเคาะราคา (เรียกใช้ Stored Procedure sp_PlaceBid ผ่าน API)
    // ------------------------------------------------------------
    window.placeBid = async function(itemId) {
        const inputEl = document.getElementById(`bid-input-${itemId}`);
        const bidAmount = parseFloat(inputEl.value);
        const bidderId = 1; // สมมติรหัสผู้ประมูลปัจจุบัน (Bidder ID = 1)

        if (!bidAmount || isNaN(bidAmount)) {
            alert('กรุณากรอกจำนวนเงินที่ต้องการประมูล');
            return;
        }

        try {
            const response = await fetch('http://localhost:3000/api/place-bid', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    item_id: itemId,
                    bidder_id: bidderId,
                    bid_amount: bidAmount
                })
            });

            const result = await response.json();

            if (result.success) {
                alert('🎉 ' + result.message);
                fetchProducts(); // โหลดรายการสินค้าใหม่ทันทีเพื่ออัปเดตราคาสูงสุดหน้าเว็บ
            } else {
                alert('❌ ไม่สามารถเคาะราคาได้: ' + result.message);
            }
        } catch (error) {
            console.error('Bid Error:', error);
            alert('เกิดข้อผิดพลาดในการเชื่อมต่อ Server');
        }
    };

    // ------------------------------------------------------------
    // 4. ระบบสลับรูปภาพ (Image Gallery) ในหน้า Detail
    // ------------------------------------------------------------
    const mainImg = document.getElementById('main-product-img');
    const thumbnails = document.querySelectorAll('.gallery-thumbs img');
    
    if (mainImg && thumbnails.length > 0) {
        thumbnails.forEach(thumb => {
            thumb.addEventListener('click', function() {
                mainImg.src = this.src;
                thumbnails.forEach(t => t.classList.remove('active'));
                this.classList.add('active');
            });
        });
    }

    // ------------------------------------------------------------
    // 5. ระบบกดหัวใจ (Favorite)
    // ------------------------------------------------------------
    function initHearts() {
        const hearts = document.querySelectorAll('.heart-abs');
        hearts.forEach(heart => {
            heart.addEventListener('click', function(e) {
                e.preventDefault();
                this.classList.toggle('active');
                this.textContent = this.classList.contains('active') ? '💙' : '🤍';
            });
        });
    }

    // เริ่มรันดึงข้อมูลทันทีเมื่อเปิดหน้าเว็บ
    fetchProducts();
});