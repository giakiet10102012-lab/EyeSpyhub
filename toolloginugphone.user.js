// ==UserScript==
// @name         UgPhone Session Manager Pro
// @namespace    https://ugphone.com/
// @version      2.0
// @description  Giao diện Inject Session cao cấp dành riêng cho UgPhone, không lưu cứng dữ liệu, tự động reload
// @author       Gemini
// @match        https://*.ugphone.com/*
// @match        http://*.ugphone.com/*
// @run-at       document-idle
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // 1. Nhúng CSS giao diện phong cách Glassmorphism & Cyberpunk Neon
    const style = document.createElement('style');
    style.textContent = `
        .ug-floating-btn {
            position: fixed;
            bottom: 25px;
            right: 25px;
            width: 54px;
            height: 54px;
            border-radius: 50%;
            background: linear-gradient(135deg, #6366f1 0%, #a855f7 50%, #ec4899 100%);
            box-shadow: 0 6px 20px rgba(168, 85, 247, 0.45), 0 0 15px rgba(99, 102, 241, 0.3);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            z-index: 999999;
            transition: all 0.3s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            border: 2px solid rgba(255, 255, 255, 0.2);
            user-select: none;
        }
        .ug-floating-btn:hover {
            transform: scale(1.12) rotate(8deg);
            box-shadow: 0 10px 30px rgba(236, 72, 153, 0.6), 0 0 25px rgba(168, 85, 247, 0.5);
        }
        .ug-floating-btn:active {
            transform: scale(0.95);
        }
        .ug-floating-btn svg {
            width: 28px;
            height: 28px;
            fill: #ffffff;
            filter: drop-shadow(0 2px 4px rgba(0,0,0,0.3));
        }

        .ug-modal-overlay {
            display: none;
            position: fixed;
            inset: 0;
            background: rgba(10, 12, 20, 0.65);
            backdrop-filter: blur(8px);
            -webkit-backdrop-filter: blur(8px);
            z-index: 1000000;
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        .ug-modal-overlay.active {
            display: flex;
            align-items: center;
            justify-content: center;
            opacity: 1;
        }

        .ug-modal-card {
            width: 480px;
            max-width: 90vw;
            background: rgba(18, 22, 36, 0.85);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 18px;
            padding: 24px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.7), 0 0 30px rgba(99, 102, 241, 0.15);
            color: #f8fafc;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            transform: scale(0.95);
            transition: transform 0.3s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .ug-modal-overlay.active .ug-modal-card {
            transform: scale(1);
        }

        .ug-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 14px;
        }
        .ug-header-title {
            font-size: 17px;
            font-weight: 700;
            letter-spacing: 0.5px;
            background: linear-gradient(90deg, #a5b4fc, #f472b6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            display: flex;
            align-items: center;
            gap: 8px;
        }
        .ug-close-icon {
            cursor: pointer;
            width: 24px;
            height: 24px;
            border-radius: 50%;
            background: rgba(255, 255, 255, 0.08);
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 13px;
            color: #94a3b8;
            transition: 0.2s;
        }
        .ug-close-icon:hover {
            background: rgba(239, 68, 68, 0.2);
            color: #ef4444;
        }

        .ug-textarea {
            width: 100%;
            height: 190px;
            background: rgba(11, 14, 23, 0.75);
            border: 1px solid rgba(255, 255, 255, 0.08);
            border-radius: 10px;
            padding: 12px;
            color: #38bdf8;
            font-family: "Fira Code", Consolas, Monaco, monospace;
            font-size: 12px;
            line-height: 1.5;
            resize: vertical;
            outline: none;
            box-sizing: border-box;
            transition: border-color 0.2s;
        }
        .ug-textarea:focus {
            border-color: #818cf8;
            box-shadow: 0 0 10px rgba(129, 140, 248, 0.25);
        }
        .ug-textarea::placeholder {
            color: #475569;
            font-family: sans-serif;
            font-size: 12px;
        }

        .ug-footer {
            display: flex;
            justify-content: flex-end;
            gap: 10px;
            margin-top: 18px;
        }
        .ug-btn {
            border: none;
            border-radius: 9px;
            padding: 10px 18px;
            font-size: 13px;
            font-weight: 600;
            cursor: pointer;
            transition: all 0.2s;
        }
        .ug-btn-cancel {
            background: rgba(255, 255, 255, 0.07);
            color: #94a3b8;
        }
        .ug-btn-cancel:hover {
            background: rgba(255, 255, 255, 0.12);
            color: #f1f5f9;
        }
        .ug-btn-submit {
            background: linear-gradient(135deg, #4f46e5, #9333ea);
            color: #ffffff;
            box-shadow: 0 4px 14px rgba(79, 70, 229, 0.35);
        }
        .ug-btn-submit:hover {
            background: linear-gradient(135deg, #4338ca, #7e22ce);
            box-shadow: 0 6px 18px rgba(147, 51, 234, 0.45);
            transform: translateY(-1px);
        }
    `;
    document.head.appendChild(style);

    // 2. Tạo nút mở giao diện (Icon Cloud Phone công nghệ)
    const toggleBtn = document.createElement('div');
    toggleBtn.className = 'ug-floating-btn';
    toggleBtn.title = 'Mở UgPhone Injector';
    toggleBtn.innerHTML = `
        <svg viewBox="0 0 24 24">
            <path d="M19.35 10.04C18.67 6.59 15.64 4 12 4 9.11 4 6.6 5.64 5.35 8.04 2.34 8.36 0 10.91 0 14c0 3.31 2.69 6 6 6h13c2.76 0 5-2.24 5-5 0-2.64-2.05-4.78-4.65-4.96zM14 13v4h-4v-4H7l5-5 5 5h-3z"/>
        </svg>
    `;
    document.body.appendChild(toggleBtn);

    // 3. Tạo khung Popup Modal
    const overlay = document.createElement('div');
    overlay.className = 'ug-modal-overlay';
    overlay.innerHTML = `
        <div class="ug-modal-card">
            <div class="ug-header">
                <div class="ug-header-title">
                    <span style="font-size: 18px;">⚡</span> UGPHONE SESSION INJECTOR
                </div>
                <div class="ug-close-icon" id="ugCloseBtn">✕</div>
            </div>
            <textarea class="ug-textarea" id="ugPayloadInput" placeholder="Dán toàn bộ mã JSON session của bạn vào đây...&#10;Ví dụ:&#10;{&#10;  &quot;UGPHONE-ID&quot;: &quot;...&quot;,&#10;  &quot;UGPHONE-Token&quot;: &quot;...&quot;&#10;}"></textarea>
            <div class="ug-footer">
                <button class="ug-btn ug-btn-cancel" id="ugCancelBtn">Hủy</button>
                <button class="ug-btn ug-btn-submit" id="ugSubmitBtn">Nạp & Vào Acc</button>
            </div>
        </div>
    `;
    document.body.appendChild(overlay);

    const inputArea = overlay.querySelector('#ugPayloadInput');
    const closeBtn = overlay.querySelector('#ugCloseBtn');
    const cancelBtn = overlay.querySelector('#ugCancelBtn');
    const submitBtn = overlay.querySelector('#ugSubmitBtn');

    // Bật/tắt Modal
    function openModal() {
        overlay.classList.add('active');
        inputArea.focus();
    }

    function closeModal() {
        overlay.classList.remove('active');
    }

    toggleBtn.addEventListener('click', openModal);
    closeBtn.addEventListener('click', closeModal);
    cancelBtn.addEventListener('click', closeModal);
    overlay.addEventListener('click', (e) => {
        if (e.target === overlay) closeModal();
    });

    // 4. Xử lý nạp dữ liệu và tải lại trang
    submitBtn.addEventListener('click', () => {
        const raw = inputArea.value.trim();
        if (!raw) {
            alert('Vui lòng dán chuỗi JSON session trước khi nạp!');
            return;
        }

        try {
            const data = JSON.parse(raw);

            // Nạp vào LocalStorage và Cookie
            for (const [key, value] of Object.entries(data)) {
                const valStr = typeof value === 'object' ? JSON.stringify(value) : String(value);
                localStorage.setItem(key, valStr);
                document.cookie = `${key}=${encodeURIComponent(valStr)}; path=/; domain=.ugphone.com; max-age=86400`;
            }

            // Tự động tải lại trang ngay lập tức
            window.location.reload();
        } catch (err) {
            alert('Dữ liệu JSON không đúng định dạng! Chi tiết: ' + err.message);
        }
    });
})();
