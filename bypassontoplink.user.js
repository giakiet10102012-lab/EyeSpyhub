// ==UserScript==
// @name         Google SEO Traffic & Smart Bypass Engine
// @namespace    http://tampermonkey.net/
// @version      1.0.3
// @description  Tự động tìm kiếm Google, mở liên kết đích, bypass nút lấy mã SEO (Ontop, GTraffic, 1s...) và tự động điền mã xác nhận.
// @author       MrDon & Assistant
// @match        *://*/*
// @match        https://*/*
// @match        http://*/*
// @include      *
// @include      http*://*/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_deleteValue
// @grant        GM_setClipboard
// @grant        GM_addValueChangeListener
// @grant        GM_registerMenuCommand
// @grant        unsafeWindow
// @run-at       document-end
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    if (window.top !== window.self) return;

    const IS_GOOGLE = /(^|\.)google\./i.test(location.hostname);
    const CODE_STORAGE_KEY = 'auto_bypass_code';
    const TASK_KEY = 'seo_task';
    const TASK_TIMEOUT_MS = 10 * 60 * 1000;

    const CONFIG = {
        SEARCH_DEBOUNCE_MS: 180,
        SEARCH_MAX_PAGE_WAIT_MS: 6000,
        TARGET_POLL_INTERVAL_MS: 250,
        ZERO_CODE_CONFIRM_MS: 1500
    };

    const BANNER_KEYWORDS = ['banner', 'popup', 'float', 'close', 'openbanner', 'ad_', 'advertisement', 'overlay'];

    // =============================================================
    // 1. CÔNG CỤ XỬ LÝ & BỘ SO KHỚP URL
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
            .flatMap(segment => segment.split(/[-_.~]+/).map(x => x.trim()).filter(Boolean))
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
            const segments = value.replace(/^(?:https?:\/\/)?(?:www\.)?/i, '').split('/');
            return {
                original,
                domain: normalizeDomain(segments.shift() || ''),
                path: cleanPath(segments.join('/')),
                tokens: getPathTokens(segments.join('/'))
            };
        }
    }

    function scoreUrlMatch(element, userTarget) {
        const href = extractTargetUrl(element);
        if (!href) return -Infinity;

        let parsedCandidate;
        try {
            const urlObj = new URL(href.startsWith('http') ? href : new URL(href, location.href).href);
            parsedCandidate = {
                url: urlObj.href,
                domain: normalizeDomain(urlObj.hostname),
                path: cleanPath(urlObj.pathname)
            };
        } catch (_) {
            const text = normalizeText(href);
            parsedCandidate = { url: text, domain: normalizeDomain(text), path: '' };
        }

        if (parsedCandidate.url.includes('google.') || parsedCandidate.url.includes('/search')) {
            return -100;
        }

        const target = parseTargetInput(userTarget);
        const rawTargetClean = normalizeText(userTarget).replace(/^https?:\/\//i, '').replace(/^www\./i, '');
        let score = 0;

        if (rawTargetClean) {
            if (parsedCandidate.domain.includes(rawTargetClean) || rawTargetClean.includes(parsedCandidate.domain)) score += 60;
            if (parsedCandidate.url.includes(rawTargetClean)) score += 40;
        }

        if (target.domain) {
            if (parsedCandidate.domain === target.domain) score += 100;
            else if (parsedCandidate.domain.endsWith(`.${target.domain}`) || target.domain.endsWith(`.${parsedCandidate.domain}`)) score += 80;
            else if (parsedCandidate.domain.includes(target.domain) || target.domain.includes(parsedCandidate.domain)) score += 40;
        }

        if (target.path && parsedCandidate.path) {
            if (parsedCandidate.path === target.path || parsedCandidate.path.includes(target.path)) {
                score += 60;
            } else {
                const targetTokens = target.tokens;
                const candidateTokens = getPathTokens(parsedCandidate.path);
                if (targetTokens.length && candidateTokens.length) {
                    let matched = 0;
                    for (const t of targetTokens) {
                        if (candidateTokens.includes(t)) matched += 1;
                        else if (candidateTokens.some(c => c.includes(t) || t.includes(c))) matched += 0.7;
                    }
                    score += (matched / targetTokens.length) * 40;
                }
            }
        }

        const snippetContainer = element.closest('div.MjjYud, div.tF2Cxc, div.g, div[data-snhf]') || element.parentElement;
        if (snippetContainer) {
            const visibleText = normalizeText(snippetContainer.innerText || '');
            if (rawTargetClean && visibleText.includes(rawTargetClean)) score += 30;
        }

        return score;
    }

    function findBestMatchingResult(userTarget) {
        const rootContainer = document.querySelector('#rso, #search, #center_col') || document.body;
        if (!rootContainer) return null;

        const links = rootContainer.querySelectorAll('a[href]');
        let best = null;
        let highestScore = 30;

        for (const link of links) {
            if (!link.isConnected) continue;
            const score = scoreUrlMatch(link, userTarget);
            if (score > highestScore) {
                highestScore = score;
                best = { element: link, url: extractTargetUrl(link), score };
            }
        }
        return best;
    }

    function getActiveTask() {
        const task = GM_getValue(TASK_KEY, null);
        if (!task) return null;
        if (!task.timestamp || Date.now() - task.timestamp > TASK_TIMEOUT_MS) {
            GM_deleteValue(TASK_KEY);
            return null;
        }
        return task;
    }

    function saveTask(task) {
        task.timestamp = Date.now();
        GM_setValue(TASK_KEY, task);
    }

    function clearTask() {
        GM_deleteValue(TASK_KEY);
    }

    function setNativeValue(element, value) {
        const valueSetter = Object.getOwnPropertyDescriptor(element, 'value');
        const prototype = Object.getPrototypeOf(element);
        const prototypeValueSetter = Object.getOwnPropertyDescriptor(prototype, 'value');

        if (prototypeValueSetter && valueSetter !== prototypeValueSetter) {
            prototypeValueSetter.set.call(element, value);
        } else if (valueSetter) {
            valueSetter.set.call(element, value);
        } else {
            element.value = value;
        }

        element.dispatchEvent(new Event('input', { bubbles: true }));
        element.dispatchEvent(new Event('change', { bubbles: true }));
    }

    function showToast(message, type = 'info') {
        const targetBody = document.body || document.documentElement;
        if (!targetBody) return;
        let box = document.getElementById('engine-toast-container');
        if (!box) {
            box = document.createElement('div');
            box.id = 'engine-toast-container';
            box.style.cssText = 'position:fixed !important;bottom:24px !important;right:24px !important;z-index:2147483647 !important;display:flex !important;flex-direction:column !important;gap:8px !important;pointer-events:none !important;';
            targetBody.appendChild(box);
        }

        const toast = document.createElement('div');
        const palette = {
            info: { bg: '#1e1e2e', text: '#a6e3a1', border: '#a6e3a1' },
            warn: { bg: '#1e1e2e', text: '#f9e2af', border: '#f9e2af' },
            err: { bg: '#1e1e2e', text: '#f38ba8', border: '#f38ba8' }
        };
        const currentStyle = palette[type] || palette.info;

        toast.style.cssText = `
            background: ${currentStyle.bg} !important; color: ${currentStyle.text} !important;
            border: 1px solid ${currentStyle.border} !important; padding: 10px 16px !important;
            border-radius: 8px !important; font-family: system-ui, -apple-system, sans-serif !important;
            font-size: 13px !important; font-weight: 600 !important; box-shadow: 0 4px 16px rgba(0,0,0,0.4) !important;
            opacity: 0; transform: translateY(12px); transition: all 0.25s ease-out;
            pointer-events: auto !important;
        `;
        toast.textContent = message;
        box.appendChild(toast);

        requestAnimationFrame(() => {
            toast.style.opacity = '1';
            toast.style.transform = 'translateY(0)';
        });

        setTimeout(() => {
            toast.style.opacity = '0';
            toast.style.transform = 'translateY(12px)';
            setTimeout(() => toast.remove(), 250);
        }, 3000);
    }

    function executeClickSequence(element, gui) {
        if (!element || !element.isConnected) return;

        gui?.log('🎯 Tìm thấy nút bấm. Đang mở khóa và kích hoạt...', 'info');

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

            const targetChain = [
                element,
                element.closest('button, a, [onclick], input[type="button"]'),
                element.parentElement
            ].filter(Boolean);

            const uniqueChain = [...new Set(targetChain)];

            uniqueChain.forEach(node => {
                const onclickAttr = node.getAttribute('onclick');
                if (onclickAttr) {
                    try {
                        const execWindow = typeof unsafeWindow !== 'undefined' ? unsafeWindow : window;
                        execWindow.eval(onclickAttr);
                    } catch (_) {}
                }
            });

            const eventPayload = {
                bubbles: true,
                cancelable: true,
                view: typeof unsafeWindow !== 'undefined' ? unsafeWindow : window,
                clientX: clickX,
                clientY: clickY,
                button: 0,
                buttons: 1
            };

            ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'].forEach(evtType => {
                const evt = new MouseEvent(evtType, eventPayload);
                element.dispatchEvent(evt);
            });

            if (typeof element.click === 'function') {
                try { element.click(); } catch (_) {}
            }

            clearTask();
            gui?.log('✅ Đã kích hoạt nhấn thành công!', 'info');
            showToast('🎯 Đã bấm nút nhận mã thành công!', 'info');
        }, 400);
    }

    // =============================================================
    // 2. GIAO DIỆN ĐIỀU KHIỂN (CƠ CHẾ TỰ PHỤC HỒI / SELF-HEALING)
    // =============================================================

    class ControlPanel {
        constructor() {
            this.container = null;
            this.floatingBtn = null;
            this.logOutput = null;
            this.keywordInput = null;
            this.domainInput = null;
        }

        buildFloatingButton() {
            if (document.getElementById('engine-quick-toggle-btn')) return;

            this.floatingBtn = document.createElement('div');
            this.floatingBtn.id = 'engine-quick-toggle-btn';
            this.floatingBtn.title = 'Bấm để Mở/Ẩn SEO Tool (Alt+Shift+G)';
            this.floatingBtn.innerHTML = '⚡';
            this.floatingBtn.style.cssText = `
                position: fixed !important; bottom: 20px !important; left: 20px !important;
                width: 44px !important; height: 44px !important; background: #89b4fa !important;
                color: #11111b !important; border-radius: 50% !important;
                display: flex !important; align-items: center !important; justify-content: center !important;
                font-size: 22px !important; font-weight: bold !important; cursor: pointer !important;
                box-shadow: 0 4px 14px rgba(0,0,0,0.5) !important; z-index: 2147483646 !important;
                transition: transform 0.2s, background 0.2s !important; user-select: none !important;
            `;

            this.floatingBtn.addEventListener('mouseenter', () => {
                this.floatingBtn.style.transform = 'scale(1.1)';
            });
            this.floatingBtn.addEventListener('mouseleave', () => {
                this.floatingBtn.style.transform = 'scale(1)';
            });
            this.floatingBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                this.toggle();
            });

            (document.body || document.documentElement).appendChild(this.floatingBtn);
        }

        buildInterface() {
            if (document.getElementById('engine-control-panel')) return;

            this.container = document.createElement('div');
            this.container.id = 'engine-control-panel';
            this.container.style.cssText = `
                position: fixed !important; top: 20px !important; right: 20px !important; width: 330px !important;
                background: #181825 !important; color: #cdd6f4 !important; border: 2px solid #89b4fa !important;
                border-radius: 12px !important; padding: 14px !important; font-family: system-ui, -apple-system, sans-serif !important;
                font-size: 12px !important; z-index: 2147483647 !important; box-shadow: 0 10px 30px rgba(0,0,0,0.7) !important;
                user-select: none !important; display: block !important; box-sizing: border-box !important;
            `;

            const header = document.createElement('div');
            header.style.cssText = 'display: flex !important; justify-content: space-between !important; align-items: center !important; margin-bottom: 10px !important; cursor: move !important;';

            const title = document.createElement('span');
            title.style.cssText = 'font-weight: 700 !important; color: #89b4fa !important; font-size: 13px !important;';
            title.textContent = '⚡ SEO Bypass Engine v1.0.3';

            const closeBtn = document.createElement('span');
            closeBtn.style.cssText = 'cursor: pointer !important; color: #f38ba8 !important; font-weight: bold !important; padding: 2px 6px !important; font-size: 14px !important;';
            closeBtn.textContent = '✖';
            closeBtn.title = 'Ẩn bảng điều khiển';
            closeBtn.addEventListener('click', () => this.toggle());

            header.append(title, closeBtn);
            this.container.appendChild(header);

            this.keywordInput = this.createStyledInput('Từ khóa tìm kiếm Google...');
            this.container.appendChild(this.keywordInput);

            this.domainInput = this.createStyledInput('Tên miền / URL trang đích...');
            this.container.appendChild(this.domainInput);

            const btnWrapper = document.createElement('div');
            btnWrapper.style.cssText = 'display: flex !important; gap: 8px !important; margin-bottom: 10px !important;';

            const runBtn = document.createElement('button');
            runBtn.textContent = '▶ Bắt Đầu';
            runBtn.style.cssText = 'flex: 1 !important; background: #89b4fa !important; color: #11111b !important; border: none !important; padding: 8px !important; font-weight: 700 !important; border-radius: 6px !important; cursor: pointer !important;';

            const clearBtn = document.createElement('button');
            clearBtn.textContent = '🧹 Xóa Task';
            clearBtn.style.cssText = 'flex: 1 !important; background: #f38ba8 !important; color: #11111b !important; border: none !important; padding: 8px !important; font-weight: 700 !important; border-radius: 6px !important; cursor: pointer !important;';

            btnWrapper.append(runBtn, clearBtn);
            this.container.appendChild(btnWrapper);

            this.logOutput = document.createElement('div');
            this.logOutput.style.cssText = 'background: #11111b !important; border: 1px solid #313244 !important; height: 110px !important; padding: 8px !important; overflow-y: auto !important; color: #a6e3a1 !important; border-radius: 6px !important; font-family: monospace !important; font-size: 11px !important;';
            this.container.appendChild(this.logOutput);

            (document.body || document.documentElement).appendChild(this.container);

            this.bindDrag(header);

            const activeTask = getActiveTask();
            if (activeTask) {
                this.keywordInput.value = activeTask.keyword || '';
                this.domainInput.value = activeTask.domain || '';
                this.log(`🔄 Khôi phục task: [${activeTask.domain}]`, 'info');
            }

            runBtn.addEventListener('click', () => {
                const keyword = this.keywordInput.value.trim();
                const domain = this.domainInput.value.trim();

                if (!keyword || !domain) {
                    showToast('Vui lòng nhập cả từ khóa và link đích!', 'warn');
                    return;
                }

                saveTask({
                    keyword,
                    domain,
                    originUrl: location.href,
                    step: 'SEARCHING',
                    page: 1
                });

                this.log(`🚀 Mở Google tìm: ${keyword}`, 'info');
                showToast(`🔎 Đang tìm kiếm trên Google...`);
                window.open(`https://www.google.com/search?q=${encodeURIComponent(keyword)}`, '_blank');
            });

            clearBtn.addEventListener('click', () => {
                clearTask();
                this.keywordInput.value = '';
                this.domainInput.value = '';
                this.log('🧹 Đã xóa task lưu trữ.', 'warn');
                showToast('🧹 Đã dọn dẹp task.', 'warn');
            });
        }

        createStyledInput(placeholderText) {
            const input = document.createElement('input');
            input.type = 'text';
            input.placeholder = placeholderText;
            input.style.cssText = 'width: 100% !important; box-sizing: border-box !important; background: #313244 !important; border: 1px solid #45475a !important; color: #cdd6f4 !important; padding: 8px 10px !important; border-radius: 6px !important; margin-bottom: 8px !important; outline: none !important; font-size: 12px !important;';
            return input;
        }

        bindDrag(dragHandle) {
            let active = false;
            let startX = 0, startY = 0;

            dragHandle.addEventListener('mousedown', e => {
                active = true;
                const rect = this.container.getBoundingClientRect();
                startX = e.clientX - rect.left;
                startY = e.clientY - rect.top;
            });

            document.addEventListener('mousemove', e => {
                if (!active || !this.container) return;
                this.container.style.left = `${e.clientX - startX}px`;
                this.container.style.top = `${e.clientY - startY}px`;
                this.container.style.right = 'auto';
            });

            document.addEventListener('mouseup', () => { active = false; });
        }

        log(message, type = 'info') {
            const now = new Date().toLocaleTimeString('vi-VN', { hour12: false });
            const prefix = `[Engine ${now}] ${message}`;

            if (type === 'err') console.error(`%c${prefix}`, 'color:#f38ba8;font-weight:bold;');
            else if (type === 'warn') console.warn(`%c${prefix}`, 'color:#f9e2af;font-weight:bold;');
            else console.log(`%c${prefix}`, 'color:#a6e3a1;font-weight:bold;');

            if (!this.logOutput) return;
            const line = document.createElement('div');
            line.style.margin = '2px 0';
            line.style.color = type === 'err' ? '#f38ba8' : type === 'warn' ? '#f9e2af' : '#a6e3a1';
            line.textContent = `[${now}] ${message}`;
            this.logOutput.appendChild(line);
            this.logOutput.scrollTop = this.logOutput.scrollHeight;
        }

        toggle() {
            if (!this.container) {
                this.buildInterface();
                return;
            }
            const isHidden = this.container.style.display === 'none';
            this.container.style.display = isHidden ? 'block' : 'none';
        }

        ensureMounted() {
            if (!document.body && !document.documentElement) return;
            if (!document.getElementById('engine-control-panel')) {
                this.buildInterface();
            }
            if (!document.getElementById('engine-quick-toggle-btn')) {
                this.buildFloatingButton();
            }
        }
    }

    // =============================================================
    // 3. ĐIỀU HƯỚNG TÌM KIẾM TRÊN GOOGLE
    // =============================================================

    class GoogleNavigator {
        static run(task, gui) {
            gui?.log(`🔍 Quét liên kết: "${task.domain}"...`, 'info');

            let isFound = false;
            let observer = null;
            let timeoutWatch = null;
            let debounceTimer = null;

            const stopSearching = () => {
                if (observer) { observer.disconnect(); observer = null; }
                if (timeoutWatch) { clearTimeout(timeoutWatch); timeoutWatch = null; }
                if (debounceTimer) { clearTimeout(debounceTimer); debounceTimer = null; }
            };

            const evaluateResults = () => {
                if (isFound) return;
                const match = findBestMatchingResult(task.domain);
                if (!match) return;

                isFound = true;
                stopSearching();

                gui?.log(`✅ Chọn liên kết (Điểm: ${match.score.toFixed(1)}): ${match.url}`, 'info');
                showToast(`🎯 Đã tìm thấy trang đích!`, 'info');

                task.step = 'BYPASSING';
                task.matchedUrl = match.url;
                saveTask(task);

                try { match.element.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (_) {}

                setTimeout(() => {
                    try { match.element.click(); } catch (_) {}
                    setTimeout(() => { location.href = match.url; }, 400);
                }, 400);
            };

            const debouncedScan = () => {
                if (debounceTimer) clearTimeout(debounceTimer);
                debounceTimer = setTimeout(evaluateResults, CONFIG.SEARCH_DEBOUNCE_MS);
            };

            const targetContainer = document.querySelector('#rso, #search, #center_col') || document.body;
            if (targetContainer) {
                observer = new MutationObserver(debouncedScan);
                observer.observe(targetContainer, { childList: true, subtree: true });
            }

            evaluateResults();

            timeoutWatch = setTimeout(() => {
                if (isFound) return;
                stopSearching();

                const nextBtn = document.querySelector('#pnnext, a[id="pnnext"], a[aria-label*="Next"], a[aria-label*="Trang sau"], [jsname="Te322e"]');
                if (!nextBtn) {
                    gui?.log(`❌ Không tìm thấy trang web khớp với "${task.domain}".`, 'err');
                    showToast(`❌ Không tìm thấy trang đích!`, 'err');
                    return;
                }

                task.page = Number(task.page || 1) + 1;
                task.step = 'SEARCHING';
                saveTask(task);

                gui?.log(`➡️ Chuyển sang trang Google ${task.page}...`, 'info');
                nextBtn.click();
            }, CONFIG.SEARCH_MAX_PAGE_WAIT_MS);
        }
    }

    // =============================================================
    // 4. QUÉT NÚT BẤM & XỬ LÝ TRANG TRUNG GIAN
    // =============================================================

    class TargetPageHandler {
        static run(task, gui) {
            gui?.log('🌐 Đang tìm kiếm nút nhận mã SEO...', 'info');

            let attempts = 0;
            let scrollDirection = 1;

            TargetPageHandler.cleanOverlays();

            const pollInterval = setInterval(() => {
                attempts++;
                const targetBtn = TargetPageHandler.detectTrafficButton();

                if (targetBtn) {
                    clearInterval(pollInterval);
                    executeClickSequence(targetBtn, gui);
                    return;
                }

                if (attempts % 4 === 0) {
                    const atBottom = (window.innerHeight + window.scrollY) >= (document.documentElement.scrollHeight - 80);
                    const atTop = window.scrollY <= 40;

                    if (atBottom && scrollDirection === 1) scrollDirection = -1;
                    else if (atTop && scrollDirection === -1) scrollDirection = 1;

                    window.scrollBy({ top: 320 * scrollDirection, behavior: 'smooth' });
                }

                if (attempts > 80) {
                    clearInterval(pollInterval);
                    gui?.log('⚠️ Hết thời gian tìm kiếm tự động nút bấm.', 'warn');
                }
            }, CONFIG.TARGET_POLL_INTERVAL_MS);
        }

        static cleanOverlays() {
            try {
                const candidates = document.querySelectorAll('div[class*="popup"], div[id*="popup"], div[class*="overlay"], div[id*="overlay"]');
                candidates.forEach(node => {
                    const style = window.getComputedStyle(node);
                    if ((style.position === 'fixed' || style.position === 'absolute') && parseInt(style.zIndex, 10) > 5000) {
                        const hasFormOrBtn = node.querySelector('button, input, a');
                        if (!hasFormOrBtn) node.remove();
                    }
                });
            } catch (_) {}
        }

        static detectTrafficButton() {
            const prioritySelectors = [
                '#trade-d-btn', '#trade-d-btn__content', '#trade-d-btn__arrow',
                '#avt-btn', 'svg#avt-btn', '[id="avt-btn"]',
                '#traffic-button-no__arrow', '.traffic-button__content',
                '#btn-lay-ma', '.btn-lay-ma', '#getcode', '.getcode',
                '[id*="layma"]', '[class*="layma"]', '[id*="1sdesign"]'
            ];

            for (const selector of prioritySelectors) {
                const node = document.querySelector(selector);
                if (node) {
                    const rect = node.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0) return node;
                }
            }

            const imgSelectors = [
                'img[src*="layma"]', 'img[src*="traffic"]', 'img[src*="getcode"]',
                'img[src*="button"]', 'img[alt*="mã" i]', 'img[alt*="code" i]'
            ];
            for (const selector of imgSelectors) {
                const img = document.querySelector(selector);
                if (img) {
                    const rect = img.getBoundingClientRect();
                    if (rect.width > 0 && rect.height > 0) return img;
                }
            }

            const textKeywords = [/lấy\s*mã/i, /get\s*code/i, /mã\s*xác\s*nhận/i, /lấy\s*pass/i, /bấm\s*lấy\s*mã/i];
            const candidateElements = document.querySelectorAll('button, a, div[role="button"]');

            for (const el of candidateElements) {
                const rect = el.getBoundingClientRect();
                if (rect.width <= 0 || rect.height <= 0) continue;

                const text = (el.innerText || el.textContent || '').trim();
                if (text && text.length < 40 && textKeywords.some(rx => rx.test(text))) {
                    const onclick = el.getAttribute('onclick') || '';
                    if (!BANNER_KEYWORDS.some(k => onclick.toLowerCase().includes(k))) {
                        return el;
                    }
                }
            }
            return null;
        }

        static handleIntermediateBypass(gui) {
            let runs = 0;
            const checkTimer = setInterval(() => {
                runs++;
                const verifyLink = document.querySelector('a[href*="activate_link"], a[href*="type=verify"], a[href*="realkidkey.site/api"], a[href*="verify"]');
                if (verifyLink) {
                    const realHref = verifyLink.getAttribute('href') || verifyLink.href;
                    if (realHref && realHref.startsWith('http')) {
                        clearInterval(checkTimer);
                        gui?.log(`🚀 Chuyển hướng link: ${realHref}`, 'info');
                        location.href = realHref;
                        return;
                    }
                }

                const actionLinks = document.querySelectorAll('a, button');
                for (const el of actionLinks) {
                    const text = (el.innerText || el.textContent || '').trim();
                    if (/^lấy\s*link$/i.test(text) \vert{}\vert{} /^get\s*link$/i.test(text)) {
                        clearInterval(checkTimer);
                        gui?.log('⚡ Tìm thấy nút "Lấy link", kích hoạt ngay...', 'info');
                        el.removeAttribute('disabled');
                        if (el.href && el.href.startsWith('http')) {
                            location.href = el.href;
                        } else {
                            el.click();
                        }
                        return;
                    }
                }

                if (runs > 40) clearInterval(checkTimer);
            }, 250);
        }

        static monitorCodeExtraction(gui) {
            let isExtracted = false;
            let zeroStallTimer = null;

            const isValidCode = (raw) => {
                if (!raw) return false;
                const text = raw.trim();
                if (text.length < 4 || text.length > 40) return false;

                if (/^\d+$/.test(text)) {
                    const num = parseInt(text, 10);
                    if (num <= 180) return false;
                }

                if (/^(code|get code|mã code|pass|loading|wait|chờ|giây|seconds)$/i.test(text)) return false;
                if (/lấy mã|vui lòng|chờ duyệt|download/i.test(text)) return false;
                return true;
            };

            const extractCodeFromDOM = () => {
                if (isExtracted) return;

                const codeNodes = document.querySelectorAll(
                    '#trade-d-btn__content, .trade-d-btn__content, .trade-btn-clf__content, .traffic-button__content, .copy-allowed'
                );

                for (const node of codeNodes) {
                    const val = (node.textContent || node.innerText || '').trim();

                    if (val === '0') {
                        if (!zeroStallTimer) {
                            gui?.log('⚠️ Đếm ngược kẹt "0". Kiểm tra reload...', 'warn');
                            zeroStallTimer = setTimeout(() => {
                                const reCheck = (node.textContent || node.innerText || '').trim();
                                if (reCheck === '0') {
                                    isExtracted = true;
                                    gui?.log('🔄 Mã bị lỗi 0s, tải lại trang...', 'err');
                                    showToast('🔄 Mã bị kẹt 0s, đang reload trang...', 'err');
                                    location.reload();
                                } else {
                                    zeroStallTimer = null;
                                }
                            }, CONFIG.ZERO_CODE_CONFIRM_MS);
                        }
                    } else if (val !== '0' && zeroStallTimer) {
                        clearTimeout(zeroStallTimer);
                        zeroStallTimer = null;
                    }

                    if (isValidCode(val)) {
                        if (zeroStallTimer) clearTimeout(zeroStallTimer);
                        isExtracted = true;

                        gui?.log(`🎉 ĐÃ BẮT ĐƯỢC MÃ: [${val}]`, 'info');
                        showToast(`🎉 Bắt được mã: ${val}`, 'info');

                        GM_setValue(CODE_STORAGE_KEY, val);

                        try {
                            GM_setClipboard(val);
                            gui?.log('📋 Đã sao chép mã vào Clipboard.', 'info');
                        } catch (_) {}

                        document.title = `✅ [MÃ: ${val}] - ${document.title}`;

                        setTimeout(() => {
                            gui?.log('🚪 Hoàn tất! Đang đóng tab...', 'info');
                            try { window.close(); } catch (_) {}
                        }, 800);
                        break;
                    }
                }
            };

            const observer = new MutationObserver(() => {
                extractCodeFromDOM();
                if (isExtracted) observer.disconnect();
            });

            const targetRoot = document.body || document.documentElement;
            if (targetRoot) {
                observer.observe(targetRoot, { childList: true, subtree: true, characterData: true });
                extractCodeFromDOM();
            }
        }
    }

    // =============================================================
    // 5. TỰ ĐỘNG NHẬP MÃ XÁC NHẬN VÀ GỬI
    // =============================================================

    function setupAutoFillListener(gui) {
        let submitted = false;

        const attemptSubmit = (codeToFill) => {
            if (!codeToFill || submitted) return;

            let checkCount = 0;
            const submitWatcher = setInterval(() => {
                checkCount++;
                if (submitted || checkCount > 30) {
                    clearInterval(submitWatcher);
                    if (checkCount > 30) GM_deleteValue(CODE_STORAGE_KEY);
                    return;
                }

                const inputElement = document.querySelector(
                    'input[placeholder*="Nhập mã" i], input[placeholder*="xác nhận" i], input[placeholder*="code" i], ' +
                    'input[id*="code" i], input[name*="code" i], input[id*="token" i], main#scroller input[type="text"]'
                );

                if (!inputElement) return;

                if (inputElement.value !== codeToFill) {
                    gui?.log(`⚡ Đang điền mã xác nhận: [${codeToFill}]`, 'info');
                    showToast(`⚡ Đang điền mã: ${codeToFill}`);
                    inputElement.focus();
                    setNativeValue(inputElement, codeToFill);
                }

                const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]'));
                const submitButton = buttons.find(btn =>
                    /nhập mã|xác nhận|gửi|submit|tiếp tục/i.test(btn.textContent || btn.value || '') ||
                    btn.querySelector('.tabler-icon-brand-telegram')
                );

                if (submitButton) {
                    submitted = true;
                    clearInterval(submitWatcher);

                    submitButton.removeAttribute('disabled');
                    submitButton.disabled = false;
                    submitButton.classList.remove('opacity-70', 'cursor-not-allowed');

                    gui?.log('🚀 Đang gửi mã xác thực...', 'info');
                    showToast('🚀 Đã gửi mã thành công!', 'info');

                    GM_deleteValue(CODE_STORAGE_KEY);

                    setTimeout(() => {
                        try { submitButton.click(); } catch (_) {}
                    }, 200);
                }
            }, 300);
        };

        const existingCode = GM_getValue(CODE_STORAGE_KEY, null);
        if (existingCode) attemptSubmit(existingCode);

        try {
            GM_addValueChangeListener(CODE_STORAGE_KEY, (_, __, newCode) => {
                if (newCode && !submitted) {
                    gui?.log(`🔔 Nhận mã từ tab khác: [${newCode}]`, 'info');
                    attemptSubmit(newCode);
                }
            });
        } catch (_) {}
    }

    // =============================================================
    // 6. KHỞI TẠO ĐIỂM VÀO SCRIPT
    // =============================================================

    function initEngine() {
        const gui = new ControlPanel();

        // 1. Phím tắt Alt+Shift+G
        window.addEventListener('keydown', (e) => {
            const isKeyG = e.code === 'KeyG' || (e.key && e.key.toLowerCase() === 'g');
            if (e.altKey && e.shiftKey && isKeyG) {
                e.preventDefault();
                e.stopImmediatePropagation();
                gui.toggle();
            }
        }, true);

        // 2. Menu Extension
        if (typeof GM_registerMenuCommand === 'function') {
            GM_registerMenuCommand('⚡ Ẩn / Hiện Bảng Điều Khiển (Alt+Shift+G)', () => {
                gui.toggle();
            });
        }

        // 3. Khởi tạo & Cơ chế Self-Healing (duy trì sự tồn tại của GUI trước các khung SPA)
        gui.ensureMounted();
        setInterval(() => {
            gui.ensureMounted();
        }, 1000);

        setupAutoFillListener(gui);

        if (!IS_GOOGLE) {
            TargetPageHandler.monitorCodeExtraction(gui);
            TargetPageHandler.handleIntermediateBypass(gui);
        }

        const currentTask = getActiveTask();
        if (!currentTask?.domain) return;

        if (IS_GOOGLE && currentTask.step === 'SEARCHING') {
            GoogleNavigator.run(currentTask, gui);
            return;
        }

        if (!IS_GOOGLE && currentTask.step === 'BYPASSING') {
            TargetPageHandler.run(currentTask, gui);
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', initEngine);
    } else {
        initEngine();
    }

})();
