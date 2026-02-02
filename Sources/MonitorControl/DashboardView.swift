import SwiftUI


struct DashboardView: View {
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var monitorManager: MonitorManager
    var onDismiss: () -> Void
    var onSelectPreset: (Preset) -> Void // Callback to notify parent
    
    @State private var showAddPreset = false
    @State private var isEditing = false
    @State private var presetToEdit: Preset? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.elementSpacing) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.primaryText)
                        .padding(8)
                        .background(Theme.controlBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                
                Text("Dashboard")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.primaryText)
                
                Spacer()
                
                // Sync Button (Only if we have both Internal AND External monitors)
                if monitorManager.monitors.contains(where: { $0.isBuiltIn }) && monitorManager.monitors.contains(where: { !$0.isBuiltIn }) {
                    Button(action: {
                        monitorManager.syncExternalToInternal()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                            Text("Sync")
                        }
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.accentColor.opacity(0.8)) // Vibrant blue for action
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Theme.accentColor.opacity(0.4), radius: 5, x: 0, y: 0)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .help("Sync external monitors to internal display brightness")
                }
                
                Button(action: {
                    withAnimation { isEditing.toggle() }
                }) {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isEditing ? Theme.accentColor : Theme.controlBackground)
                        .foregroundColor(isEditing ? .white : Theme.primaryText)
                        .cornerRadius(12)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top, 24) // Increased padding to clear rounded corners
            .padding(.bottom, 5)
            
            if showAddPreset {
                AddPresetView(isPresented: $showAddPreset, presetToEdit: $presetToEdit, presetManager: presetManager, monitorManager: monitorManager)
                    .transition(.move(edge: .bottom))
            } else {
                // Presets Grid
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // Section Header
                        Text("Presets")
                            .font(.headline)
                            .foregroundColor(Theme.secondaryText)
                            .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(presetManager.presets) { preset in
                                PresetButton(
                                    preset: preset, 
                                    isEditing: isEditing,
                                    showInternal: monitorManager.monitors.contains { $0.isBuiltIn },
                                    showExternal: monitorManager.monitors.contains { !$0.isBuiltIn },
                                    onDelete: {
                                    if !preset.isDefault, let index = presetManager.presets.firstIndex(where: { $0.id == preset.id }) {
                                        presetManager.removePreset(at: IndexSet(integer: index))
                                    }
                                },
                                    onToggleFavorite: {
                                        var updated = preset
                                        updated.isFavorite.toggle()
                                        presetManager.updatePreset(updated)
                                    }) {
                                    if isEditing && !preset.isDefault {
                                        presetToEdit = preset
                                        withAnimation { showAddPreset = true }
                                    } else {
                                        applyPreset(preset)
                                        onSelectPreset(preset)
                                    }
                                }
                            }
                            
                            // Add "New Preset" Button
                            if !isEditing {
                                Button(action: {
                                    withAnimation { showAddPreset = true }
                                }) {
                                    VStack {
                                        Image(systemName: "plus")
                                            .font(.title2)
                                            .foregroundColor(Theme.accentColor)
                                        Text("New Preset")
                                            .font(.caption)
                                            .foregroundColor(Theme.secondaryText)
                                    }
                                    .frame(height: 80)
                                    .frame(maxWidth: .infinity)
                                    .glassElement()
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 4)
                        
                        // Settings / Info
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About")
                                .font(.headline)
                                .foregroundColor(Theme.secondaryText)
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("MonitorControl V3")
                                        .font(.subheadline)
                                        .fontWeight(.bold)
                                    Text("Liquid Glass Edition")
                                        .font(.caption2)
                                        .foregroundColor(Theme.accentColor)
                                }
                                Spacer()
                                // Apple Silicon M4 Pro Icon Representation
                                HStack(spacing: 4) {
                                    Image(systemName: "apple.logo")
                                    Text("M4 Pro")
                                        .font(.custom("Menlo", size: 10))
                                        .fontWeight(.bold)
                                }
                                .padding(6)
                                .background(Color.black.opacity(0.5)) // Processor-like look
                                .foregroundColor(.white)
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray.opacity(0.5), lineWidth: 1)
                                )
                            }
                            
                            HStack(alignment: .top) {
                                Image(systemName: "cpu")
                                    .foregroundColor(.secondary)
                                Text("Made of Apple Silicon by Saketa Reddy")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            
                            // Feature badges
                            HStack(spacing: 8) {
                                Label("Sync Ready", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(16)
                        .background(Theme.controlBackground)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .padding(.vertical, 0) // Remove default padding as we handle it in layout
        .frame(width: 340, height: 480) // Slightly taller/wider for modern feel
        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius)) // Ensure content doesn't bleed out
        .liquidGlassBackground()
    }
    
    private func applyPreset(_ preset: Preset) {
        // Apply to all monitors
        for monitor in monitorManager.monitors {
            if monitor.isBuiltIn {
                monitorManager.setBrightness(for: monitor.id, value: preset.internalBrightness, smooth: true)
            } else {
                monitorManager.setBrightness(for: monitor.id, value: preset.externalBrightness, smooth: true)
            }
        }
    }
}

struct PresetButton: View {
    let preset: Preset
    let isEditing: Bool
    let showInternal: Bool
    let showExternal: Bool
    let onDelete: () -> Void
    let onToggleFavorite: () -> Void
    let action: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: preset.icon)
                        .font(.title2)
                    
                    HStack(spacing: 4) {
                        Text(preset.name)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        if preset.isFavorite {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        if showInternal {
                            Text("Int: \(Int(preset.internalBrightness * 100))%")
                        }
                        if showExternal {
                            Text("Ext: \(Int(preset.externalBrightness * 100))%")
                        }
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                }
                .frame(height: 80)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(isEditing)
            .opacity(isEditing ? 0.6 : 1.0)
            
            if isEditing {
                // Delete Button
                if !preset.isDefault {
                    Button(action: onDelete) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .background(Color.white.clipShape(Circle()))
                    }
                    .offset(x: 5, y: -5)
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Favorite Toggle (Bottom Right)
                Button(action: onToggleFavorite) {
                    Image(systemName: preset.isFavorite ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                        .background(Color.white.opacity(0.2).clipShape(Circle()))
                }
                .offset(x: 5, y: 50) // Bottom Right Corner roughly
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}
