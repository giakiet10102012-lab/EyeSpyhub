// ==UserScript==
// @name         UgPhone Multi-Account Manager Pro
// @namespace    https://ugphone.com/
// @version      3.0
// @description  Quản lý, chuyển đổi nhiều acc UgPhone 1-click, lưu lịch sử, giao diện đặt ngay phía trên nút bấm
// @author       Gemini
// @match        https://*.ugphone.com/*
// @match        http://*.ugphone.com/*
// @run-at       document-idle
// @grant        GM_setValue
// @grant        GM_getValue
// ==/UserScript==

(function () {
    'use strict';

    // 1. Quản lý lưu trữ thông qua GM Storage (chống bị web UgPhone xóa nhầm)
    const getSavedAccounts = () => {
        try {
            if (typeof GM_getValue === 'function') return GM_getValue('ug_accounts_vault', []);
        } catch (e) {}
        return JSON.parse(localStorage.getItem('__ug_accounts_vault__') || '[]');
    };

    const saveAccounts = (accList) => {
        try {
            if (typeof GM_setValue === 'function') {
                GM_setValue('ug_accounts_vault', accList);
                return;
            }
        } catch (e) {}
        localStorage.setItem('__ug_accounts_vault__', JSON.stringify(accList));
    };

    // 2. Logic nạp Session & Reload
    const applySessionAndReload = (sessionData) => {
        for (const [key, value] of Object.entries(sessionData)) {
            const valStr = typeof value === 'object' ? JSON.stringify(value) : String(value);
            localStorage.setItem(key, valStr);
            document.cookie = `${key}=${encodeURIComponent(valStr)}; path=/; domain=.ugphone.com; max-age=86400`;
        }
        window.location.reload();
    };

    // 3. Nhúng CSS Giao diện Cyber-Glassmorphism dọc
    const style = document.createElement('style');
    style.textContent = `
        /* Nút kích hoạt tròn góc phải dưới */
        .ug-main-btn {
            position: fixed;
            bottom: 20px;
            right: 20px;
            width: 52px;
            height: 52px;
            border-radius: 50%;
            background: linear-gradient(135deg, #4f46e5 0%, #7c3aed 50%, #db2777 100%);
            box-shadow: 0 6px 18px rgba(124, 58, 237, 0.45);
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            z-index: 9999999;
            transition: all 0.25s cubic-bezier(0.175, 0.885, 0.32, 1.275);
            border: 2px solid rgba(255, 255, 255, 0.25);
            user-select: none;
        }
        .ug-main-btn:hover {
            transform: scale(1.08);
            box-shadow: 0 8px 25px rgba(219, 39, 119, 0.6);
        }
        .ug-main-btn svg {
            width: 26px;
            height: 26px;
            fill: #ffffff;
        }

        /* Bảng Menu Dọc đặt ngay trên nút */
        .ug-dock-panel {
            display: none;
            position: fixed;
            bottom: 82px;
            right: 20px;
            width: 340px;
            height: 520px;
            background: rgba(13, 17, 28, 0.94);
            backdrop-filter: blur(20px);
            -webkit-backdrop-filter: blur(20px);
            border: 1px solid rgba(255, 255, 255, 0.12);
            border-radius: 16px;
            box-shadow: 0 16px 40px rgba(0, 0, 0, 0.7), 0 0 20px rgba(99, 102, 241, 0.2);
            z-index: 9999998;
            flex-direction: column;
            overflow: hidden;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            color: #e2e8f0;
            animation: ugSlideUp 0.2s cubic-bezier(0.16, 1, 0.3, 1);
        }
        .ug-dock-panel.active {
            display: flex;
        }
        @keyframes ugSlideUp {
            from { opacity: 0; transform: translateY(12px) scale(0.96); }
            to { opacity: 1; transform: translateY(0) scale(1); }
        }

        /* Header */
        .ug-panel-header {
            padding: 12px 14px;
            display: flex;
            align-items: center;
            justify-content: space-between;
            border-bottom: 1px solid rgba(255, 255, 255, 0.08);
            background: rgba(255, 255, 255, 0.02);
        }
        .ug-panel-title {
            font-size: 14px;
            font-weight: 700;
            background: linear-gradient(90deg, #818cf8, #f472b6);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            display: flex;
            align-items: center;
            gap: 6px;
        }
        .ug-close-btn {
            cursor: pointer;
            font-size: 14px;
            color: #94a3b8;
            padding: 2px 6px;
            border-radius: 4px;
            transition: 0.2s;
        }
        .ug-close-btn:hover {
            color: #ef4444;
            background: rgba(239, 68, 68, 0.15);
        }

        /* Tab Controller */
        .ug-tab-nav {
            display: flex;
            padding: 6px 10px;
            background: rgba(0, 0, 0, 0.25);
            gap: 6px;
        }
        .ug-tab-item {
            flex: 1;
            text-align: center;
            padding: 7px 0;
            font-size: 12px;
            font-weight: 600;
            border-radius: 8px;
            cursor: pointer;
            color: #94a3b8;
            transition: all 0.2s;
            user-select: none;
        }
        .ug-tab-item.active {
            background: rgba(99, 102, 241, 0.25);
            color: #38bdf8;
            box-shadow: inset 0 0 0 1px rgba(99, 102, 241, 0.4);
        }

        /* Body Views */
        .ug-view-content {
            flex: 1;
            padding: 12px;
            display: flex;
            flex-direction: column;
            overflow: hidden;
        }
        .ug-view-tab {
            display: none;
            height: 100%;
            flex-direction: column;
        }
        .ug-view-tab.active {
            display: flex;
        }

        /* Form Nhập Session */
        .ug-input-label {
            font-size: 11px;
            color: #94a3b8;
            margin-bottom: 4px;
            font-weight: 600;
        }
        .ug-input-text {
            width: 100%;
            background: rgba(18, 24, 38, 0.8);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 7px;
            padding: 8px 10px;
            font-size: 12px;
            color: #f1f5f9;
            outline: none;
            box-sizing: border-box;
            margin-bottom: 10px;
        }
        .ug-input-text:focus {
            border-color: #6366f1;
        }
        .ug-input-area {
            flex: 1;
            width: 100%;
            background: rgba(18, 24, 38, 0.8);
            border: 1px solid rgba(255, 255, 255, 0.1);
            border-radius: 7px;
            padding: 8px 10px;
            font-size: 11px;
            font-family: Consolas, monospace;
            color: #38bdf8;
            outline: none;
            resize: none;
            box-sizing: border-box;
            margin-bottom: 10px;
        }
        .ug-input-area:focus {
            border-color: #6366f1;
        }
        .ug-btn-group {
            display: flex;
            gap: 8px;
        }
        .ug-btn-action {
            flex: 1;
            padding: 8px 0;
            border: none;
            border-radius: 7px;
            font-size: 12px;
            font-weight: 600;
            cursor: pointer;
            transition: 0.2s;
        }
        .ug-btn-save {
            background: rgba(255, 255, 255, 0.08);
            color: #cbd5e1;
        }
        .ug-btn-save:hover {
            background: rgba(255, 255, 255, 0.15);
            color: #ffffff;
        }
        .ug-btn-apply {
            background: linear-gradient(135deg, #4f46e5, #7c3aed);
            color: #ffffff;
        }
        .ug-btn-apply:hover {
            opacity: 0.92;
            transform: translateY(-1px);
        }

        /* Danh Sách Tài Khoản */
        .ug-acc-list {
            flex: 1;
            overflow-y: auto;
            display: flex;
            flex-direction: column;
            gap: 8px;
            padding-right: 4px;
        }
        .ug-acc-list::-webkit-scrollbar {
            width: 4px;
        }
        .ug-acc-list::-webkit-scrollbar-thumb {
            background: rgba(255, 255, 255, 0.15);
            border-radius: 4px;
        }
        .ug-acc-card {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid rgba(255, 255, 255, 0.06);
            border-radius: 10px;
            padding: 10px;
            display: flex;
            flex-direction: column;
            gap: 6px;
            transition: all 0.2s;
        }
        .ug-acc-card:hover {
            border-color: rgba(99, 102, 241, 0.4);
            background: rgba(255, 255, 255, 0.05);
        }
        .ug-acc-card.current {
            border-color: #22c55e;
            background: rgba(34, 197, 94, 0.06);
        }
        .ug-acc-top {
            display: flex;
            justify-content: space-between;
            align-items: center;
        }
        .ug-acc-name {
            font-size: 13px;
            font-weight: 700;
            color: #f8fafc;
            white-space: nowrap;
            overflow: hidden;
            text-overflow: ellipsis;
            max-width: 170px;
        }
        .ug-badge-active {
            font-size: 9px;
            background: rgba(34, 197, 94, 0.2);
            color: #4ade80;
            border: 1px solid rgba(34, 197, 94, 0.3);
            border-radius: 4px;
            padding: 1px 5px;
            font-weight: 700;
        }
        .ug-acc-id {
            font-size: 10px;
            color: #64748b;
            font-family: monospace;
        }
        .ug-acc-actions {
            display: flex;
            align-items: center;
            gap: 6px;
            margin-top: 4px;
        }
        .ug-btn-login-acc {
            flex: 1;
            padding: 5px 0;
            background: linear-gradient(135deg, #059669, #10b981);
            color: #ffffff;
            border: none;
            border-radius: 6px;
            font-size: 11px;
            font-weight: 600;
            cursor: pointer;
            transition: 0.2s;
        }
        .ug-btn-login-acc:hover {
            filter: brightness(1.1);
        }
        .ug-btn-mini {
            padding: 4px 8px;
            background: rgba(255, 255, 255, 0.06);
            border: none;
            border-radius: 6px;
            color: #94a3b8;
            font-size: 11px;
            cursor: pointer;
            transition: 0.2s;
        }
        .ug-btn-mini:hover {
            color: #ffffff;
            background: rgba(255, 255, 255, 0.15);
        }
        .ug-btn-del:hover {
            color: #f87171;
            background: rgba(239, 68, 68, 0.15);
        }
        .ug-empty-hint {
            text-align: center;
            margin-top: 50px;
            color: #64748b;
            font-size: 12px;
            line-height: 1.6;
        }
    `;
    document.head.appendChild(style);

    // 4. Tạo Nút Tròn Mở Menu (Góc phải dưới)
    const mainBtn = document.createElement('div');
    mainBtn.className = 'ug-main-btn';
    mainBtn.title = 'UgPhone Account Hub';
    mainBtn.innerHTML = `
        <svg viewBox="0 0 24 24">
            <path d="M4 6h16v2H4zm0 5h16v2H4zm0 5h16v2H4z"/>
        </svg>
    `;
    document.body.appendChild(mainBtn);

    // 5. Tạo Khung Menu Dọc Nằm Trên Nút Bấm
    const panel = document.createElement('div');
    panel.className = 'ug-dock-panel';
    panel.innerHTML = `
        <div class="ug-panel-header">
            <div class="ug-panel-title">
                <span>⚡</span> UGPHONE HUB
            </div>
            <div class="ug-close-btn" id="ugCloseBtn">✕</div>
        </div>

        <div class="ug-tab-nav">
            <div class="ug-tab-item active" data-tab="tab-input">📥 Nhập Session</div>
            <div class="ug-tab-item" data-tab="tab-accounts" id="ugTabAccountsTitle">👥 Acc (<span id="ugAccCount">0</span>)</div>
        </div>

        <div class="ug-view-content">
            <!-- TAB 1: NHẬP SESSION -->
            <div class="ug-view-tab active" id="tab-input">
                <div class="ug-input-label">TÊN GỢI NHỚ</div>
                <input class="ug-input-text" id="ugAccNameInput" placeholder="Ví dụ: Acc Chính, Acc Treo Game 01..." />
                
                <div class="ug-input-label">DỮ LIỆU LOCALSTORAGE (JSON)</div>
                <textarea class="ug-input-area" id="ugJsonInput" placeholder="Dán toàn bộ mã JSON session của bạn vào đây..."></textarea>
                
                <div class="ug-btn-group">
                    <button class="ug-btn-action ug-btn-save" id="ugSaveOnlyBtn">Chỉ Lưu</button>
                    <button class="ug-btn-action ug-btn-apply" id="ugSaveAndLoginBtn">Lưu & Vào Ngay</button>
                </div>
            </div>

            <!-- TAB 2: DANH SÁCH ACC -->
            <div class="ug-view-tab" id="tab-accounts">
                <div class="ug-acc-list" id="ugAccContainer"></div>
            </div>
        </div>
    `;
    document.body.appendChild(panel);

    // 6. Xử lý logic Tab & UI
    const tabItems = panel.querySelectorAll('.ug-tab-item');
    const tabViews = panel.querySelectorAll('.ug-view-tab');
    const nameInput = panel.querySelector('#ugAccNameInput');
    const jsonInput = panel.querySelector('#ugJsonInput');
    const accContainer = panel.querySelector('#ugAccContainer');
    const accCount = panel.querySelector('#ugAccCount');

    function switchTab(targetTabId) {
        tabItems.forEach(tab => {
            tab.classList.toggle('active', tab.dataset.tab === targetTabId);
        });
        tabViews.forEach(view => {
            view.classList.toggle('active', view.id === targetTabId);
        });
        if (targetTabId === 'tab-accounts') {
            renderAccountList();
        }
    }

    tabItems.forEach(tab => {
        tab.addEventListener('click', () => switchTab(tab.dataset.tab));
    });

    // Toggle menu
    mainBtn.addEventListener('click', () => {
        panel.classList.toggle('active');
        if (panel.classList.contains('active')) {
            renderAccountList();
        }
    });

    panel.querySelector('#ugCloseBtn').addEventListener('click', () => {
        panel.classList.remove('active');
    });

    // 7. Render danh sách tài khoản
    function renderAccountList() {
        const accounts = getSavedAccounts();
        accCount.textContent = accounts.length;
        accContainer.innerHTML = '';

        if (accounts.length === 0) {
            accContainer.innerHTML = `
                <div class="ug-empty-hint">
                    Chưa có tài khoản nào được lưu.<br>
                    Hãy sang tab <b>Nhập Session</b> để thêm tài khoản mới!
                </div>
            `;
            return;
        }

        const currentLocalId = localStorage.getItem('UGPHONE-ID');

        accounts.forEach((acc, index) => {
            const isCurrent = acc.data && acc.data['UGPHONE-ID'] === currentLocalId;
            const deviceId = acc.data && acc.data['UGPHONE-ID'] ? acc.data['UGPHONE-ID'] : 'N/A';

            const card = document.createElement('div');
            card.className = `ug-acc-card ${isCurrent ? 'current' : ''}`;
            card.innerHTML = `
                <div class="ug-acc-top">
                    <div class="ug-acc-name" title="${acc.name}">${acc.name}</div>
                    ${isCurrent ? '<span class="ug-badge-active">Đang dùng</span>' : ''}
                </div>
                <div class="ug-acc-id">ID: ${deviceId.substring(0, 16)}...</div>
                <div class="ug-acc-actions">
                    <button class="ug-btn-login-acc" data-idx="${index}">▶ Vào Acc</button>
                    <button class="ug-btn-mini ug-btn-rename" data-idx="${index}" title="Đổi tên">✏️</button>
                    <button class="ug-btn-mini ug-btn-del" data-idx="${index}" title="Xóa">🗑️</button>
                </div>
            `;

            // 1-Click Vào Acc
            card.querySelector('.ug-btn-login-acc').onclick = () => {
                applySessionAndReload(acc.data);
            };

            // Đổi tên tài khoản
            card.querySelector('.ug-btn-rename').onclick = () => {
                const newName = prompt('Nhập tên mới cho tài khoản:', acc.name);
                if (newName && newName.trim() !== '') {
                    accounts[index].name = newName.trim();
                    saveAccounts(accounts);
                    renderAccountList();
                }
            };

            // Xóa tài khoản
            card.querySelector('.ug-btn-del').onclick = () => {
                if (confirm(`Bạn có chắc chắn muốn xóa tài khoản "${acc.name}" không?`)) {
                    accounts.splice(index, 1);
                    saveAccounts(accounts);
                    renderAccountList();
                }
            };

            accContainer.appendChild(card);
        });
    }

    // 8. Xử lý Lưu tài khoản từ Tab 1
    function handleSave(autoLogin = false) {
        const rawJson = jsonInput.value.trim();
        let accName = nameInput.value.trim();

        if (!rawJson) {
            alert('Vui lòng dán chuỗi JSON session trước!');
            return;
        }

        try {
            const parsedData = JSON.parse(rawJson);
            const accounts = getSavedAccounts();

            if (!accName) {
                accName = `Acc ${accounts.length + 1}`;
            }

            const newAcc = {
                id: 'acc_' + Date.now(),
                name: accName,
                createdAt: Date.now(),
                data: parsedData
            };

            accounts.unshift(newAcc);
            saveAccounts(accounts);

            // Xóa trắng form
            nameInput.value = '';
            jsonInput.value = '';

            if (autoLogin) {
                applySessionAndReload(parsedData);
            } else {
                alert(`Đã lưu tài khoản "${accName}" thành công!`);
                switchTab('tab-accounts');
            }
        } catch (e) {
            alert('Dữ liệu JSON không hợp lệ! Vui lòng kiểm tra lại.\nLỗi: ' + e.message);
        }
    }

    panel.querySelector('#ugSaveOnlyBtn').onclick = () => handleSave(false);
    panel.querySelector('#ugSaveAndLoginBtn').onclick = () => handleSave(true);

    // Khởi chạy lấy số lượng acc ban đầu
    accCount.textContent = getSavedAccounts().length;
})();
