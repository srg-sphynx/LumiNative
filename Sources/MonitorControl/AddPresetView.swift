import SwiftUI

struct AddPresetView: View {
    @Binding var isPresented: Bool
    @Binding var presetToEdit: Preset? // Optional: If set, we are editing
    
    @ObservedObject var presetManager: PresetManager
    @ObservedObject var monitorManager: MonitorManager
    
    @State private var name: String = ""
    @State private var selectedIcon: String = "star"
    @State private var internalBrightness: Float = 0.5
    @State private var externalBrightness: Float = 0.5
    
    // Curated Icons
    let icons = ["sun.max", "moon.fill", "gamecontroller.fill", "tv.fill", "book.fill", "leaf.fill", "bolt.fill", "flame.fill", "desktopcomputer", "laptopcomputer", "star.fill", "heart.fill"]
    
    var isDuplicateName: Bool {
        // Validation: Check if name exists AND we are not editing THAT preset
        if let existing = presetManager.presets.first(where: { $0.name.lowercased() == name.lowercased() }) {
            // If editing, ignore self
            if let edit = presetToEdit, edit.id == existing.id {
                return false
            }
            return true
        }
        return false
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text(presetToEdit == nil ? "New Preset" : "Edit Preset")
                .font(.headline)
                .foregroundColor(.white)
            
            // Scrollable Content
            ScrollView {
                VStack(spacing: 20) {
                    // Name Input
                    TextField("Preset Name", text: $name)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                        .foregroundColor(.white)
                    
                    if isDuplicateName {
                        Text("Name already exists")
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    // Brightness Sliders (Live Preview)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Target Brightness")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // Adaptive UI: Only show Internal if present (Clamshell Mode Support)
                        if monitorManager.monitors.contains(where: { $0.isBuiltIn }) {
                            HStack {
                                Image(systemName: "laptopcomputer")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                LiquidSlider(value: $internalBrightness, onChange: { val, smooth in
                                    // NO-OP: Live Preview Disabled by User Request (V2.20)
                                    // User wants to set value without changing screen until "Saved" and "Applied".
                                })
                                .frame(height: 12)
                                Text("\(Int(internalBrightness * 100))%")
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .frame(width: 30)
                            }
                        }
                        
                        // Adaptive UI: Only show External if present
                        if monitorManager.monitors.contains(where: { !$0.isBuiltIn }) {
                            HStack {
                                Image(systemName: "display")
                                    .foregroundColor(.secondary)
                                    .frame(width: 20)
                                LiquidSlider(value: $externalBrightness, onChange: { val, smooth in
                                     // NO-OP: Live Preview Disabled
                                })
                                .frame(height: 12)
                                Text("\(Int(externalBrightness * 100))%")
                                    .font(.caption2)
                                    .monospacedDigit()
                                    .frame(width: 30)
                            }
                        }
                        
                        // Fallback Text if NO monitors detected (shouldn't happen)
                        if monitorManager.monitors.isEmpty {
                            Text("No displays detected")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding(.vertical, 5)
                    
                    // Icon Picker
                    VStack(alignment: .leading) {
                        Text("Icon")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 36))], spacing: 8) {
                            ForEach(icons, id: \.self) { icon in
                                Button(action: { selectedIcon = icon }) {
                                    Image(systemName: icon)
                                        .font(.headline)
                                        .frame(width: 36, height: 36)
                                        .background(selectedIcon == icon ? Color.blue : Color.white.opacity(0.1))
                                        .foregroundColor(selectedIcon == icon ? .white : .white.opacity(0.7))
                                        .cornerRadius(8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                }
                .padding(.horizontal, 4) // Slight padding for scroll bar space
            }
            .frame(maxHeight: 280) // Limit scroll area height to ensure fit
            
            // Pinned Footer Actions
            HStack(spacing: 16) {
                Button("Cancel") {
                    withAnimation { isPresented = false }
                }
                .foregroundColor(.secondary)
                
                Button("Save") {
                    savePreset()
                }
                .disabled(name.isEmpty || isDuplicateName)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background((name.isEmpty || isDuplicateName) ? Color.gray : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding(.top, 10)
        }
        .padding()
        .frame(width: 320)
        .glassBackground(material: .hudWindow)
        .onAppear {
            if let edit = presetToEdit {
                // Load existing values
                name = edit.name
                selectedIcon = edit.icon
                internalBrightness = edit.internalBrightness
                externalBrightness = edit.externalBrightness
            } else {
                // Initialize with current values (New Preset)
                if let builtin = monitorManager.monitors.first(where: { $0.isBuiltIn }) {
                    internalBrightness = builtin.brightness
                }
                if let external = monitorManager.monitors.first(where: { !$0.isBuiltIn }) {
                    externalBrightness = external.brightness
                }
            }
        }
    }
    
    private func savePreset() {
        if var edit = presetToEdit {
            // Update Existing
            edit.name = name
            edit.internalBrightness = internalBrightness
            edit.externalBrightness = externalBrightness
            edit.icon = selectedIcon
            presetManager.updatePreset(edit)
        } else {
            // Create New
            presetManager.addPreset(name: name, internalVal: internalBrightness, externalVal: externalBrightness, icon: selectedIcon)
        }
        
        withAnimation {
            isPresented = false
            presetToEdit = nil // cleanup
        }
    }
}
