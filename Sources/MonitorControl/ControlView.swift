import SwiftUI

struct ControlView: View {
    @ObservedObject var manager: MonitorManager
    @ObservedObject var presetManager: PresetManager
    
    @State private var showDashboard = false
    @State private var currentPresetName: String = ""
    
    var body: some View {
        ZStack {
            // Background Visuals
            GlassEffect(material: .hudWindow, blendingMode: .behindWindow)
                .edgesIgnoringSafeArea(.all)
            
            if showDashboard {
                DashboardView(presetManager: presetManager, monitorManager: manager, onDismiss: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showDashboard = false
                    }
                }, onSelectPreset: { preset in
                    currentPresetName = preset.name
                })
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing),
                    removal: .move(edge: .trailing)
                ))
                .zIndex(1) // Ensure Dashboard is on top during transition
            } else {
                VStack(spacing: 20) {
                    // Header
                    HStack {
                        Text("LumiNative")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                        
                        
                        Spacer()
                        
                        // Dashboard Toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showDashboard.toggle()
                            }
                        }) {
                            Image(systemName: "square.grid.2x2.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal)
                    .padding(.top, 20)
                    
                    // Monitor List
                    ScrollView {
                        VStack(spacing: 16) {
                            if manager.monitors.isEmpty {
                                Text("No monitors detected")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach($manager.monitors) { $monitor in
                                    MonitorSliderRow(monitor: $monitor) { val, smooth in
                                        manager.setBrightness(for: monitor.id, value: val, smooth: smooth)
                                        currentPresetName = "Custom" // Reset name if manually changed
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10) // Extra padding for scrolling
                    }

                    .frame(maxHeight: 400) // Ensure max height
                    
                    // V2.26: Refined Cycle Button (Subtle & Relevant)
                    Button(action: cycleFavorites) {
                        HStack {
                            Image(systemName: "rectangle.stack.fill") // Relevant: "Stack of Presets"
                                .font(.system(size: 16, weight: .semibold))
                            Text("Next Favorite Preset")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        
                        // Subtle, premium appearance (Glassmorphic)
                        .background(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(12)
                        .foregroundColor(.white.opacity(0.9)) // Softer white
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                    .help("Cycle through unlimited favorite presets")
                    
                    Spacer()
                    
                    // Footer
                    Divider()
                        .background(Color.white.opacity(0.2))
                    
                    HStack {
                        // Current Preset Info
                        if !currentPresetName.isEmpty && currentPresetName != "Custom" {
                            Image(systemName: "slider.horizontal.3")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(currentPresetName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Quit") {
                            NSApplication.shared.terminate(nil)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 15)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .leading),
                    removal: .move(edge: .leading)
                ))
            }
        }
        .frame(width: 340)
        .frame(minHeight: showDashboard ? 480 : 250) // Adjust height dynamically to match DashboardView
    }

    private func cycleFavorites() {
        let favorites = presetManager.presets.filter { $0.isFavorite }
        
        // Ensure we have favorites to cycle
        guard !favorites.isEmpty else {
            print("No favorites found.")
            return
        }
        
        // Robust cycling logic:
        // 1. Find current index provided name matches exactly.
        // 2. If 'Night' (last item) is selected, currentIndex is last index.
        // 3. (last + 1) % count SHOULD be 0.
        
        var nextIndex = 0
        if let currentIndex = favorites.firstIndex(where: { $0.name == currentPresetName }) {
            nextIndex = (currentIndex + 1) % favorites.count
        } else {
            // Check if we are "Custom" or "Unknown". Start with first favorite.
            nextIndex = 0
        }
        
        // Safety check
        if nextIndex >= 0 && nextIndex < favorites.count {
            let nextPreset = favorites[nextIndex]
            print("Cycling to: \(nextPreset.name)")
            applyPreset(nextPreset)
        }
    }
    
    private func applyPreset(_ preset: Preset) {
        currentPresetName = preset.name
        // Apply to all monitors
        for monitor in manager.monitors {
            if monitor.isBuiltIn {
                manager.setBrightness(for: monitor.id, value: preset.internalBrightness, smooth: true)
            } else {
                manager.setBrightness(for: monitor.id, value: preset.externalBrightness, smooth: true)
            }
        }
    }
}

struct MonitorSliderRow: View {
    @Binding var monitor: MonitorManager.Monitor
    var onChange: (Float, Bool) -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            // Label Row
            HStack {
                Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
                
                Text(monitor.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
                
                Spacer()
                
                Text("\(Int(monitor.brightness * 100))%")
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Custom Slider
            LiquidSlider(value: $monitor.brightness, onChange: onChange)
        }
        .padding(12)
        .background(Color.black.opacity(0.2))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

struct LiquidSlider: View {
    @Binding var value: Float
    var onChange: (Float, Bool) -> Void // Value, Smooth
    
    @State private var isDragging = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 8)
                
                // Fill
                Capsule()
                    .fill(
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)]), startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: CGFloat(value) * geometry.size.width, height: 8)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let newValue = min(max(0, Float(gesture.location.x / geometry.size.width)), 1)
                        
                        // Determine interaction type
                        var shouldSmooth = false
                        
                        if !isDragging {
                            // Start of gesture
                            isDragging = true
                            let delta = abs(newValue - value)
                            // If jump is > 5%, treat as a Click/Tap (Smooth)
                            // If jump is small, it's likely a drag start (Instant)
                            if delta > 0.05 {
                                shouldSmooth = true
                            }
                        } else {
                            // Continuing drag -> Always instant
                            shouldSmooth = false
                        }
                        
                        value = newValue
                        onChange(newValue, shouldSmooth)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: 20) // Taller touch area for better usability
    }
}

