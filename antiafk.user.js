// ==UserScript==
// @name         Universal Always Active & Anti-AFK Bypass
// @namespace    http://tampermonkey.net/
// @version      1.0.0
// @description  Bypass triệt để cơ chế phát hiện rời tab: rAF, Visibility, IntersectionObserver, Inline Handlers & Anti-AFK
// @match        *://*/*
// @run-at       document-start
// @grant        none
// ==/UserScript==

(function () {
    'use strict';

    // =============================================================
    // 1. GIẢ LẬP ĐẦY ĐỦ VISIBILITY & FOCUS
    // =============================================================
    try {
        const alwaysTrue = () => true;
        const alwaysVisible = () => 'visible';

        Object.defineProperties(document, {
            'hidden': { get: () => false, configurable: true },
            'visibilityState': { get: alwaysVisible, configurable: true },
            'webkitVisibilityState': { get: alwaysVisible, configurable: true },
            'webkitHidden': { get: () => false, configurable: true },
            'hasFocus': { value: alwaysTrue, writable: true, configurable: true }
        });
    } catch (e) {}

    // =============================================================
    // 2. CHẶN INLINE EVENT HANDLERS (window.onblur, document.onvisibilitychange)
    // =============================================================
    const blockedPropEvents = ['onblur', 'onfocusout', 'onvisibilitychange', 'onmouseleave', 'onpagehide'];
    blockedPropEvents.forEach(prop => {
        try {
            Object.defineProperty(window, prop, {
                get: () => null,
                set: () => true,
                configurable: true
            });
            Object.defineProperty(document, prop, {
                get: () => null,
                set: () => true,
                configurable: true
            });
        } catch (e) {}
    });

    // =============================================================
    // 3. CHẶN EVENT RỜI TAB (BẢO VỆ Ô NHẬP LIỆU/INPUT FORM)
    // =============================================================
    const blockedEventTypes = new Set(['visibilitychange', 'webkitvisibilitychange', 'blur', 'focusout', 'mouseleave', 'pagehide']);
    const origAddEventListener = EventTarget.prototype.addEventListener;

    EventTarget.prototype.addEventListener = function (type, listener, options) {
        const lowerType = String(type).toLowerCase();

        if (blockedEventTypes.has(lowerType)) {
            // Không chặn blur/focusout trên các phần tử nhập liệu để tránh làm hỏng UI
            if ((lowerType === 'blur' || lowerType === 'focusout') && this instanceof Element) {
                const tagName = this.tagName ? this.tagName.toLowerCase() : '';
                if (['input', 'textarea', 'select', 'option', 'button'].includes(tagName) || this.isContentEditable) {
                    return origAddEventListener.apply(this, arguments);
                }
            }
            return; // Chặn các listener ẩn/rời tab cấp window & document
        }
        return origAddEventListener.apply(this, arguments);
    };

    // Chặn bắt sự kiện cấp cao nhất
    ['blur', 'visibilitychange', 'pagehide'].forEach(evt => {
        window.addEventListener(evt, e => {
            if (e.target === window || e.target === document) {
                e.stopImmediatePropagation();
            }
        }, true);
    });

    // =============================================================
    // 4. BYPASS INTERSECTION OBSERVER (AN TOÀN ANCESTRY)
    // =============================================================
    if (window.IntersectionObserver) {
        const OrigObserver = window.IntersectionObserver;
        const PatchedObserver = function (callback, options) {
            const wrappedCallback = (entries, observer) => {
                const fakeEntries = entries.map(entry => {
                    return new Proxy(entry, {
                        get: (target, prop) => {
                            if (prop === 'isIntersecting') return true;
                            if (prop === 'intersectionRatio') return 1;
                            return Reflect.get(target, prop);
                        }
                    });
                });
                callback(fakeEntries, observer);
            };
            return new OrigObserver(wrappedCallback, options);
        };
        PatchedObserver.prototype = OrigObserver.prototype;
        window.IntersectionObserver = PatchedObserver;
    }

    // =============================================================
    // 5. HOOK REQUESTANIMATIONFRAME (CÓ FALLBACK CHỐNG LỖI CSP)
    // =============================================================
    let worker = null;
    try {
        const workerCode = `
            self.onmessage = function(e) {
                if (e.data.type === 'raf') {
                    setTimeout(() => {
                        self.postMessage({ type: 'raf', id: e.data.id });
                    }, 1000 / 60);
                }
            };
        `;
        const blob = new Blob([workerCode], { type: 'application/javascript' });
        worker = new Worker(URL.createObjectURL(blob));
    } catch (err) {
        // Nếu bị CSP chặn Worker, trình duyệt tự fallback dùng timer gốc
    }

    if (worker) {
        let rafId = 0;
        const rafMap = new Map();

        window.requestAnimationFrame = function (cb) {
            const id = ++rafId;
            rafMap.set(id, cb);
            worker.postMessage({ type: 'raf', id: id });
            return id;
        };

        window.cancelAnimationFrame = function (id) {
            rafMap.delete(id);
        };

        worker.onmessage = function (e) {
            if (e.data.type === 'raf') {
                const cb = rafMap.get(e.data.id);
                if (cb) {
                    rafMap.delete(e.data.id);
                    cb(performance.now()); // Lấy timestamp chuẩn từ Main Thread
                }
            }
        };
    }

    // =============================================================
    // 6. NÂNG CẤP MÔ PHỎNG TƯƠNG TÁC ĐA DẠNG (ANTI-AFK NÂNG CAO)
    // =============================================================
    setInterval(() => {
        const width = window.innerWidth || 800;
        const height = window.innerHeight || 600;
        const x = Math.floor(Math.random() * width);
        const y = Math.floor(Math.random() * height);

        const target = document.elementFromPoint(x, y) || document.body || window;

        try {
            // Mô phỏng chuỗi sự kiện tương tác tự nhiên: Pointer -> Mouse -> Scroll
            target.dispatchEvent(new PointerEvent('pointermove', { clientX: x, clientY: y, bubbles: true }));
            target.dispatchEvent(new MouseEvent('mousemove', { clientX: x, clientY: y, bubbles: true }));
            window.dispatchEvent(new Event('scroll', { bubbles: true }));
        } catch (e) {}
    }, 2500);

    console.log('%c[Bypass Engine v1.0 Official] Đã kích hoạt đầy đủ tính năng!', 'color: #00ff00; font-weight: bold;');
})();
