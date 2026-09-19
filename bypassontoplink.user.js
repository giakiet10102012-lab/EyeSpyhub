// ==UserScript==
// @name         Google SEO Traffic & Smart Bypass Engine
// @namespace    http://tampermonkey.net/
// @version      1.0.0
// @description  Bypass SEO Google cao cấp: Tìm kiếm tự động, phân tích URL đa tầng, lật trang, chống kẹt số 0 & tự điền mã.
// @author       MrDon & Assistant
// @match        *://*/*
// @include      *
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_deleteValue
// @grant        GM_setClipboard
// @grant        GM_addValueChangeListener
// @grant        GM_registerMenuCommand
// @grant        unsafeWindow
// @grant        window.close
// @run-at       document-end
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    try {
        if (window.self !== window.top) return;
    } catch (_) {
        return;
    }

    const IS_GOOGLE = /(^|\.)google\./i.test(location.hostname);
    const CODE_STORAGE_KEY = 'auto_bypass_code';
    const TASK_KEY = 'seo_task';
    const TASK_TIMEOUT_MS = 10 * 60 * 1000;

    const BANNER_KEYWORDS = ['banner', 'popup', 'float', 'close', 'openbanner', 'ad_', 'advertisement', 'overlay'];

    // =============================================================
    // 1. LỚP LƯU TRỮ HYBRID AN TOÀN
    // =============================================================

    const Storage = {
        get(key, fallback = null) {
            try {
                if (typeof GM_getValue === 'function') {
                    const val = GM_getValue(key, null);
                    if (val !== null && val !== undefined) return val;
                }
            } catch (_) {}
            try {
                const item = localStorage.getItem('__engine_' + key);
                return item ? JSON.parse(item) : fallback;
            } catch (_) {
                return fallback;
            }
        },
        set(key, value) {
            try {
                if (typeof GM_setValue === 'function') GM_setValue(key, value);
            } catch (_) {}
            try {
                localStorage.setItem('__engine_' + key, JSON.stringify(value));
            } catch (_) {}
        },
        delete(key) {
            try {
                if (typeof GM_deleteValue === 'function') GM_deleteValue(key);
            } catch (_) {}
            try {
                localStorage.removeItem('__engine_' + key);
            } catch (_) {}
        }
    };

    function getActiveTask() {
        const task = Storage.get(TASK_KEY, null);
        if (!task) return null;
        if (!task.timestamp || Date.now() - task.timestamp > TASK_TIMEOUT_MS) {
            Storage.delete(TASK_KEY);
            return null;
        }
        return task;
    }

    function saveTask(task) {
        task.timestamp = Date.now();
        Storage.set(TASK_KEY, task);
    }

    function clearTask() {
        Storage.delete(TASK_KEY);
    }

    // =============================================================
    // 2. PHÂN TÍCH & SO KHỚP URL GOOGLE
    // =============================================================

    function normalizeText(value) {
        return String(value || '')
            .toLowerCase()
            .normalize('NFKC')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function normalizeDomain(value) {
        return normalizeText(value)
            .replace(/^(?:https?:\/\/)?(?:www\.)?/i, '')
            .split('/')[0]
            .split('?')[0]
            .split('#')[0]
            .trim();
    }

    function cleanPath(path) {
        return String(path || '')
            .toLowerCase()
            .replace(/\/+/g, '/')
            .replace(/^\/|\/$/g, '')
            .replace(/[?#].*$/, '')
            .trim();
    }

    function getPathTokens(path) {
        const clean = cleanPath(path);
        if (!clean) return [];
        return clean
            .split('/')
            .flatMap(part => part.split(/[-_.~]+/).map(x => x.trim()).filter(Boolean))
            .filter(token => token.length >= 2);
    }

    function decodeRepeated(value) {
        let current = String(value || '');
        for (let i = 0; i < 3; i++) {
            try {
                const decoded = decodeURIComponent(current);
                if (decoded === current) break;
                current = decoded;
            } catch (_) {
                break;
            }
        }
        return current;
    }

    function extractTargetUrl(element) {
        if (!element) return '';
        let href = element.getAttribute('href') || element.href || '';
        if (!href) return '';
        href = decodeRepeated(href);

        try {
            if (href.includes('/url?') || href.includes('/url?q=') || href.includes('/url?sa=')) {
                const queryIndex = href.indexOf('?');
                const params = new URLSearchParams(href.slice(queryIndex + 1));
                href = params.get('q') || params.get('url') || params.get('u') || href;
                href = decodeRepeated(href);
            }

            if (/^https?:\/\//i.test(href)) return href;
            if (href.startsWith('//')) return `${location.protocol}${href}`;
            if (href.startsWith('/')) return new URL(href, location.origin).href;
        } catch (_) {}

        return href;
    }

    function parseTargetInput(target) {
        const original = String(target || '').trim();
        if (!original) return { original: '', domain: '', path: '', tokens: [] };

        let value = decodeRepeated(original).trim();
        if (!/^https?:\/\//i.test(value) && !/^\/\//.test(value) && !/^[a-z0-9.-]+\.[a-z]{2,}(?:\/|$)/i.test(value)) {
            return { original, domain: '', path: cleanPath(value), tokens: getPathTokens(value) };
        }

        try {
            if (value.startsWith('//')) value = `${location.protocol}${value}`;
            if (!/^https?:\/\//i.test(value)) value = `https://${value}`;
            const url = new URL(value);
            return {
                original,
                domain: normalizeDomain(url.hostname),
                path: cleanPath(url.pathname),
                tokens: getPathTokens(url.pathname)
            };
        } catch (_) {
            const parts = value.replace(/^(?:https?:\/\/)?(?:www\.)?/i, '').split('/');
            return {
                original,
                domain: normalizeDomain(parts.shift() || ''),
                path: cleanPath(parts.join('/')),
                tokens: getPathTokens(parts.join('/'))
            };
        }
    }

    function tokenMatchScore(targetTokens, candidateTokens) {
        if (!targetTokens.length) return 0;
        let matched = 0;
        for (const targetToken of targetTokens) {
            if (candidateTokens.includes(targetToken)) {
                matched += 1;
            } else if (candidateTokens.some(ct => ct.includes(targetToken) || targetToken.includes(ct))) {
                matched += 0.7;
            }
        }
        return matched / targetTokens.length;
    }

    function sequenceScore(targetPath, candidatePath) {
        if (!targetPath || !candidatePath) return 0;
        const target = cleanPath(targetPath);
        const candidate = cleanPath(candidatePath);
        if (!target || !candidate) return 0;
        if (candidate === target || candidate.includes(target)) return 1;

        const targetParts = target.split('/');
        const candidateParts = candidate.split('/');
        let matched = 0;

        for (const targetPart of targetParts) {
            if (candidateParts.some(cp => cp === targetPart || cp.includes(targetPart) || targetPart.includes(cp))) {
                matched++;
            }
        }
        return matched / Math.max(targetParts.length, 1);
    }

    function scoreGoogleLink(element, userTarget) {
        const href = extractTargetUrl(element);
        if (!href) return -Infinity;

        let candidate;
        try {
            const urlObj = new URL(href.startsWith('http') ? href : new URL(href, location.href).href);
            candidate = {
                url: urlObj.href,
                domain: normalizeDomain(urlObj.hostname),
                path: cleanPath(urlObj.pathname)
            };
        } catch (_) {
            const text = normalizeText(href);
            candidate = { url: text, domain: normalizeDomain(text), path: '' };
        }

        if (candidate.url.includes('google.') || candidate.url.includes('/search')) return -100;

        const target = parseTargetInput(userTarget);
        const rawTargetClean = normalizeText(userTarget).replace(/^https?:\/\//i, '').replace(/^www\./i, '');
        let score = 0;

        if (rawTargetClean) {
            if (candidate.domain.includes(rawTargetClean) || rawTargetClean.includes(candidate.domain)) score += 60;
            if (candidate.url.includes(rawTargetClean)) score += 40;
        }

        if (target.domain) {
            if (candidate.domain === target.domain) score += 100;
            else if (candidate.domain.endsWith(`.${target.domain}`) || target.domain.endsWith(`.${candidate.domain}`)) score += 80;
            else if (candidate.domain.includes(target.domain) || target.domain.includes(candidate.domain)) score += 40;
        }

        if (target.path && candidate.path) {
            const pScore = sequenceScore(target.path, candidate.path);
            const tScore = tokenMatchScore(target.tokens, getPathTokens(candidate.path));
            score += pScore * 50 + tScore * 30;
        }

        const snippetContainer = element.closest('div.MjjYud, div.tF2Cxc, div.g, div[data-snhf]') || element.parentElement;
        if (snippetContainer) {
            const text = normalizeText(snippetContainer.innerText || '');
            if (rawTargetClean && text.includes(rawTargetClean)) score += 30;
        }

        return score;
    }

    function findBestGoogleLink(userTarget) {
        const root = document.querySelector('#rso, #search, #center_col') || document.body;
        if (!root) return null;

        const links = root.querySelectorAll('a[href]');
        let best = null;
        let highest = 30;

        for (const link of links) {
            if (!link.isConnected) continue;
            const score = scoreGoogleLink(link, userTarget);
            if (score > highest) {
                highest = score;
                best = { element: link, url: extractTargetUrl(link), score };
            }
        }
        return best;
    }

    // =============================================================
    // 3. THAO TÁC DOM & CLICK NÂNG CAO
    // =============================================================

    function setNativeValue(element, value) {
        const valSetter = Object.getOwnPropertyDescriptor(element, 'value');
        const proto = Object.getPrototypeOf(element);
        const protoSetter = Object.getOwnPropertyDescriptor(proto, 'value');

        if (protoSetter && valSetter !== protoSetter) {
            protoSetter.set.call(element, value);
        } else if (valSetter) {
            valSetter.set.call(element, value);
        } else {
            element.value = value;
        }

        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function executeDeepClick(element, gui) {
        if (!element || !element.isConnected) return;

        gui?.log('🎯 Xác nhận nút lấy mã. Đang kích hoạt...', 'info');

        try {
            element.removeAttribute('disabled');
            element.style.pointerEvents = 'auto';
            element.style.cursor = 'pointer';
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });
        } catch (_) {}

        setTimeout(() => {
            if (!element.isConnected) return;
            const rect = element.getBoundingClientRect();
            const clickX = Math.round(rect.left + Math.max(rect.width / 2, 5));
            const clickY = Math.round(rect.top + Math.max(rect.height / 2, 5));

            const targets = [
                element,
                element.closest('button, a, [onclick], input[type="button"]'),
                element.parentElement
            ].filter(Boolean);

            [...new Set(targets)].forEach(t => {
                const onclick = t.getAttribute('onclick');
                if (onclick) {
                    try {
                        const win = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
                        win.eval(onclick);
                    } catch (_) {}
                }
            });

            const evData = {
                bubbles: true, cancelable: true,
                view: typeof unsafeWindow !== 'undefined' ? unsafeWindow : window,
                clientX: clickX, clientY: clickY, button: 0, buttons: 1
            };

            ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(evt => {
                element.dispatchEvent(new MouseEvent(evt, evData));
            });

            if (typeof element.click === 'function') {
                try { element.click(); } catch (_) {}
            }

            clearTask();
            gui?.log('✅ KÍCH HOẠT NÚT THÀNH CÔNG!', 'info');
            gui?.toast('🎯 Đã bấm nút lấy mã!', 'info');
        }, 400);
    }

    // =============================================================
    // 4. BẢNG ĐIỀU KHIỂN DOM TRỰC TIẾP (CHUẨN BẢO MẬT & TRUSTED TYPES SAFE)
    // =============================================================

    class EngineGUI {
        constructor() {
            this.panel = null;
            this.floatingBtn = null;
            this.logOutput = null;
            this.keywordInput = null;
            this.domainInput = null;
            this.toastContainer = null;
            this.visible = true;
        }

        render() {
            const root = document.body || document.documentElement;
            if (!root) return;

            // 1. Toast Container
            if (!document.getElementById('mrdon-toast-box')) {
                this.toastContainer = document.createElement('div');
                this.toastContainer.id = 'mrdon-toast-box';
                this.toastContainer.style.cssText = 'position:fixed !important;bottom:24px !important;right:24px !important;z-index:2147483647 !important;display:flex !important;flex-direction:column !important;gap:8px !important;pointer-events:none !important;';
                root.appendChild(this.toastContainer);
            } else {
                this.toastContainer = document.getElementById('mrdon-toast-box');
            }

            // 2. Nút tròn góc trái (⚡)
            if (!document.getElementById('mrdon-floating-btn')) {
                this.floatingBtn = document.createElement('div');
                this.floatingBtn.id = 'mrdon-floating-btn';
                this.floatingBtn.title = 'Mở / Ẩn SEO Tool (Alt+Shift+G)';
                this.floatingBtn.textContent = '⚡';
                this.floatingBtn.style.cssText = `
                    position: fixed !important; bottom: 20px !important; left: 20px !important;
                    width: 44px !important; height: 44px !important; background: #89b4fa !important;
                    color: #11111b !important; border-radius: 50% !important;
                    display: flex !important; align-items: center !important; justify-content: center !important;
                    font-size: 22px !important; font-weight: bold !important; cursor: pointer !important;
                    box-shadow: 0 4px 14px rgba(0,0,0,0.5) !important; z-index: 2147483646 !important;
                    user-select: none !important; pointer-events: auto !important;
                `;
                this.floatingBtn.onclick = () => this.toggle();
                root.appendChild(this.floatingBtn);
            }

            // 3. Bảng điều khiển chính (Tạo DOM thuần để vượt Trusted Types)
            if (!document.getElementById('mrdon-main-panel')) {
                this.panel = document.createElement('div');
                this.panel.id = 'mrdon-main-panel';
                this.panel.style.cssText = `
                    position: fixed !important; top: 20px !important; right: 20px !important; width: 330px !important;
                    background: #181825 !important; color: #cdd6f4 !important; border: 2px solid #89b4fa !important;
                    border-radius: 12px !important; padding: 14px !important; font-family: system-ui, -apple-system, sans-serif !important;
                    font-size: 12px !important; box-shadow: 0 10px 30px rgba(0,0,0,0.7) !important;
                    user-select: none !important; display: block !important; z-index: 2147483647 !important;
                    pointer-events: auto !important; box-sizing: border-box !important;
                `;

                // Header
                const header = document.createElement('div');
                header.id = 'mrdon-panel-header';
                header.style.cssText = 'display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;cursor:move;';

                const title = document.createElement('span');
                title.style.cssText = 'font-weight:700;color:#89b4fa;font-size:13px;';
                title.textContent = '⚡ SEO Bypass Engine v1.1.3';

                const closeBtn = document.createElement('span');
                closeBtn.id = 'mrdon-panel-close';
                closeBtn.title = 'Ẩn (Alt+Shift+G)';
                closeBtn.style.cssText = 'cursor:pointer;color:#f38ba8;font-weight:bold;font-size:14px;padding:2px 6px;';
                closeBtn.textContent = '✖';
                closeBtn.onclick = () => this.toggle();

                header.appendChild(title);
                header.appendChild(closeBtn);

                // Input Keyword
                this.keywordInput = document.createElement('input');
                this.keywordInput.type = 'text';
                this.keywordInput.id = 'mrdon-input-kw';
                this.keywordInput.placeholder = 'Từ khóa Google...';
                this.keywordInput.style.cssText = 'width:100%;box-sizing:border-box;background:#313244;border:1px solid #45475a;color:#cdd6f4;padding:8px 10px;border-radius:6px;margin-bottom:8px;outline:none;font-size:12px;';

                // Input Domain
                this.domainInput = document.createElement('input');
                this.domainInput.type = 'text';
                this.domainInput.id = 'mrdon-input-dom';
                this.domainInput.placeholder = 'Domain đích / link gần đúng...';
                this.domainInput.style.cssText = 'width:100%;box-sizing:border-box;background:#313244;border:1px solid #45475a;color:#cdd6f4;padding:8px 10px;border-radius:6px;margin-bottom:8px;outline:none;font-size:12px;';

                // Button Group
                const btnGroup = document.createElement('div');
                btnGroup.style.cssText = 'display:flex;gap:8px;margin-bottom:10px;';

                const btnStart = document.createElement('button');
                btnStart.id = 'mrdon-btn-start';
                btnStart.style.cssText = 'flex:1;background:#89b4fa;color:#11111b;border:none;padding:8px;font-weight:700;border-radius:6px;cursor:pointer;font-size:12px;';
                btnStart.textContent = '▶ Bắt Đầu';

                const btnClear = document.createElement('button');
                btnClear.id = 'mrdon-btn-clear';
                btnClear.style.cssText = 'flex:1;background:#f38ba8;color:#11111b;border:none;padding:8px;font-weight:700;border-radius:6px;cursor:pointer;font-size:12px;';
                btnClear.textContent = '🧹 Xóa Task';

                btnGroup.appendChild(btnStart);
                btnGroup.appendChild(btnClear);

                // Log Box
                this.logOutput = document.createElement('div');
                this.logOutput.id = 'mrdon-log-box';
                this.logOutput.style.cssText = 'background:#11111b;border:1px solid #313244;height:110px;padding:8px;overflow-y:auto;color:#a6e3a1;border-radius:6px;font-family:monospace;font-size:11px;';

                // Gắn các phần tử vào Panel
                this.panel.appendChild(header);
                this.panel.appendChild(this.keywordInput);
                this.panel.appendChild(this.domainInput);
                this.panel.appendChild(btnGroup);
                this.panel.appendChild(this.logOutput);

                root.appendChild(this.panel);

                // Sự kiện nút Bắt đầu
                btnStart.onclick = () => {
                    const keyword = this.keywordInput.value.trim();
                    const domain = this.domainInput.value.trim();

                    if (!keyword || !domain) {
                        this.toast('Vui lòng nhập cả từ khóa và link đích!', 'warn');
                        return;
                    }

                    saveTask({
                        keyword,
                        domain,
                        originUrl: location.href,
                        step: 'SEARCHING',
                        page: 1
                    });

                    this.log(`🚀 Mở tab Google: ${keyword}`, 'info');
                    this.toast(`🔎 Đang tìm kiếm trên Google...`);
                    window.open(`https://www.google.com/search?q=${encodeURIComponent(keyword)}`, '_blank');
                };

                // Sự kiện nút Xóa task
                btnClear.onclick = () => {
                    clearTask();
                    this.keywordInput.value = '';
                    this.domainInput.value = '';
                    this.log('🧹 Đã dọn dẹp task lưu trữ.', 'warn');
                    this.toast('🧹 Đã xóa task!', 'warn');
                };

                this.bindDrag(header);

                const task = getActiveTask();
                if (task) {
                    this.keywordInput.value = task.keyword || '';
                    this.domainInput.value = task.domain || '';
                    this.log(`🔄 Khôi phục task: [${task.domain}]`, 'info');
                }
            }
        }

        toggle() {
            if (!this.panel) return;
            this.visible = !this.visible;
            this.panel.style.display = this.visible ? 'block' : 'none';
        }

        log(message, type = 'info') {
            const now = new Date().toLocaleTimeString('vi-VN', { hour12: false });
            const p = document.createElement('div');
            p.style.margin = '2px 0';
            p.style.color = type === 'err' ? '#f38ba8' : type === 'warn' ? '#f9e2af' : '#a6e3a1';
            p.textContent = `[${now}] ${message}`;

            if (this.logOutput) {
                this.logOutput.appendChild(p);
                this.logOutput.scrollTop = this.logOutput.scrollHeight;
            }
            console.log(`[Engine ${now}] ${message}`);
        }

        toast(message, type = 'info') {
            if (!this.toastContainer) return;
            const toast = document.createElement('div');
            const colors = {
                info: { bg: '#1e1e2e', text: '#a6e3a1', border: '#a6e3a1' },
                warn: { bg: '#1e1e2e', text: '#f9e2af', border: '#f9e2af' },
                err: { bg: '#1e1e2e', text: '#f38ba8', border: '#f38ba8' }
            }[type] || { bg: '#1e1e2e', text: '#a6e3a1', border: '#a6e3a1' };

            toast.style.cssText = `
                background: ${colors.bg} !important; color: ${colors.text} !important;
                border: 1px solid ${colors.border} !important; padding: 10px 16px !important;
                border-radius: 8px !important; font-family: system-ui, sans-serif !important;
                font-size: 13px !important; font-weight: 600 !important; box-shadow: 0 4px 16px rgba(0,0,0,0.4) !important;
                pointer-events: auto !important; transition: all 0.25s ease-out !important;
            `;
            toast.textContent = message;

            this.toastContainer.appendChild(toast);
            setTimeout(() => {
                toast.style.opacity = '0';
                toast.style.transform = 'translateY(10px)';
                setTimeout(() => toast.remove(), 250);
            }, 3000);
        }

        bindDrag(handle) {
            let dragging = false;
            let startX = 0, startY = 0;

            handle.onmousedown = (e) => {
                dragging = true;
                const rect = this.panel.getBoundingClientRect();
                startX = e.clientX - rect.left;
                startY = e.clientY - rect.top;
            };

            document.addEventListener('mousemove', (e) => {
                if (!dragging || !this.panel) return;
                this.panel.style.left = `${e.clientX - startX}px`;
                this.panel.style.top = `${e.clientY - startY}px`;
                this.panel.style.right = 'auto';
            });

            document.addEventListener('mouseup', () => { dragging = false; });
        }
    }

    // =============================================================
    // 5. GOOGLE NAVIGATOR
    // =============================================================

    class GoogleNavigator {
        static run(task, gui) {
            gui?.log(`🔍 Quét link Google khớp: "${task.domain}"...`, 'info');

            let isProcessing = false;
            let attempts = 0;
            const maxAttempts = 18;

            const checkPage = () => {
                if (isProcessing) return;
                const result = findBestGoogleLink(task.domain);
                if (!result) return;

                isProcessing = true;
                clearInterval(scanInterval);

                const { element, url, score } = result;
                gui?.log(`✅ Chọn link (Điểm ${score.toFixed(1)}): ${url}`, 'info');
                gui?.toast('🎯 Đã tìm thấy trang đích!', 'info');

                task.step = 'BYPASSING';
                task.matchedUrl = url;
                saveTask(task);

                try { element.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (_) {}

                setTimeout(() => {
                    try { element.click(); } catch (_) {}
                    setTimeout(() => { location.href = url; }, 500);
                }, 500);
            };

            const scanInterval = setInterval(() => {
                if (isProcessing) return;
                attempts++;
                checkPage();

                if (attempts >= maxAttempts && !isProcessing) {
                    clearInterval(scanInterval);
                    const nextBtn = document.querySelector('#pnnext, a[id="pnnext"], a[aria-label*="Next"], a[aria-label*="Trang sau"], [jsname="Te322e"]');

                    if (!nextBtn) {
                        gui?.log(`❌ Không tìm thấy trang đích cho "${task.domain}".`, 'err');
                        gui?.toast('❌ Không tìm thấy trang đích!', 'err');
                        return;
                    }

                    task.page = Number(task.page || 1) + 1;
                    task.step = 'SEARCHING';
                    saveTask(task);

                    gui?.log(`➡️ Đang sang trang Google ${task.page}...`, 'info');
                    setTimeout(() => {
                        try { nextBtn.click(); } catch (_) {}
                    }, 500);
                }
            }, 350);

            checkPage();
        }
    }

    // =============================================================
    // 6. TARGET PAGE: QUÉT NÚT, TRÍCH XUẤT MÃ & RELOAD KHI KẸT 0
    // =============================================================

    class TargetPageHandler {
        static run(task, gui) {
            gui?.log('🌐 Đang tìm nút lấy mã SEO...', 'info');

            let attempts = 0;
            let direction = 1;

            TargetPageHandler.removeOverlayAds();

            const timer = setInterval(() => {
                attempts++;
                const foundBtn = TargetPageHandler.scanNodeAllLayers();

                if (foundBtn) {
                    clearInterval(timer);
                    executeDeepClick(foundBtn, gui);
                    return;
                }

                if (attempts % 4 === 0) {
                    const isAtBottom = (window.innerHeight + window.scrollY) >= (document.documentElement.scrollHeight - 100);
                    const isAtTop = window.scrollY <= 50;

                    if (isAtBottom && direction === 1) direction = -1;
                    else if (isAtTop && direction === -1) direction = 1;

                    window.scrollBy({ top: 350 * direction, behavior: 'smooth' });
                }

                if (attempts > 90) clearInterval(timer);
            }, 250);
        }

        static removeOverlayAds() {
            try {
                const overlays = document.querySelectorAll('div[class*="popup"], div[id*="popup"], div[class*="overlay"], div[id*="overlay"]');
                overlays.forEach(el => {
                    const style = window.getComputedStyle(el);
                    if ((style.position === 'fixed' || style.position === 'absolute') && parseInt(style.zIndex, 10) > 5000) {
                        if (!el.querySelector('button, input, a') && !el.id.startsWith('mrdon-')) el.remove();
                    }
                });
            } catch (_) {}
        }

        static scanNodeAllLayers() {
            const allImgSelectors = [
                '#trade-d-btn', '#trade-d-btn__arrow', '#trade-d-btn__content',
                'svg#avt-btn', '#avt-btn', '[id="avt-btn"]',
                'rect[fill*="pattern0_647_11"]', 'img[src*="play"]', 'img[src*="red"]',
                'img[src*="button"]', 'img[src*="layma"]', 'img[src*="traffic"]',
                'img[src*="code"]', 'img[alt*="mã" i]', 'img[alt*="code" i]',
                '#traffic-button-no__arrow img', '#traffic-button-no__arrow',
                'a[id*="traffic"] img', 'div[id*="traffic"] img'
            ];

            for (const sel of allImgSelectors) {
                try {
                    const imgs = document.querySelectorAll(sel);
                    for (const img of imgs) {
                        const rect = img.getBoundingClientRect();
                        if (rect.width > 0 && rect.height > 0) return img;
                    }
                } catch (_) {}
            }

            const textKeywords = [
                /lấy\s*mã/i, /get\s*code/i, /mã\s*xác\s*nhận/i,
                /lấy\s*pass/i, /xem\s*mã/i, /click\s*để\s*lấy/i, /bấm\s*lấy\s*mã/i
            ];

            const elements = document.querySelectorAll('button, a, div[role="button"], input[type="button"], input[type="submit"]');
            for (const el of elements) {
                if (el.closest('#mrdon-main-panel')) continue;
                const rect = el.getBoundingClientRect();
                if (rect.width <= 0 || rect.height <= 0) continue;

                const text = (el.innerText || el.value || '').trim();
                if (/hướng dẫn|cách lấy mã/i.test(text)) continue;

                if (text && text.length < 35 && textKeywords.some(regex => regex.test(text))) {
                    const onclick = el.getAttribute('onclick') || '';
                    if (!BANNER_KEYWORDS.some(k => onclick.toLowerCase().includes(k))) return el;
                }
            }

            const allSelectors = [
                '#trade-d-btn', '#avt-btn', 'svg#avt-btn',
                '#traffic-button-no__arrow', '.traffic-button__content', '[class*="layma"]',
                '[id*="layma"]', '[class*="l4m"]', '[id*="l4m"]', 'button[class*="traffic"]',
                'a[class*="traffic"]', 'div[class*="traffic"]', '#btn-lay-ma', '.btn-lay-ma',
                '#getcode', '.getcode', '[id*="1sdesign"]', '[class*="1sdesign"]'
            ];

            for (const selector of allSelectors) {
                try {
                    const els = document.querySelectorAll(selector);
                    for (const el of els) {
                        const rect = el.getBoundingClientRect();
                        if (rect.width <= 0 || rect.height <= 0) continue;
                        const onclick = el.getAttribute('onclick') || '';
                        if (!BANNER_KEYWORDS.some(k => onclick.toLowerCase().includes(k))) return el;
                    }
                } catch (_) {}
            }

            return null;
        }

        static handleIntermediateBypass(gui) {
            let runs = 0;
            const fastTimer = setInterval(() => {
                runs++;
                const targetLink = document.querySelector('a[href*="activate_link"], a[href*="type=verify"], a[href*="realkidkey.site/api"]');
                if (targetLink) {
                    const realHref = targetLink.getAttribute('href') || targetLink.href;
                    if (realHref && realHref.startsWith('http')) {
                        clearInterval(fastTimer);
                        gui?.log(`🚀 Chuyển hướng link: ${realHref}`, 'info');
                        location.href = realHref;
                        return;
                    }
                }

                const links = document.querySelectorAll('a, button');
                for (const el of links) {
                    if (el.closest('#mrdon-main-panel')) continue;
                    const text = (el.innerText || el.textContent || '').trim();

                    // SỬA TẠI ĐÂY: Dùng toán tử || hợp lệ
                   if (/^lấy\s*link$/i.test(text) || /^get\s*link$/i.test(text)) {
                        clearInterval(fastTimer);
                        gui?.log('⚡ Tìm thấy nút "Lấy link", bấm ngay...', 'info');
                        el.removeAttribute('disabled');
                        el.style.pointerEvents = 'auto';

                        if (el.href && el.href.startsWith('http')) location.href = el.href;
                        else el.click();
                        return;
                    }
                }

                if (runs > 40) clearInterval(fastTimer);
            }, 300);
        }

        static monitorCodeExtraction(gui) {
            let extracted = false;
            let zeroErrorTimer = null;

            const isCodeValid = (text) => {
                if (!text) return false;
                const clean = text.trim();

                if (/\s/.test(clean)) return false;
                if (clean.length < 4 || clean.length > 35) return false;

                if (/^\d+$/.test(clean)) {
                    const num = parseInt(clean, 10);
                    if (num <= 180) return false;
                }

                if (/^(code|get code|mã code|pass|password|lấy mã|lay ma|wait|loading|click|xem mã)$/i.test(clean)) return false;
                if (/lấy mã|chờ|wait|click|vui lòng|giây|seconds|download|chờ duyệt|bấm vào|bước/i.test(clean)) return false;
                return true;
            };

            const checkAndExtract = () => {
                if (extracted) return;

                const codeElements = document.querySelectorAll(
                    '#trade-d-btn__content, .trade-d-btn__content, .trade-btn-clf__content, .traffic-button__content'
                );

                for (const el of codeElements) {
                    const val = (el.textContent || el.innerText || '').trim();

                    if (val === '0') {
                        if (!zeroErrorTimer) {
                            gui?.log('⚠️ Kẹt đếm ngược "0". Chờ 1.5s xác nhận...', 'warn');
                            zeroErrorTimer = setTimeout(() => {
                                const reCheckVal = (el.textContent || el.innerText || '').trim();
                                if (reCheckVal === '0') {
                                    extracted = true;
                                    gui?.log('🔄 Kẹt 0s, tải lại trang...', 'err');
                                    gui?.toast('🔄 Mã bị kẹt 0s, reload...', 'err');
                                    location.reload();
                                } else {
                                    zeroErrorTimer = null;
                                }
                            }, 1500);
                        }
                    } else if (val !== '0' && zeroErrorTimer) {
                        clearTimeout(zeroErrorTimer);
                        zeroErrorTimer = null;
                    }

                    if (isCodeValid(val)) {
                        if (zeroErrorTimer) clearTimeout(zeroErrorTimer);
                        extracted = true;
                        gui?.log(`🎉 BẮT ĐƯỢC MÃ THẬT: [${val}]`, 'info');
                        gui?.toast(`🎉 Bắt được mã: ${val}`, 'info');

                        Storage.set(CODE_STORAGE_KEY, val);

                        try {
                            if (typeof GM_setClipboard === 'function') GM_setClipboard(val);
                        } catch (_) {}

                        document.title = `✅ [MÃ: ${val}] - ${document.title}`;

                        gui?.log('🚪 Đã lấy mã xong! Chuẩn bị tắt tab...', 'info');
                        setTimeout(() => { try { window.close(); } catch (_) {} }, 1000);
                        break;
                    }
                }
            };

            const observer = new MutationObserver(checkAndExtract);
            const targetRoot = document.documentElement || document.body;
            if (targetRoot) {
                observer.observe(targetRoot, { childList: true, subtree: true, characterData: true });
                checkAndExtract();
            }
        }
    }

    // =============================================================
    // 7. TỰ ĐỘNG ĐIỀN MÃ XÁC NHẬN VÀO TRANG GỐC
    // =============================================================

    function handleAutoFillAndSubmit(gui) {
        let isSubmitted = false;

        const trySubmitCode = (savedCode) => {
            if (!savedCode || isSubmitted) return;

            let checkCount = 0;
            const watcher = setInterval(() => {
                checkCount++;
                if (isSubmitted || checkCount > 35) {
                    clearInterval(watcher);
                    if (checkCount > 35) Storage.delete(CODE_STORAGE_KEY);
                    return;
                }

                const inputEl = document.querySelector(
                    'input[placeholder*="Nhập mã" i], input[placeholder*="xác nhận" i], input[placeholder*="nhập code" i], ' +
                    'input[id*="code" i], input[name*="code" i], input[id*="token" i], main#scroller input[type="text"]'
                );

                if (!inputEl) return;

                if (inputEl.value !== savedCode) {
                    gui?.log(`⚡ Điền mã tự động: [${savedCode}]`, 'info');
                    gui?.toast(`⚡ Đang điền mã: ${savedCode}`);
                    inputEl.focus();
                    setNativeValue(inputEl, savedCode);
                }

                const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]'));
                const submitBtn = buttons.find(btn =>
                    !btn.closest('#mrdon-main-panel') &&
                    (/nhập mã|gửi|submit|xác nhận/i.test(btn.textContent || btn.value || '') ||
                    btn.querySelector('.tabler-icon-brand-telegram'))
                );

                if (submitBtn) {
                    isSubmitted = true;
                    clearInterval(watcher);

                    submitBtn.removeAttribute('disabled');
                    submitBtn.disabled = false;
                    submitBtn.classList.remove('opacity-70', 'cursor-not-allowed');

                    gui?.log('🚀 Tự động gửi mã xác thực!', 'info');
                    gui?.toast('🚀 Đã gửi mã thành công!', 'info');

                    Storage.delete(CODE_STORAGE_KEY);

                    setTimeout(() => {
                        try { submitBtn.click(); } catch (_) {}
                    }, 300);
                }
            }, 300);
        };

        const existingCode = Storage.get(CODE_STORAGE_KEY, null);
        if (existingCode) trySubmitCode(existingCode);

        try {
            if (typeof GM_addValueChangeListener === 'function') {
                GM_addValueChangeListener(CODE_STORAGE_KEY, (_, __, newValue) => {
                    if (newValue && !isSubmitted) {
                        gui?.log(`🔔 Nhận mã realtime: [${newValue}]`, 'info');
                        trySubmitCode(newValue);
                    }
                });
            }
        } catch (_) {}
    }

    // =============================================================
    // 8. KHỞI CHẠY (ENTRY POINT)
    // =============================================================

    function main() {
        const gui = new EngineGUI();
        gui.render();

        // Tự động kiểm tra và vẽ lại bảng nếu trang web tải động
        setInterval(() => gui.render(), 1000);

        window.addEventListener('keydown', (e) => {
            const isKeyG = e.code === 'KeyG' || (e.key && e.key.toLowerCase() === 'g');
            if (e.altKey && e.shiftKey && isKeyG) {
                e.preventDefault();
                e.stopImmediatePropagation();
                gui.toggle();
            }
        }, true);

        if (typeof GM_registerMenuCommand === 'function') {
            GM_registerMenuCommand('⚡ Mở / Ẩn Bảng Điều Khiển', () => gui.toggle());
        }

        handleAutoFillAndSubmit(gui);

        if (!IS_GOOGLE) {
            TargetPageHandler.monitorCodeExtraction(gui);
            TargetPageHandler.handleIntermediateBypass(gui);
        }

        const task = getActiveTask();
        if (!task?.domain) return;

        if (IS_GOOGLE && task.step === 'SEARCHING') {
            GoogleNavigator.run(task, gui);
            return;
        }

        if (!IS_GOOGLE && task.step === 'BYPASSING') {
            TargetPageHandler.run(task, gui);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', main);
    } else {
        main();
    }

})();
