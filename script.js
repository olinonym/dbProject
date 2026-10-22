document.addEventListener("DOMContentLoaded", () => {

    // ------------------------------------------------------------
    // 1. ดึงรายการสินค้าหน้าหลัก (index.html)
    // ------------------------------------------------------------
    const productContainer = document.querySelector('.product-grid') || document.getElementById('product-list');

    async function fetchProducts() {
        if (!productContainer) return;

        try {
            const response = await fetch('http://localhost:3000/api/items');
            const items = await response.json();

            productContainer.innerHTML = '';

            items.forEach(item => {
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
            if (timer.dataset.started) return;
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

                if (hoursEl) hoursEl.textContent = String(h).padStart(2, '0');
                if (minsEl) minsEl.textContent = String(m).padStart(2, '0');
                if (secsEl) secsEl.textContent = String(s).padStart(2, '0');

                totalSeconds--;
            };

            updateTimer();
            setInterval(updateTimer, 1000);
        });
    }

    // ------------------------------------------------------------
    // 3. ปุ่มกดเคาะราคาหน้าหลัก (placeBid)
    // ------------------------------------------------------------
    window.placeBid = async function (itemId) {
        const inputEl = document.getElementById(`bid-input-${itemId}`);
        const bidAmount = parseFloat(inputEl.value);
        const bidderId = 1; // สมมติ User ID = 1

        if (!bidAmount || isNaN(bidAmount)) {
            alert('กรุณากรอกจำนวนเงินที่ต้องการประมูล');
            return;
        }

        try {
            const response = await fetch('http://localhost:3000/api/place-bid', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ item_id: itemId, bidder_id: bidderId, bid_amount: bidAmount })
            });

            const result = await response.json();

            if (result.success) {
                alert('🎉 ' + result.message);
                fetchProducts(); // โหลดการ์ดหน้าหลักใหม่
                fetchMyBids();   // อัปเดตตารางหน้า bids.html
            } else {
                alert('❌ ไม่สามารถเคาะราคาได้: ' + result.message);
            }
        } catch (error) {
            console.error('Bid Error:', error);
            alert('เกิดข้อผิดพลาดในการเชื่อมต่อ Server');
        }
    };

    // ------------------------------------------------------------
    // 4. ดึงรายการการเสนอราคาของผู้ใช้ (รองรับทั้ง index.html และ bids.html)
    // ------------------------------------------------------------
    async function fetchMyBids() {
        const myBidsContainer = document.getElementById('my-bids-container');
        const elSidebarCount = document.getElementById('sidebar-bids-count');

        // ถ้าไม่มีทั้งตาราง และไม่มีตัวเลข Sidebar ให้ข้าม
        if (!myBidsContainer && !elSidebarCount) return;

        try {
            const bidderId = 1;
            const response = await fetch(`http://localhost:3000/api/bids/user/${bidderId}`);
            
            if (!response.ok) return;

            const bids = await response.json();

            // ------------------------------------------------------------
            // อัปเดตตัวเลขสรุปผลและ Sidebar (ทำงานได้ทุกหน้า)
            // ------------------------------------------------------------
            if (Array.isArray(bids)) {
                const totalCount = bids.length;
                const leadingItems = bids.filter(item => item.bid_status === 'คุณเป็นผู้นำ');
                const outbidItems = bids.filter(item => item.bid_status === 'ถูกเสนอแซง');

                const leadingCount = leadingItems.length;
                const outbidCount = outbidItems.length;

                const leadingSum = leadingItems.reduce((sum, item) => sum + Number(item.my_last_bid), 0);
                const totalSum = bids.reduce((sum, item) => sum + Number(item.my_last_bid), 0);

                // 🟢 อัปเดตตัวเลขบน Sidebar ด้านซ้าย (ได้ทั้ง index.html และ bids.html)
                if (elSidebarCount) elSidebarCount.textContent = String(totalCount).padStart(2, '0');

                // อัปเดตการ์ด 4 กล่องหน้า bids.html
                const elTotal = document.getElementById('stat-total');
                const elLeading = document.getElementById('stat-leading');
                const elLeadingAmount = document.getElementById('stat-leading-amount');
                const elOutbid = document.getElementById('stat-outbid');
                const elTotalAmount = document.getElementById('stat-total-amount');

                if (elTotal) elTotal.textContent = String(totalCount).padStart(2, '0');
                if (elLeading) elLeading.textContent = String(leadingCount).padStart(2, '0');
                if (elLeadingAmount) elLeadingAmount.textContent = `ราคารวม ฿${leadingSum.toLocaleString()}`;
                if (elOutbid) elOutbid.textContent = String(outbidCount).padStart(2, '0');
                if (elTotalAmount) elTotalAmount.textContent = `฿${totalSum.toLocaleString()}`;

                // อัปเดต Header Badge และ Tabs
                const elTopBadge = document.getElementById('top-badge');
                const elTabAll = document.getElementById('tab-all');
                const elTabLeading = document.getElementById('tab-leading');
                const elTabOutbid = document.getElementById('tab-outbid');

                if (elTopBadge) elTopBadge.textContent = `กำลังประมูล ${totalCount} รายการ`;
                if (elTabAll) elTabAll.textContent = `กำลังประมูล ${totalCount}`;
                if (elTabLeading) elTabLeading.textContent = `คุณเป็นผู้นำ ${leadingCount}`;
                if (elTabOutbid) elTabOutbid.textContent = `ถูกเสนอแซง ${outbidCount}`;

                // อัปเดต Alert Banner
                const elAlertBanner = document.getElementById('alert-banner');
                const elAlertText = document.getElementById('alert-text');

                if (elAlertBanner && elAlertText) {
                    if (outbidCount > 0) {
                        const outbidNames = outbidItems.slice(0, 2).map(item => item.product_name).join(' และ ');
                        const extraText = outbidCount > 2 ? ` และอีก ${outbidCount - 2} รายการ` : '';
                        elAlertText.textContent = `คุณถูกเสนอแซงใน ${outbidNames}${extraText} · โปรดตรวจสอบและเสนอราคาใหม่`;
                        elAlertBanner.style.display = 'flex';
                    } else {
                        elAlertBanner.style.display = 'none';
                    }
                }
            }

            // ------------------------------------------------------------
            // อัปเดตข้อมูลลงตาราง (ทำงานเฉพาะหน้า bids.html)
            // ------------------------------------------------------------
            if (myBidsContainer) {
                if (!Array.isArray(bids) || bids.length === 0) {
                    myBidsContainer.innerHTML = '<div style="padding: 20px; text-align: center; color: var(--muted);">ยังไม่มีรายการที่คุณเข้าร่วมประมูล</div>';
                    return;
                }

                myBidsContainer.innerHTML = '';

                bids.forEach(item => {
                    const isLeading = item.bid_status === 'คุณเป็นผู้นำ';
                    const nextBidAmount = Number(item.current_price) + 50;

                    const row = document.createElement('div');
                    row.className = 'bid-row';
                    row.innerHTML = `
                        <div style="display: flex; gap: 12px; align-items: center; padding-right: 16px;">
                            <img src="${item.image_url || 'https://picsum.photos/100/70'}" style="width: 80px; height: 56px; border-radius: 8px; object-fit: cover; border: 1px solid var(--line);">
                            <div>
                                <div style="font-weight: 600; color: var(--ink); margin-bottom: 4px;">${item.product_name}</div>
                                <div class="p-meta">${item.category_name}</div>
                            </div>
                        </div>
                        <div style="font-weight: 600; color: var(--ink);">฿${Number(item.my_last_bid).toLocaleString()}</div>
                        <div style="font-weight: 600; color: var(--blue);">฿${Number(item.current_price).toLocaleString()}</div>
                        <div>
                            <span class="status-pill ${isLeading ? 'green' : 'red'}">${item.bid_status}</span>
                        </div>
                        <div>
                            ${item.status === 'active' ? `
                                <button class="btn-primary" onclick="quickBid(${item.item_id},${nextBidAmount})" style="padding: 8px 16px; width: 100%; font-size: 13px;">
                                    ${isLeading ? 'เสนอราคาเพิ่ม' : `เสนอ ฿${nextBidAmount.toLocaleString()}`}
                                </button>
                            ` : '<span style="color:red; font-size:12px;">ปิดประมูลแล้ว</span>'}
                        </div>
                    `;
                    myBidsContainer.appendChild(row);
                });
            }

        } catch (error) {
            console.error('Error fetching my bids:', error);
        }
    }

    // ------------------------------------------------------------
    // 5. ระบบสลับรูปภาพ (Gallery) & หัวใจ
    // ------------------------------------------------------------
    const mainImg = document.getElementById('main-product-img');
    const thumbnails = document.querySelectorAll('.gallery-thumbs img');

    if (mainImg && thumbnails.length > 0) {
        thumbnails.forEach(thumb => {
            thumb.addEventListener('click', function () {
                mainImg.src = this.src;
                thumbnails.forEach(t => t.classList.remove('active'));
                this.classList.add('active');
            });
        });
    }

    function initHearts() {
        const hearts = document.querySelectorAll('.heart-abs');
        hearts.forEach(heart => {
            heart.addEventListener('click', function (e) {
                e.preventDefault();
                this.classList.toggle('active');
                this.textContent = this.classList.contains('active') ? '💙' : '🤍';
            });
        });
    }

    // เริ่มรันดึงข้อมูลอัตโนมัติ
    fetchProducts();
    fetchMyBids();
});