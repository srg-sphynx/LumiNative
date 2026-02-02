import Foundation
import Combine

struct Preset: Identifiable, Codable {
    var id = UUID()
    var name: String
    var internalBrightness: Float
    var externalBrightness: Float
    var icon: String // SF Symbol name
    var isDefault: Bool = false
    var isFavorite: Bool = false
}

class PresetManager: ObservableObject {
    @Published var presets: [Preset] = []
    
    private let defaultsKey = "savedPresets"
    
    init() {
        loadPresets()
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: defaultsKey)
        }
    }
    
    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded
        } else {
            // Default Presets
            presets = [
                Preset(name: "Standard", internalBrightness: 0.5, externalBrightness: 0.5, icon: "sun.max.fill", isDefault: true, isFavorite: true),
                Preset(name: "Movie", internalBrightness: 0.2, externalBrightness: 0.3, icon: "popcorn.fill", isDefault: true, isFavorite: true),
                Preset(name: "Gaming", internalBrightness: 0.8, externalBrightness: 1.0, icon: "gamecontroller.fill", isDefault: true, isFavorite: false),
                Preset(name: "Night", internalBrightness: 0.05, externalBrightness: 0.1, icon: "moon.stars.fill", isDefault: true, isFavorite: true)
            ]
        }
    }
    
    func addPreset(name: String, internalVal: Float, externalVal: Float, icon: String = "star") {
        let newPreset = Preset(name: name, internalBrightness: internalVal, externalBrightness: externalVal, icon: icon, isDefault: false, isFavorite: true) // New User Presets are Favorites by default
        presets.append(newPreset)
        savePresets()
    }
    
    func updatePreset(_ updatedPreset: Preset) {
        if let index = presets.firstIndex(where: { $0.id == updatedPreset.id }) {
            presets[index] = updatedPreset
            savePresets()
        }
    }
    
    func removePreset(at offsets: IndexSet) {
        presets.remove(atOffsets: offsets)
        savePresets()
    }
}
