import SwiftUI
import WebKit
import Combine

class WebViewModel: ObservableObject {
    static let shared = WebViewModel()
    
    @Published var trackTitle: String = "Не играет"
    @Published var artist: String = "Загрузка..."
    @Published var coverURL: String = ""
    @Published var isPlaying: Bool = false
    @Published var progress: Double = 0.0
    @Published var positionText: String = "0:00"
    @Published var remainingText: String = "0:00"
    
    var webView: WKWebView?
    
    func playPause() {
        let js = """
        (function() {
            try {
                var player = document.querySelector('section[aria-label="Плеер" i], [class*="PlayerBar" i], [class*="player-controls" i]');
                if (!player) return;

                function doClick(target) {
                    if (typeof target.click === 'function') {
                        target.click();
                    } else {
                        target.dispatchEvent(new MouseEvent('click', {bubbles: true, cancelable: true, view: window}));
                    }
                }

                // 1. Ищем кнопку по внутренней SVG иконке (самый железобетонный метод)
                var svgs = player.querySelectorAll('use');
                for (var i = 0; i < svgs.length; i++) {
                    var href = svgs[i].getAttribute('xlink:href') || svgs[i].getAttribute('href') || '';
                    var isTarget = false;
                    
                    if (href.indexOf('#pause') !== -1) isTarget = true;
                    // Ищем #play, но исключаем #playlist, #player и т.д.
                    if (href.indexOf('#play') !== -1 && href.indexOf('playlist') === -1 && href.indexOf('player') === -1) isTarget = true;
                    
                    if (isTarget) {
                        var btn = svgs[i].closest('button, [role="button"]') || svgs[i].parentElement;
                        doClick(btn);
                        return;
                    }
                }

                // 2. Ищем по aria-label или title, если SVG поменяли
                var labels = ['Пауза', 'Pause', 'Играть', 'Воспроизвести', 'Play', 'Слушать'];
                for (var i = 0; i < labels.length; i++) {
                    var btn = player.querySelector('[aria-label*="' + labels[i] + '" i], [title*="' + labels[i] + '" i]');
                    if (btn) {
                        var target = btn.closest('button, [role="button"]') || btn;
                        doClick(target);
                        return;
                    }
                }

                // 3. Запасной вариант - кнопка поверх обложки
                var coverBtn = player.querySelector('[class*="playButton" i], [class*="PlayButton" i]');
                if (coverBtn) {
                    doClick(coverBtn);
                    return;
                }
                
                // Если плеера нет - пытаемся включить "Мою Волну"
                var vibeBtn = document.querySelector('[aria-label*="Моя волна" i], [class*="Vibe" i]');
                if (vibeBtn) doClick(vibeBtn);
                
            } catch(e) {}
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func nextTrack() {
        let js = """
        (function() {
            if (typeof externalAPI !== 'undefined') { externalAPI.next(); return; }
            var player = document.querySelector('section[aria-label="Плеер" i], [class*="PlayerBar" i]') || document;
            var btn = player.querySelector('[aria-label*="Следующ" i], [aria-label*="Вперед" i], use[href*="#next" i]');
            if (btn) {
                var target = btn.closest('button') || btn;
                target.click();
            }
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func prevTrack() {
        let js = """
        (function() {
            if (typeof externalAPI !== 'undefined') { externalAPI.prev(); return; }
            var player = document.querySelector('section[aria-label="Плеер" i], [class*="PlayerBar" i]') || document;
            var btn = player.querySelector('[aria-label*="Предыдущ" i], [aria-label*="Назад" i], use[href*="#previous" i], use[href*="#prev" i]');
            if (btn) {
                var target = btn.closest('button') || btn;
                target.click();
            }
        })();
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func seek(to progress: Double) {
        let js = """
        if (typeof externalAPI !== 'undefined') {
            var track = externalAPI.getCurrentTrack();
            var dur = track ? track.duration : 0;
            if (dur > 0) externalAPI.setPosition(\(progress) * dur);
        } else {
            var media = document.querySelector('video, audio');
            var success = false;
            if (media && media.duration && media.duration !== Infinity && media.duration > 0) {
                media.currentTime = \(progress) * media.duration;
                success = true;
            }
            if (!success) {
                var bars = document.querySelectorAll('[role="slider"], [class*="progress" i], [class*="timeline" i]');
                if (bars.length > 0) {
                    var bar = bars[bars.length - 1];
                    var rect = bar.getBoundingClientRect();
                    var x = rect.left + rect.width * \(progress);
                    var y = rect.top + rect.height / 2;
                    var opts = { bubbles: true, clientX: x, clientY: y };
                    bar.dispatchEvent(new PointerEvent('pointerdown', opts));
                    bar.dispatchEvent(new MouseEvent('mousedown', opts));
                    bar.dispatchEvent(new MouseEvent('mouseup', opts));
                    bar.dispatchEvent(new PointerEvent('pointerup', opts));
                    bar.dispatchEvent(new MouseEvent('click', opts));
                }
            }
        }
        """
        webView?.evaluateJavaScript(js, completionHandler: nil)
    }
    
    func checkMetadata() {
        let js = """
        (function() {
            try {
                var title = 'Не играет';
                var artist = '';
                var cover = '';
                var isPlaying = false;
                var position = 0;
                var duration = 0;
                
                // 1. Попытка через Yandex externalAPI
                if (typeof externalAPI !== 'undefined') {
                    try {
                        var track = externalAPI.getCurrentTrack();
                        if (track) {
                            title = track.title || title;
                            artist = track.artists ? track.artists.map(a => a.title).join(', ') : artist;
                            cover = track.cover ? 'https://' + track.cover.replace('%%', '400x400') : cover;
                        }
                        if (externalAPI.isPlaying()) isPlaying = true;
                        var p = externalAPI.getProgress();
                        if (p && p.duration > 0) {
                            position = p.position;
                            duration = p.duration;
                        }
                    } catch(e) {}
                }
                
                // 2. Универсальный Media Session API
                if (navigator.mediaSession) {
                    if (navigator.mediaSession.metadata) {
                        var md = navigator.mediaSession.metadata;
                        title = md.title || title;
                        artist = md.artist || artist;
                        var artwork = md.artwork;
                        if (artwork && artwork.length > 0) {
                            var src = artwork[artwork.length - 1].src;
                            if (src.includes('avatars.yandex.net')) {
                                cover = src.replace(/\\d+x\\d+/, '400x400');
                            } else {
                                cover = src;
                            }
                        }
                    }
                    if (navigator.mediaSession.playbackState === 'playing') isPlaying = true;
                    if (navigator.mediaSession.positionState && navigator.mediaSession.positionState.duration > 0) {
                        position = navigator.mediaSession.positionState.position;
                        duration = navigator.mediaSession.positionState.duration;
                    }
                }
                
                // 2.5 Расширенный поиск по DOM (на случай отключения Media Session)
                if (title === 'Не играет' || title === '') {
                    var titleEl = document.querySelector('[class*="TrackTitle_title" i], [class*="track-title" i], [class*="Player_title" i], [data-test-id="track-title" i]');
                    if (titleEl) title = titleEl.innerText || titleEl.textContent;
                    
                    var artistEl = document.querySelector('[class*="TrackTitle_artists" i], [class*="track-artist" i], [class*="Player_artist" i], [data-test-id="track-artist" i]');
                    if (artistEl) artist = artistEl.innerText || artistEl.textContent;
                }
                
                // 3. Прямой опрос DOM-тегов audio/video
                var mediaList = document.querySelectorAll('audio, video');
                var isDOMPlaying = false;
                for (var i = 0; i < mediaList.length; i++) {
                    var m = mediaList[i];
                    if (!m.paused) {
                        isDOMPlaying = true;
                        if (duration === 0 && m.duration > 0 && m.duration !== Infinity) {
                            position = m.currentTime;
                            duration = m.duration;
                        }
                    }
                }
                if (isDOMPlaying) isPlaying = true;
                
                // 4. Поиск ползунка прогресса в React UI (как запасной вариант для времени)
                if (duration === 0 || isNaN(duration)) {
                    var slider = document.querySelector('[role="slider"][aria-valuemax]');
                    if (slider) {
                        var val = parseFloat(slider.getAttribute('aria-valuenow'));
                        var max = parseFloat(slider.getAttribute('aria-valuemax'));
                        if (!isNaN(val) && !isNaN(max) && max > 0) {
                            position = val;
                            duration = max;
                        }
                    }
                }
                
                // 5. Проверка кнопок Play/Pause в интерфейсе
                if (!isPlaying) {
                    // Только кнопки внутри плеера: классы с "pause" встречаются на странице и без воспроизведения
                    var playerBar = document.querySelector('section[aria-label="Плеер" i], [class*="PlayerBar" i], [class*="player-controls" i]');
                    var pauseBtn = playerBar ? playerBar.querySelector('[aria-label*="Пауза" i], [title*="Пауза" i], [aria-label*="Pause" i], [title*="Pause" i]') : null;
                    if (pauseBtn) isPlaying = true;
                }
                
                // Резервный поиск обложки
                if (cover === '' || cover === 'Не играет') {
                    var images = document.querySelectorAll('img');
                    for (var i = 0; i < images.length; i++) {
                        var imgsrc = images[i].src;
                        if (imgsrc && imgsrc.includes('avatars.yandex.net/get-music-content')) {
                            cover = imgsrc.replace(/\\d+x\\d+/, '400x400');
                        }
                    }
                }
                
                // Итоги
                var progress = 0.0;
                if (duration > 0) progress = position / duration;
                progress = Math.max(0.0, Math.min(1.0, progress));
                
                function formatTime(sec) {
                    if (!sec || isNaN(sec) || sec === Infinity) return "0:00";
                    var m = Math.floor(sec / 60);
                    var s = Math.floor(sec % 60);
                    return m + ":" + (s < 10 ? "0" : "") + s;
                }
                
                var posText = formatTime(position);
                var remText = formatTime(Math.max(0, duration - position));
                
                return {
                    title: title,
                    artist: artist,
                    cover: cover,
                    isPlaying: isPlaying,
                    progress: progress,
                    positionText: posText || "0:00",
                    remainingText: remText || "0:00"
                };
            } catch (e) {
                return {
                    title: 'Ошибка JS: ' + e.toString(),
                    artist: '',
                    cover: '',
                    isPlaying: false,
                    progress: 0.0,
                    positionText: "0:00",
                    remainingText: "0:00"
                };
            }
        })();
        """
        
        webView?.evaluateJavaScript(js) { (result, error) in
            if let dict = result as? [String: Any] {
                DispatchQueue.main.async {
                    let newTitle = dict["title"] as? String ?? "Не играет"
                    let newArtist = dict["artist"] as? String ?? ""
                    let newCover = dict["cover"] as? String ?? ""
                    let newIsPlaying = dict["isPlaying"] as? Bool ?? false
                    let newProgress = dict["progress"] as? Double ?? 0.0
                    let newPosText = dict["positionText"] as? String ?? "0:00"
                    let newRemText = dict["remainingText"] as? String ?? "0:00"
                    
                    self.trackTitle = newTitle
                    self.artist = newArtist
                    self.isPlaying = newIsPlaying
                    self.progress = newProgress.isNaN ? 0.0 : newProgress
                    self.positionText = newPosText
                    self.remainingText = newRemText
                    
                    if newCover != "" && newCover != self.coverURL {
                        // Яндекс музыка часто дает обложки 50x50, меняем на 400x400 для виджета
                        self.coverURL = newCover.replacingOccurrences(of: "50x50", with: "400x400")
                    }
                }
            }
        }
    }
}

class BrowserWindowManager: NSObject, NSWindowDelegate {
    static let shared = BrowserWindowManager()
    var window: NSWindow?
    var webView: WKWebView?
    
    func setup() {
        if window == nil {
            let config = WKWebViewConfiguration()
            
            // ВАЖНО: Разрешаем воспроизведение медиа без прямого клика пользователя в WebView!
            // Без этого WebKit блокирует вызов media.play() из JavaScript.
            config.mediaTypesRequiringUserActionForPlayback = []
            
            let userScriptCode = """
            Object.defineProperty(window, 'innerWidth', { get: function() { return 1024; }, configurable: true });
            Object.defineProperty(window, 'innerHeight', { get: function() { return 768; }, configurable: true });
            Object.defineProperty(document.documentElement, 'clientWidth', { get: function() { return 1024; }, configurable: true });
            Object.defineProperty(document.documentElement, 'clientHeight', { get: function() { return 768; }, configurable: true });
            window.matchMedia = window.matchMedia || function() { return { matches: false, addListener: function() {}, removeListener: function() {} }; };
            """
            let userScript = WKUserScript(source: userScriptCode, injectionTime: .atDocumentStart, forMainFrameOnly: false)
            config.userContentController.addUserScript(userScript)
            
            webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: config)
            webView?.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
            
            WebViewModel.shared.webView = webView
            
            let request = URLRequest(url: URL(string: "https://music.yandex.ru")!)
            webView?.load(request)
            
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Яндекс Музыка"
            win.center()
            win.contentView = webView
            win.isReleasedWhenClosed = false
            win.delegate = self // ВАЖНО: перехватываем закрытие
            
            self.window = win
            
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                WebViewModel.shared.checkMetadata()
            }
        }
    }
    
    func show() {
        setup()
        window?.makeKeyAndOrderFront(nil)
    }

    // Этот метод вызывается, когда пользователь нажимает красный крестик
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        // Вместо реального закрытия (которое ломает WebKit) убираем окно с экрана:
        // WebView продолжает работать и играть, но окна нет в Mission Control и ⌘`
        sender.orderOut(nil)
        return false // Запрещаем реальное закрытие
    }
}

extension NSApplication {
    // Окно самого виджета (не окно плеера)
    var widgetWindow: NSWindow? {
        windows.first { $0.identifier?.rawValue == "widget" }
            ?? windows.first { $0 !== BrowserWindowManager.shared.window && $0.contentView != nil && !($0 is NSPanel) }
    }
}

