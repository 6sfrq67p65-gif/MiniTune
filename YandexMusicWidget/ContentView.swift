import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WebViewModel.shared
    @AppStorage("viewMode") private var viewMode = 0 // 0: vertical, 1: horizontal, 2: dock
    
    // Сохраненные размеры окон пользователем
    @AppStorage("horizontalWidth") private var horizontalWidth: Double = 420
    @AppStorage("horizontalHeight") private var horizontalHeight: Double = 200
    @AppStorage("verticalWidth") private var verticalWidth: Double = 250
    @AppStorage("verticalHeight") private var verticalHeight: Double = 460
    @AppStorage("dockWidth") private var dockWidth: Double = 400
    @AppStorage("dockHeight") private var dockHeight: Double = 60
    
    @State private var dragOffset: CGPoint? = nil
    @State private var seekPreview: Double? = nil
    
    var body: some View {
        ZStack {
            // Фон матовое стекло (с принудительным заполнением 100% пространства)
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
            
            // Основной интерфейс мини-плеера
            if viewMode == 0 {
                verticalBody
            } else if viewMode == 1 {
                horizontalBody
            } else {
                dockBody
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous)) // Скругляем углы как у системного Dock
        .ignoresSafeArea() // Игнорируем safe area, чтобы системный заголовок не смещал контент вниз
        .frame(maxWidth: .infinity, maxHeight: .infinity) // Динамическое заполнение всего окна Mac
        .gesture(
            DragGesture()
                .onChanged { _ in
                    if let window = NSApplication.shared.widgetWindow {
                        let mouseLoc = NSEvent.mouseLocation
                        if dragOffset == nil {
                            dragOffset = CGPoint(
                                x: window.frame.origin.x - mouseLoc.x,
                                y: window.frame.origin.y - mouseLoc.y
                            )
                        }
                        if let offset = dragOffset {
                            window.setFrameOrigin(CGPoint(x: mouseLoc.x + offset.x, y: mouseLoc.y + offset.y))
                        }
                    }
                }
                .onEnded { _ in
                    dragOffset = nil
                }
        )
        .onAppear {
            // При запуске приложения невидимо инициализируем браузер в фоне
            BrowserWindowManager.shared.setup()
            updateWindowSize(animated: false)
        }
        .onChange(of: viewMode) {
            updateWindowSize(animated: true)
        }
    }
    
    private func updateWindowSize(animated: Bool) {
        DispatchQueue.main.async {
            if let window = NSApplication.shared.widgetWindow {
                // Используем сохраненные пользователем размеры (с минимальными ограничениями)
                let vSize = NSSize(width: max(200, verticalWidth), height: max(440, verticalHeight))
                let hSize = NSSize(width: max(300, horizontalWidth), height: max(200, horizontalHeight))
                let dSize = NSSize(width: max(180, dockWidth), height: max(30, dockHeight))
                
                let newSize: NSSize
                let minSize: NSSize
                
                if viewMode == 0 {
                    newSize = vSize
                    minSize = NSSize(width: 200, height: 440)
                } else if viewMode == 1 {
                    newSize = hSize
                    minSize = NSSize(width: 300, height: 200)
                } else {
                    newSize = dSize
                    minSize = NSSize(width: 150, height: 15) // Позволяет делать dock супер узким
                }
                
                var frame = window.frame
                
                // Чтобы виджет не "улетал" при смене размера:
                // Если он находится в верхней половине экрана — фиксируем верхний край.
                // Если в нижней — фиксируем нижний край (стандартное поведение macOS).
                if let screen = window.screen, frame.origin.y > (screen.visibleFrame.height / 2) {
                    frame.origin.y += frame.size.height - newSize.height
                }
                
                frame.size = newSize
                
                // Устанавливаем минимальный размер окна, чтобы элементы не сжимались до ошибок
                window.minSize = minSize
                
                if animated {
                    window.setFrame(frame, display: true, animate: true)
                } else {
                    window.setFrame(frame, display: true)
                }
            }
        }
    }
    
    private var verticalBody: some View {
        VStack(spacing: 12) {
            // Обложка
            coverView(size: 200)
            
            // Название и артист
            VStack(spacing: 4) {
                Text(viewModel.trackTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(viewModel.artist.isEmpty ? " " : viewModel.artist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
            
            progressBar
                .padding(.horizontal, 20)

            // Кнопки управления
            HStack(spacing: 25) {
                playbackControls
            }
            
            Spacer(minLength: 0) // Толкает нижние кнопки вниз, а верхние элементы вверх
            
            // Нижняя панель кнопок
            HStack(spacing: 12) {
                powerButton
                browserButton
                layoutButton
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .padding(.top, 25)
    }
    
    private var horizontalBody: some View {
        HStack(spacing: 15) {
            // Обложка
            coverView(size: 140)
            
            VStack(alignment: .leading, spacing: 0) {
                // Название и артист
                Text(viewModel.trackTitle)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(viewModel.artist.isEmpty ? " " : viewModel.artist)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
                    .padding(.top, 2)

                Spacer()

                progressBar
                
                // Кнопки управления
                HStack(spacing: 25) {
                    playbackControls
                }
                .frame(maxWidth: .infinity, alignment: .center)
                
                Spacer()
                
                // Нижняя панель кнопок
                HStack(spacing: 12) {
                    powerButton
                    browserButton
                    layoutButton
                }
            }
            .padding(.vertical, 5)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    private var dockBody: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let isSuperSmall = h <= 25 // Если панель стала совсем узкой
            
            HStack(spacing: isSuperSmall ? 8 : 12) {
                if !isSuperSmall {
                    // Картинка масштабируется, но не больше 50
                    let coverSize = max(15, min(50, h - 10))
                    coverView(size: coverSize)
                        .padding(.leading, 10)
                } else {
                    Spacer().frame(width: 5)
                }
                
                VStack(alignment: .leading, spacing: isSuperSmall ? 0 : 2) {
                    // Название и артист
                    Text(viewModel.trackTitle)
                        .font(.system(size: isSuperSmall ? 10 : 13, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if !isSuperSmall || h > 18 { // Скрываем артиста если уж совсем в линию
                        Text(viewModel.artist.isEmpty ? " " : viewModel.artist)
                            .font(.system(size: isSuperSmall ? 9 : 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                .frame(width: isSuperSmall ? 140 : 120, alignment: .leading)
                
                Spacer(minLength: 0)
                
                // Кнопки управления плеером (масштабируются)
                HStack(spacing: isSuperSmall ? 10 : 15) {
                    Button(action: { viewModel.prevTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: isSuperSmall ? 10 : 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { viewModel.playPause() }) {
                        Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: isSuperSmall ? 14 : 26))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: { viewModel.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: isSuperSmall ? 10 : 14))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Разделитель
                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: isSuperSmall ? 15 : 30)
                    .padding(.horizontal, 5)
                
                // Правый блок системных кнопок
                if isSuperSmall {
                    // Если очень узко, выстраиваем в линию
                    HStack(spacing: 12) {
                        Button(action: { 
                            withAnimation { viewMode = (viewMode + 1) % 3 } 
                        }) {
                            Image(systemName: viewModeIcon)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { NSApplication.shared.terminate(nil) }) {
                            Image(systemName: "power")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 10)
                } else {
                    // Стандартный вертикальный столбик
                    VStack(spacing: 8) {
                        Button(action: { 
                            withAnimation { viewMode = (viewMode + 1) % 3 } 
                        }) {
                            Image(systemName: viewModeIcon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button(action: { NSApplication.shared.terminate(nil) }) {
                            Image(systemName: "power")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.red.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.trailing, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func coverView(size: CGFloat) -> some View {
        AsyncImage(url: URL(string: viewModel.coverURL)) { phase in
            if let image = phase.image {
                image.resizable()
                     .aspectRatio(contentMode: .fill)
            } else if phase.error != nil {
                Color.black.opacity(0.5)
            } else {
                Color.black.opacity(0.3)
            }
        }
        .frame(width: size, height: size)
        .cornerRadius(12)
        .shadow(radius: 5)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
    
    // Полоса прогресса: клик или перетаскивание перематывают трек
    private var progressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let shown = seekPreview ?? viewModel.progress
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule().fill(Color.white.opacity(0.85))
                        .frame(width: max(0, min(1, shown)) * geo.size.width)
                }
                .frame(height: 4)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in seekPreview = max(0, min(1, v.location.x / geo.size.width)) }
                        .onEnded { v in
                            viewModel.seek(to: max(0, min(1, v.location.x / geo.size.width)))
                            seekPreview = nil
                        }
                )
            }
            .frame(height: 12)

            HStack {
                Text(viewModel.positionText)
                Spacer()
                Text("-" + viewModel.remainingText)
            }
            .font(.system(size: 10, weight: .medium).monospacedDigit())
            .foregroundColor(.white.opacity(0.6))
        }
    }

    @ViewBuilder
    private var playbackControls: some View {
        Button(action: { viewModel.prevTrack() }) {
            Image(systemName: "backward.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
        
        Button(action: { viewModel.playPause() }) {
            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.system(size: 38))
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
        
        Button(action: { viewModel.nextTrack() }) {
            Image(systemName: "forward.fill")
                .font(.system(size: 18))
                .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var powerButton: some View {
        Button(action: { 
            NSApplication.shared.terminate(nil)
        }) {
            Image(systemName: "power")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var browserButton: some View {
        Button(action: { 
            BrowserWindowManager.shared.show()
        }) {
            HStack {
                Image(systemName: "safari.fill")
                Text("Открыть плеер")
                    .fontWeight(.medium)
            }
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.9))
            .frame(maxWidth: .infinity, minHeight: 36, maxHeight: 36)
            .background(Color.white.opacity(0.15))
            .cornerRadius(18)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var viewModeIcon: String {
        switch viewMode {
        case 0: return "rectangle"
        case 1: return "menubar.dock.rectangle"
        default: return "rectangle.portrait"
        }
    }
    
    private var layoutButton: some View {
        Button(action: { 
            withAnimation {
                viewMode = (viewMode + 1) % 3
            }
        }) {
            Image(systemName: viewModeIcon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Вспомогательная View для эффекта размытия (Vibrancy) в macOS
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}
