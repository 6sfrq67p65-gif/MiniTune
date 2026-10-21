import SwiftUI

@main
struct YandexMusicWidgetApp: App {
    // Подключаем AppDelegate для настройки плавающего окна
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // Window, а не WindowGroup: виджет один, ⌘N не открывает второй
        Window("Яндекс Музыка", id: "widget") {
            ContentView()
                .edgesIgnoringSafeArea(.all) // Заполняем фон целиком, чтобы не было прозрачной полосы
        }
        .windowStyle(HiddenTitleBarWindowStyle())
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Настраиваем основное окно, чтобы оно было похоже на виджет
        if let window = NSApplication.shared.widgetWindow {
            window.identifier = NSUserInterfaceItemIdentifier("widget")
            // Полностью убираем системный заголовок (это отключает защиту от перекрытия Dock'а)
            window.styleMask.remove(.titled)
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.standardWindowButton(.zoomButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.closeButton)?.isHidden = true
            
            // Делаем окно "плавающим" поверх остальных, включая Dock
            window.level = .statusBar
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            
            // Делаем фон прозрачным для эффекта стекла
            window.backgroundColor = .clear
            window.isOpaque = false
            window.hasShadow = true
            
            // Разрешаем изменять размер (перемещение сделаем кастомным для обхода лимитов)
            window.styleMask.insert(.resizable)
            window.isMovableByWindowBackground = false
            
            // Убираем стандартный серый фон
            window.contentView?.wantsLayer = true
            window.contentView?.layer?.backgroundColor = NSColor.clear.cgColor
            // Отслеживаем изменение размера пользователем и сохраняем
            NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { _ in
                let size = window.frame.size
                let viewMode = UserDefaults.standard.integer(forKey: "viewMode")
                
                if viewMode == 0 { // vertical
                    UserDefaults.standard.set(Double(size.width), forKey: "verticalWidth")
                    UserDefaults.standard.set(Double(size.height), forKey: "verticalHeight")
                } else if viewMode == 1 { // horizontal
                    UserDefaults.standard.set(Double(size.width), forKey: "horizontalWidth")
                    UserDefaults.standard.set(Double(size.height), forKey: "horizontalHeight")
                } else if viewMode == 2 { // dock
                    UserDefaults.standard.set(Double(size.width), forKey: "dockWidth")
                    UserDefaults.standard.set(Double(size.height), forKey: "dockHeight")
                }
            }
        }
    }
}
