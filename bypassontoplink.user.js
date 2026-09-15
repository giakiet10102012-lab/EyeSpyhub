// ==UserScript==
// @name         Google SEO Traffic & Smart Bypass Engine v6.2.1 (Single-Submit Fixed Edition)
// @namespace    http://tampermonkey.net/
// @version      6.2.1
// @description  Bypass SEO Google, mở Tab độc lập, chống trôi mã, Auto Click, Reload khi kẹt mã "0" & Nhập mã đúng 1 lần duy nhất.
// @author       MrDon & Assistant
// @match        *://*.google.com/*
// @match        *://*.google.com.vn/*
// @match        *://google.com/*
// @match        *://google.com.vn/*
// @match        *://*/*
// @include      *://*.google.*/*
// @include      *://google.*/*
// @include      http*://*/*
// @grant        GM_setValue
// @grant        GM_getValue
// @grant        GM_deleteValue
// @grant        GM_setClipboard
// @grant        GM_addValueChangeListener
// @grant        unsafeWindow
// @run-at       document-start
// @noframes
// ==/UserScript==

(function () {
    'use strict';

    if (window.top !== window.self) return;

    const IS_GOOGLE = /(^|\.)google\./i.test(location.hostname);
    const CODE_STORAGE_KEY = 'auto_bypass_code';
    const TASK_KEY = 'seo_task';
    const TASK_TIMEOUT = 10 * 60 * 1000;

    const SEARCH_INTERVAL = 500;
    const SEARCH_MAX_ATTEMPTS = 12;

    const TARGET_INTERVAL = 250;

    const BANNER_KEYWORDS = [
        'banner',
        'popup',
        'float',
        'close',
        'openbanner',
        'ad_'
    ];

    // =============================================================
    // 1. UTILS & HELPER FUNCTIONS
    // =============================================================

    function normalizeText(value) {
        return String(value || '')
            .toLowerCase()
            .normalize('NFKC')
            .replace(/\s+/g, ' ')
            .trim();
    }

    function normalizeDomain(value) {
        let text = normalizeText(value);
        text = text
            .replace(/^(?:https?:\/\/)?(?:www\.)?/i, '')
            .split('/')[0]
            .split('?')[0]
            .split('#')[0]
            .trim();
        return text;
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
            .flatMap(part =>
                part
                    .split(/[-_.~]+/)
                    .map(x => x.trim())
                    .filter(Boolean)
            )
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

    function getRealTargetUrl(element) {
        if (!element) return '';
        let href = element.getAttribute('href') || element.href || '';
        if (!href) return '';
        href = decodeRepeated(href);

        try {
            if (
                href.includes('/url?') ||
                href.includes('/url?q=') ||
                href.includes('/url?sa=')
            ) {
                const queryIndex = href.indexOf('?');
                const query = href.slice(queryIndex + 1);
                const params = new URLSearchParams(query);
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
        if (!original) {
            return { original: '', domain: '', path: '', tokens: [] };
        }

        let value = decodeRepeated(original).trim();

        if (
            !/^https?:\/\//i.test(value) &&
            !/^\/\//.test(value) &&
            !/^[a-z0-9.-]+\.[a-z]{2,}(?:\/|$)/i.test(value)
        ) {
            return {
                original,
                domain: '',
                path: cleanPath(value),
                tokens: getPathTokens(value)
            };
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
            const parts = value
                .replace(/^(?:https?:\/\/)?(?:www\.)?/i, '')
                .split('/');
            return {
                original,
                domain: normalizeDomain(parts.shift() || ''),
                path: cleanPath(parts.join('/')),
                tokens: getPathTokens(parts.join('/'))
            };
        }
    }

    function extractUrlParts(rawHref) {
        try {
            let value = decodeRepeated(rawHref);
            if (!/^https?:\/\//i.test(value)) {
                value = new URL(value, location.href).href;
            }
            const url = new URL(value);
            return {
                url: url.href,
                domain: normalizeDomain(url.hostname),
                path: cleanPath(url.pathname),
                query: normalizeText(url.search),
                hash: normalizeText(url.hash)
            };
        } catch (_) {
            const text = normalizeText(rawHref);
            return {
                url: text,
                domain: normalizeDomain(text),
                path: '',
                query: '',
                hash: ''
            };
        }
    }

    function tokenMatchScore(targetTokens, candidateTokens) {
        if (!targetTokens.length) return 0;
        let matched = 0;
        for (const targetToken of targetTokens) {
            const exact = candidateTokens.some(ct => ct === targetToken);
            if (exact) {
                matched += 1;
                continue;
            }
            const partial = candidateTokens.some(
                ct => ct.includes(targetToken) || targetToken.includes(ct)
            );
            if (partial) matched += 0.7;
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
            if (
                candidateParts.some(
                    cp => cp === targetPart || cp.includes(targetPart) || targetPart.includes(cp)
                )
            ) {
                matched++;
            }
        }
        return matched / Math.max(targetParts.length, 1);
    }

    function getVisibleUrlText(link) {
        if (!link) return '';
        const parent =
            link.closest('div.MjjYud, div.tF2Cxc, div.g, div[data-snhf], div') ||
            link.parentElement;
        if (!parent) return '';
        return normalizeText(parent.innerText || parent.textContent || '');
    }

    function getUrlMatchScore(element, userTarget) {
        const href = getRealTargetUrl(element);
        if (!href) return -Infinity;

        const target = parseTargetInput(userTarget);
        const candidate = extractUrlParts(href);
        const rawTargetClean = normalizeText(userTarget).replace(/^https?:\/\//i, '').replace(/^www\./i, '');
        let score = 0;

        if (rawTargetClean) {
            if (candidate.domain.includes(rawTargetClean) || rawTargetClean.includes(candidate.domain)) {
                score += 60;
            }
            if (candidate.url.includes(rawTargetClean)) {
                score += 40;
            }
        }

        if (target.domain) {
            if (candidate.domain === target.domain) {
                score += 100;
            } else if (candidate.domain.endsWith(`.${target.domain}`) || target.domain.endsWith(`.${candidate.domain}`)) {
                score += 80;
            } else if (candidate.domain.includes(target.domain) || target.domain.includes(candidate.domain)) {
                score += 40;
            }
        }

        if (target.path) {
            const pathScore = sequenceScore(target.path, candidate.path);
            const tokenScore = tokenMatchScore(target.tokens, getPathTokens(candidate.path));
            score += pathScore * 50;
            score += tokenScore * 30;
        }

        const visibleText = getVisibleUrlText(element);
        if (visibleText && rawTargetClean) {
            if (visibleText.includes(rawTargetClean)) {
                score += 30;
            }
        }

        if (candidate.url.includes('google.') || candidate.url.includes('/search')) {
            score -= 100;
        }

        return score;
    }

    function findBestMatchingLink(userTarget) {
        const links = document.querySelectorAll('a[href]');
        let best = null;
        let bestScore = -Infinity;

        for (const link of links) {
            if (!link.isConnected) continue;
            const href = getRealTargetUrl(link);
            if (!href) continue;

            const score = getUrlMatchScore(link, userTarget);
            if (score > bestScore) {
                bestScore = score;
                best = { element: link, url: href, score };
            }
        }

        if (!best || bestScore < 30) return null;
        return best;
    }

    function isBlacklisted(str) {
        if (!str) return false;
        const value = normalizeText(str);
        return BANNER_KEYWORDS.some(keyword => value.includes(keyword));
    }

    function getActiveTask() {
        const task = GM_getValue(TASK_KEY, null);
        if (!task) return null;
        if (!task.timestamp || Date.now() - task.timestamp > TASK_TIMEOUT) {
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
        element.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
    }

    function executeAdvancedClick(element, gui) {
        if (!element) return;

        gui?.log('🎯 Tìm thấy nút lấy mã! Đang kích hoạt...', 'info');

        try {
            element.scrollIntoView({ behavior: 'smooth', block: 'center', inline: 'center' });
        } catch (_) {}

        setTimeout(() => {
            if (!element.isConnected) return;

            const rect = element.getBoundingClientRect();
            if (!rect.width || !rect.height) return;

            const clickX = Math.round(rect.left + rect.width / 2);
            const clickY = Math.round(rect.top + rect.height / 2);

            showClickIndicator(clickX, clickY);

            const targets = [
                element,
                element.closest('a'),
                element.closest('button'),
                element.closest('[onclick]'),
                element.parentElement
            ].filter(Boolean);

            const uniqueTargets = [...new Set(targets)];

            uniqueTargets.forEach(tgt => {
                try {
                    const onclickAttr = tgt.getAttribute('onclick');
                    if (onclickAttr) {
                        if (typeof unsafeWindow !== 'undefined') unsafeWindow.eval(onclickAttr);
                        else window.eval(onclickAttr);
                    }

                    const hrefAttr = tgt.getAttribute('href');
                    if (hrefAttr && hrefAttr.startsWith('javascript:')) {
                        const jsCode = hrefAttr.replace(/^javascript:/i, '');
                        if (typeof unsafeWindow !== 'undefined') unsafeWindow.eval(jsCode);
                        else window.eval(jsCode);
                    }
                } catch (e) {}
            });

            try {
                const jq = (typeof unsafeWindow !== 'undefined' ? unsafeWindow.$ || unsafeWindow.jQuery : null) || window.$ || window.jQuery;
                if (jq) {
                    uniqueTargets.forEach(tgt => {
                        try { jq(tgt).trigger('click'); } catch (_) {}
                    });
                }
            } catch (_) {}

            const eventTypes = ['pointerdown', 'mousedown', 'pointerup', 'mouseup', 'click'];
            const eventOptions = {
                bubbles: true,
                cancelable: true,
                view: typeof unsafeWindow !== 'undefined' ? unsafeWindow : window,
                clientX: clickX,
                clientY: clickY,
                button: 0,
                buttons: 1
            };

            uniqueTargets.forEach(tgt => {
                eventTypes.forEach(type => {
                    try { tgt.dispatchEvent(new MouseEvent(type, eventOptions)); } catch (_) {}
                });
                if (typeof tgt.click === 'function') {
                    try { tgt.click(); } catch (_) {}
                }
            });

            clearTask();
            gui?.log('✅ ĐÃ KÍCH HOẠT NÚT THÀNH CÔNG!', 'info');
        }, 500);
    }

    function showClickIndicator(x, y) {
        const old = document.getElementById('mrdon-click-indicator');
        old?.remove();

        const dot = document.createElement('div');
        dot.id = 'mrdon-click-indicator';
        dot.style.cssText = `
            position: fixed; top: ${y - 15}px; left: ${x - 15}px;
            width: 30px; height: 30px; background: rgba(255,69,0,.9);
            border: 3px solid #fff; border-radius: 50%; z-index: 999999999;
            pointer-events: none; box-shadow: 0 0 20px #ff4500;
        `;

        (document.body || document.documentElement).appendChild(dot);
        setTimeout(() => { try { dot.remove(); } catch (_) {} }, 2000);
    }

    // MAIN GUI INTERFACE
    class MainGUI {
        constructor() {
            this.container = null;
            this.logConsole = null;
            this.inputKeyword = null;
            this.inputDomain = null;
        }

        init(callback) {
            if (document.getElementById('mrdon-main-gui')) {
                callback?.();
                return;
            }

            const renderWhenReady = () => {
                if (!document.body && !document.documentElement) return;
                clearInterval(waitTimer);
                this.renderGUI();
                callback?.();
            };

            const waitTimer = setInterval(renderWhenReady, 50);
            renderWhenReady();
        }

        renderGUI() {
            if (document.getElementById('mrdon-main-gui')) return;

            this.container = document.createElement('div');
            this.container.id = 'mrdon-main-gui';

            this.container.style.cssText = `
                position: fixed; top: 20px; right: 20px; width: 320px;
                background: #181825; color: #cdd6f4; border: 2px solid #cba6f7;
                border-radius: 12px; padding: 12px; font-family: sans-serif;
                font-size: 12px; z-index: 99999999; box-shadow: 0 8px 24px rgba(0,0,0,.7);
                user-select: none; display: none;
            `;

            const header = document.createElement('div');
            header.style.cssText = 'font-weight: bold; color: #cba6f7; margin-bottom: 8px; display: flex; justify-content: space-between; cursor: move;';

            const title = document.createElement('span');
            title.textContent = '⚡ SEO Bypass Engine v6.2.1';

            const shortcut = document.createElement('span');
            shortcut.style.cssText = 'font-size: 10px; color: #a6e3a1;';
            shortcut.textContent = '[Alt+Shift+G]';

            header.append(title, shortcut);
            this.container.appendChild(header);

            this.inputKeyword = document.createElement('input');
            this.inputKeyword.type = 'text';
            this.inputKeyword.placeholder = 'Từ khóa Google...';
            this.styleInput(this.inputKeyword);
            this.container.appendChild(this.inputKeyword);

            this.inputDomain = document.createElement('input');
            this.inputDomain.type = 'text';
            this.inputDomain.placeholder = 'Link gần đúng / Domain đích...';
            this.styleInput(this.inputDomain);
            this.container.appendChild(this.inputDomain);

            const btnGroup = document.createElement('div');
            btnGroup.style.cssText = 'display: flex; gap: 6px;';

            const startBtn = document.createElement('button');
            startBtn.textContent = 'BẮT ĐẦU';
            startBtn.style.cssText = 'flex: 1; background: #cba6f7; color: #11111b; border: none; padding: 8px; font-weight: bold; border-radius: 6px; cursor: pointer;';

            const resetBtn = document.createElement('button');
            resetBtn.textContent = 'XÓA TASK';
            resetBtn.style.cssText = 'flex: 1; background: #f38ba8; color: #11111b; border: none; padding: 8px; font-weight: bold; border-radius: 6px; cursor: pointer;';

            btnGroup.append(startBtn, resetBtn);
            this.container.appendChild(btnGroup);

            this.logConsole = document.createElement('div');
            this.logConsole.style.cssText = 'background: #11111b; border: 1px solid #313244; height: 110px; margin-top: 8px; padding: 6px; overflow-y: auto; color: #a6e3a1; border-radius: 6px; font-size: 11px;';

            this.container.appendChild(this.logConsole);
            (document.body || document.documentElement).appendChild(this.container);

            this.makeDraggable(header);

            const task = getActiveTask();
            if (task) {
                this.inputKeyword.value = task.keyword || '';
                this.inputDomain.value = task.domain || '';
                this.log(`🔄 Task: [${task.domain}] - Mode: Auto Detect`, 'info');
            }

            startBtn.addEventListener('click', () => {
                const keyword = this.inputKeyword.value.trim();
                const domain = this.inputDomain.value.trim();

                if (!keyword || !domain) {
                    alert('Vui lòng nhập đầy đủ Từ Khóa và Link/Domain!');
                    return;
                }

                const task = {
                    keyword,
                    domain,
                    originUrl: location.href,
                    step: 'SEARCHING',
                    page: 1,
                    timestamp: Date.now()
                };

                saveTask(task);
                this.log(`🚀 Giữ Tab gốc. Mở Google tìm: ${domain}`, 'info');
                window.open(`https://www.google.com/search?q=${encodeURIComponent(keyword)}`, '_blank');
            });

            resetBtn.addEventListener('click', () => {
                clearTask();
                this.inputKeyword.value = '';
                this.inputDomain.value = '';
                this.log('🧹 Đã dọn dẹp bộ nhớ!', 'warn');
            });
        }

        styleInput(input) {
            input.style.cssText = 'width: 95%; background: #313244; border: 1px solid #45475a; color: #cdd6f4; padding: 7px; border-radius: 6px; margin-bottom: 6px; outline: none; font-size: 12px;';
        }

        makeDraggable(header) {
            let dragging = false;
            let offsetX = 0, offsetY = 0;

            header.addEventListener('mousedown', event => {
                dragging = true;
                const rect = this.container.getBoundingClientRect();
                offsetX = event.clientX - rect.left;
                offsetY = event.clientY - rect.top;
            });

            document.addEventListener('mousemove', event => {
                if (!dragging || !this.container) return;
                this.container.style.left = `${event.clientX - offsetX}px`;
                this.container.style.top = `${event.clientY - offsetY}px`;
                this.container.style.right = 'auto';
            });

            document.addEventListener('mouseup', () => { dragging = false; });
        }

        log(message, type = 'info') {
            const time = new Date().toLocaleTimeString('vi-VN', { hour12: false });
            const logMsg = `[Bypass Tool ${time}] ${message}`;

            if (type === 'err') console.error(`%c${logMsg}`, 'color: #f38ba8; font-weight: bold;');
            else if (type === 'warn') console.warn(`%c${logMsg}`, 'color: #f9e2af; font-weight: bold;');
            else console.log(`%c${logMsg}`, 'color: #a6e3a1; font-weight: bold;');

            if (!this.logConsole) return;
            const p = document.createElement('p');
            p.style.margin = '2px 0';
            p.style.color = type === 'err' ? '#f38ba8' : type === 'warn' ? '#f9e2af' : '#a6e3a1';
            p.textContent = `[${time}] ${message}`;
            this.logConsole.appendChild(p);
            this.logConsole.scrollTop = this.logConsole.scrollHeight;
        }

        toggle() {
            if (!this.container) {
                this.init();
                return;
            }
            const hidden = this.container.style.display === 'none';
            this.container.style.display = hidden ? 'block' : 'none';
        }
    }

    // GOOGLE SEARCH HANDLER
    class GoogleSearchHandler {
        static handle(task, gui) {
            gui?.log(`🔍 Quét link mờ trùng khớp: "${task.domain}"...`, 'info');

            let isProcessing = false;
            let observer = null;
            let fallbackTimer = null;

            const cleanup = () => {
                if (observer) { observer.disconnect(); observer = null; }
                if (fallbackTimer) { clearInterval(fallbackTimer); fallbackTimer = null; }
            };

            const scanGooglePage = () => {
                if (isProcessing) return;
                const result = findBestMatchingLink(task.domain);
                if (!result) return;

                isProcessing = true;
                cleanup();

                const { element, url, score } = result;
                gui?.log(`✅ Chọn link (điểm ${score.toFixed(1)}): ${url}`, 'info');

                task.step = 'BYPASSING';
                task.matchedUrl = url;
                task.matchScore = score;
                saveTask(task);

                try { element.scrollIntoView({ behavior: 'smooth', block: 'center' }); } catch (_) {}

                setTimeout(() => {
                    try { element.click(); } catch (_) {}
                    setTimeout(() => { location.href = url; }, 500);
                }, 500);
            };

            observer = new MutationObserver(scanGooglePage);
            observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
            scanGooglePage();

            let attempts = 0;
            fallbackTimer = setInterval(() => {
                if (isProcessing) { cleanup(); return; }
                attempts++;
                scanGooglePage();

                if (attempts >= SEARCH_MAX_ATTEMPTS && !isProcessing) {
                    cleanup();
                    const nextBtn = document.querySelector('#pnnext, a[id="pnnext"], a[aria-label*="Next"], a[aria-label*="Trang sau"], [jsname="Te322e"]');

                    if (!nextBtn) {
                        gui?.log(`❌ Không tìm thấy link cho "${task.domain}".`, 'err');
                        return;
                    }

                    task.page = Number(task.page || 1) + 1;
                    task.step = 'SEARCHING';
                    saveTask(task);

                    gui?.log(`➡️ Sang trang Google ${task.page}...`, 'info');
                    setTimeout(() => {
                        try { nextBtn.click(); } catch (_) {}
                        setTimeout(() => {
                            if (location.href.includes('/search')) {
                                GoogleSearchHandler.handle(getActiveTask() || task, gui);
                            }
                        }, 1200);
                    }, 600);
                }
            }, SEARCH_INTERVAL);
        }
    }

    // TARGET PAGE & INTERMEDIATE PAGE HANDLER
    class TargetPageHandler {
        static handle(task, gui) {
            gui?.log('🌐 Đang quét tự động nút lấy mã (Ontop & Gtraffic)...', 'info');

            let attempts = 0;
            let direction = 1;

            const timer = setInterval(() => {
                attempts++;
                const foundBtn = TargetPageHandler.scanNodeAllLayers();

                if (foundBtn) {
                    clearInterval(timer);
                    executeAdvancedClick(foundBtn, gui);
                    return;
                }

                if (attempts % 3 === 0) {
                    const scrollStep = 350;
                    const isAtBottom = (window.innerHeight + window.scrollY) >= (document.documentElement.scrollHeight - 100);
                    const isAtTop = window.scrollY <= 50;

                    if (isAtBottom && direction === 1) {
                        gui?.log('📜 Đã cuộn xuống cuối trang, quay ngược lên...', 'warn');
                        direction = -1;
                    } else if (isAtTop && direction === -1) {
                        direction = 1;
                    }

                    window.scrollBy({ top: scrollStep * direction, behavior: 'smooth' });
                }
            }, TARGET_INTERVAL);
        }

        static scanNodeAllLayers() {
            const allImgSelectors = [
                '#trade-d-btn', '#trade-d-btn__arrow', '#trade-d-btn__content',
                'svg#avt-btn', '#avt-btn', '[id="avt-btn"]',
                'rect[fill*="pattern0_647_11"]', 'img[src*="play"]', 'img[src*="red"]',
                'img[src*="button"]', 'img[src*="layma"]', 'img[src*="traffic"]',
                'img[src*="code"]', 'img[alt*="mã"]', 'img[alt*="code"]',
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

            const elements = document.querySelectorAll('button, a, div, span, p, input[type="button"], input[type="submit"], img, rect, svg');

            for (const el of elements) {
                const rect = el.getBoundingClientRect();
                if (rect.width <= 0 || rect.height <= 0) continue;

                const text = (el.innerText || el.value || el.getAttribute('alt') || el.getAttribute('title') || '').trim();

                if (text && text.length < 50 && textKeywords.some(regex => regex.test(text))) {
                    const onclick = el.getAttribute('onclick') || '';
                    if (!isBlacklisted(onclick)) {
                        const childImg = el.querySelector('img, svg, rect');
                        return childImg || el;
                    }
                }
            }

            const allSelectors = [
                '#trade-d-btn', '#avt-btn', 'svg#avt-btn',
                '#traffic-button-no__arrow', '.traffic-button__content', '[class*="layma"]',
                '[id*="layma"]', '[class*="l4m"]', '[id*="l4m"]', 'button[class*="traffic"]',
                'a[class*="traffic"]', 'div[class*="traffic"]', '#btn-lay-ma', '.btn-lay-ma',
                '#getcode', '.getcode'
            ];

            for (const selector of allSelectors) {
                try {
                    const elements = document.querySelectorAll(selector);
                    for (const el of elements) {
                        const rect = el.getBoundingClientRect();
                        if (rect.width <= 0 || rect.height <= 0) continue;
                        const onclick = el.getAttribute('onclick') || '';
                        if (!isBlacklisted(onclick)) return el;
                    }
                } catch (_) {}
            }

            return null;
        }

        static handleIntermediateBypass(gui) {
            const checkAndBypass = () => {
                const targetLink = document.querySelector('a[href*="activate_link"], a[href*="type=verify"], a[href*="realkidkey.site/api"], a[href*="verify"]');
                if (targetLink) {
                    const realHref = targetLink.getAttribute('href') || targetLink.href;
                    if (realHref && realHref.startsWith('http')) {
                        gui?.log(`🚀 Tự động kích hoạt Link đếm ngược 0s: ${realHref}`, 'info');
                        location.href = realHref;
                        return true;
                    }
                }

                const links = document.querySelectorAll('a, button');
                for (const el of links) {
                    const text = (el.innerText || el.textContent || '').trim();
                    if (/^lấy\s*link$/i.test(text) || /lấy\s*link/i.test(text) || /get\s*link/i.test(text)) {
                        gui?.log('⚡ Tìm thấy nút "Lấy link", kích hoạt ngay...', 'info');
                        el.removeAttribute('disabled');
                        el.style.pointerEvents = 'auto';
                        el.style.display = 'flex';

                        if (el.href && el.href.startsWith('http')) {
                            location.href = el.href;
                        } else {
                            el.click();
                        }
                        return true;
                    }
                }
                return false;
            };

            const fastTimer = setInterval(() => {
                if (checkAndBypass()) clearInterval(fastTimer);
            }, 100);
        }

        static startCodeExtraction(gui) {
            let extracted = false;
            let zeroErrorTimer = null;

            const isCodeValid = (text) => {
                if (!text) return false;
                const clean = text.trim();
                if (clean.length < 4 || clean.length > 30) return false;
                if (/^\d+$/.test(clean)) return false;
                if (/^(code|get code|mã code|pass|password|lấy mã|lay ma|wait|loading|click|xem mã)$/i.test(clean)) return false;
                if (/lấy mã|chờ|wait|click|vui lòng|giây|seconds|download|chờ duyệt|bấm vào/i.test(clean)) return false;
                return true;
            };

            const checkAndExtract = () => {
                if (extracted) return;

                const codeElements = document.querySelectorAll(
                    '#trade-d-btn__content, .trade-d-btn__content.copy-allowed, .trade-d-btn__content, ' +
                    '.trade-btn-clf__content.copy-allowed, .trade-btn-clf__content, .traffic-button__content.copy-allowed, ' +
                    '.traffic-button__content, .copy-allowed span, .copy-allowed'
                );

                for (const el of codeElements) {
                    const val = (el.textContent || el.innerText || '').trim();

                    if (val === '0') {
                        if (!zeroErrorTimer) {
                            gui?.log('⚠️ Phát hiện mã bị kẹt bằng "0". Chờ 1.5s xác nhận trước khi Reload...', 'warn');
                            zeroErrorTimer = setTimeout(() => {
                                const reCheckVal = (el.textContent || el.innerText || '').trim();
                                if (reCheckVal === '0') {
                                    extracted = true;
                                    gui?.log('🔄 Mã bị lỗi "0"! Đang tự động Reload trang...', 'err');
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

                        GM_setValue(CODE_STORAGE_KEY, val);

                        try {
                            GM_setClipboard(val);
                            gui?.log('📋 Đã copy mã vào Clipboard!', 'info');
                        } catch (_) {}

                        document.title = `✅ [ĐÃ COPY MÃ: ${val}] - ${document.title}`;

                        gui?.log('🚪 Đã lấy xong mã! Tự động tắt Tab...', 'info');
                        setTimeout(() => { try { window.close(); } catch (_) {} }, 500);
                        break;
                    }
                }
            };

            const intervalId = setInterval(() => {
                if (extracted) { clearInterval(intervalId); return; }
                checkAndExtract();
            }, 200);

            const observer = new MutationObserver(() => {
                checkAndExtract();
                if (extracted) observer.disconnect();
            });

            observer.observe(document.body || document.documentElement, {
                childList: true, subtree: true, characterData: true
            });
        }
    }

    // TỰ ĐỘNG DÁN MÃ VÀO TRANG ĐÍCH (ĐÃ FIX: CHỈ ĐIỀN VÀ GỬI 1 LẦN DUY NHẤT)
    function handleAutoFillAndSubmit(gui) {
        let isSubmitted = false; // Cờ khóa trạng thái gửi mã

        const trySubmitCode = (savedCode) => {
            if (!savedCode || isSubmitted) return;

            let watchdogTimer = null;
            let attempts = 0;

            const executeFillAndWatch = () => {
                if (document.readyState !== 'complete') {
                    setTimeout(executeFillAndWatch, 500);
                    return;
                }

                setTimeout(() => {
                    const fillAndCheck = () => {
                        if (isSubmitted) return true;

                        const inputEl = document.querySelector(
                            'input[placeholder*="Nhập mã xác nhận"], main#scroller input[type="text"], input[placeholder*="mã"], input[type="text"]'
                        );
                        if (!inputEl) return false;

                        // Điền mã vào ô duy nhất 1 lần
                        if (inputEl.value !== savedCode) {
                            gui?.log(`⚡ Tiến hành điền mã vào ô: [${savedCode}]`, 'info');
                            inputEl.focus();
                            setNativeValue(inputEl, savedCode);
                        }

                        const buttons = Array.from(document.querySelectorAll('button, input[type="submit"]'));
                        const submitBtn = buttons.find(btn =>
                            /nhập mã|gửi|submit|xác nhận|nhập mã xác nhận/i.test(btn.textContent || btn.value) ||
                            btn.querySelector('.tabler-icon-brand-telegram')
                        );

                        if (submitBtn) {
                            // Đặt cờ khóa ngay lập tức để không chạy lại lần 2
                            isSubmitted = true;
                            if (watchdogTimer) clearInterval(watchdogTimer);

                            submitBtn.removeAttribute('disabled');
                            submitBtn.disabled = false;
                            submitBtn.classList.remove('opacity-70', 'cursor-not-allowed');

                            gui?.log('🚀 Đang gửi mã (Xác nhận 1 lần duy nhất)...', 'info');

                            // Xóa mã trong bộ nhớ ngay để tránh gửi lại trên tab khác/reload
                            GM_deleteValue(CODE_STORAGE_KEY);

                            setTimeout(() => {
                                try { submitBtn.click(); } catch (_) {}
                            }, 200);

                            return true;
                        }
                        return false;
                    };

                    if (fillAndCheck()) return;

                    watchdogTimer = setInterval(() => {
                        attempts++;
                        if (fillAndCheck() || attempts > 20 || isSubmitted) {
                            clearInterval(watchdogTimer);
                            if (attempts > 20) {
                                GM_deleteValue(CODE_STORAGE_KEY);
                            }
                        }
                    }, 500);

                }, 1000);
            };

            executeFillAndWatch();
        };

        const existingCode = GM_getValue(CODE_STORAGE_KEY, null);
        if (existingCode) {
            trySubmitCode(existingCode);
        }

        try {
            GM_addValueChangeListener(CODE_STORAGE_KEY, (name, oldValue, newValue, remote) => {
                if (newValue && !isSubmitted) {
                    gui?.log(`🔔 Nhận mã realtime: [${newValue}]`, 'info');
                    trySubmitCode(newValue);
                }
            });
        } catch (_) {}
    }

    // MAIN ENTRY POINT
    function main() {
        const gui = new MainGUI();
        gui.init(() => {
            window.addEventListener('keydown', event => {
                if (event.altKey && event.shiftKey && event.key.toLowerCase() === 'g') {
                    event.preventDefault();
                    gui.toggle();
                }
            });

            handleAutoFillAndSubmit(gui);

            if (!IS_GOOGLE) {
                TargetPageHandler.startCodeExtraction(gui);
                TargetPageHandler.handleIntermediateBypass(gui);
            }

            const task = getActiveTask();
            if (!task?.domain) return;

            if (IS_GOOGLE && task.step === 'SEARCHING') {
                GoogleSearchHandler.handle(task, gui);
                return;
            }

            if (!IS_GOOGLE && task.step === 'BYPASSING') {
                TargetPageHandler.handle(task, gui);
            }
        });
    }

    main();

})();
