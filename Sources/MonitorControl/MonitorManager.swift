import Foundation
import Combine
import PrivateDDC
import IOKit
import CoreGraphics
import AppKit

class MonitorManager: ObservableObject {
    struct Monitor: Identifiable {
        let id: UInt32 // CGDirectDisplayID
        let name: String
        var brightness: Float // 0.0 to 1.0
        let isBuiltIn: Bool
    }

    @Published var monitors: [Monitor] = []
    
    // Key Interceptor REMOVED in V2.22 (Cleanup)
    // private let keyInterceptor = KeyInterceptor()
    // private var isClamshellMode = false
    
    private let ddcQueue = DispatchQueue(label: "com.monitorcontrol.ddc") // Serial queue for ordered commands
    private var brightnessSubject = PassthroughSubject<(UInt32, Float), Never>()
    private var cancellables = Set<AnyCancellable>()
    
    // We'll keep a mapping of DisplayID to I2C/Service handles
    
    init() {
        // Debounce brightness updates to avoid crashing sensitive monitors (Samsung)
        // Moderate Mode: 200ms debounce (Responsive but safe)
        brightnessSubject
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main) 
            .sink { [weak self] (monitorID, value) in
                self?.performBrightnessUpdate(for: monitorID, value: value)
            }
            .store(in: &cancellables)

        // Key Interceptor Logic Removed (V2.22)
        
        // Listen for Resetting Displays (Lid Close/Open, Plug/Unplug)
        CGDisplayRegisterReconfigurationCallback({ (displayId, flags, userInfo) in
            guard let userInfo = userInfo else { return }
            let this = Unmanaged<MonitorManager>.fromOpaque(userInfo).takeUnretainedValue()
            // We only care about configuration changes, not just flag changes
            if flags.contains(.addFlag) || flags.contains(.removeFlag) || flags.contains(.enabledFlag) || flags.contains(.disabledFlag) {
                // Debounce slighty to avoid multiple calls during wake
                 DispatchQueue.main.async {
                     this.refreshMonitors()
                 }
            }
        }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
        
        refreshMonitors()
    }
    
    deinit {
        CGDisplayRemoveReconfigurationCallback({ _, _, _ in }, UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()))
    }
    
    func refreshMonitors() {
        // Only detect on demand, do not poll automatically
        print("Refreshing monitors...")
        
        // Pass completion handler to ensure sync runs AFTER monitors are populated (Fix V2.16 Race Condition)
        detectDisplays { [weak self] in
            guard let self = self else { return }
            
            // 1. Immediate Sync (Fast Wake)
            print("Display Detection Complete. Triggering Immediate Sync.")
            self.syncBrightness()
            
            // 2. Delayed Sync (Slow Wake / Double-Tap)
            // Some monitors (like Dell/LG) take 1-2s to accept DDC after wake.
            print("Scheduling Robust Sync (Double-Tap) in 2.0s...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                print("Executing Robust Sync...")
                self?.syncBrightness()
            }
        }
    }
    
    private var displayServices: [UInt32: IOAVService] = [:]

    private func detectDisplays(completion: @escaping () -> Void) {
        // Use CoreGraphics to get display IDs
        var displayCount: UInt32 = 0
        var activeDisplays = [CGDirectDisplayID](repeating: 0, count: 16)
        
        guard CGGetActiveDisplayList(UInt32(activeDisplays.count), &activeDisplays, &displayCount) == .success else {
            print("Failed to get active displays")
            completion()
            return
        }
        
        let displayIDs = Array(activeDisplays.prefix(Int(displayCount)))
        
        // This matching call might be slow, but it's synchronous here? 
        // AppleSiliconDDC.getServiceMatches uses IORegistry iteration, which is generally fast but blocking.
        // We should dispatch this whole heavy lifting to background to avoid blocking Main Thread,
        // then update UI on Main.
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let matches = AppleSiliconDDC.getServiceMatches(displayIDs: displayIDs)
            
            var detectedMonitors: [Monitor] = []
            
            for displayID in displayIDs {
                var monitorName = "Display \(displayID)"
                var currentBrightness: Float = 0.5
                var isBuiltIn = DisplayServices.isBuiltInDisplay(displayID)
                
                // 1. Try to find DDC match for External
                if let match = matches.first(where: { $0.displayID == displayID }) {
                    if let service = match.service {
                        DispatchQueue.main.async {
                            self.displayServices[displayID] = service
                        }
                        monitorName = match.serviceDetails.productName.isEmpty ? monitorName : match.serviceDetails.productName
                        isBuiltIn = false // DDC displays are external
                    }
                }
                
                // 2. Handle Built-in Display (Private API)
                if isBuiltIn {
                    monitorName = "Built-in Display"
                    currentBrightness = Float(DisplayServices.getBrightness(for: displayID))
                } else {
                     // Load LAST KNOWN brightness for External
                    let defaultsKey = "brightness-v2-\(displayID)"
                    if let val = UserDefaults.standard.object(forKey: defaultsKey) as? Float {
                        currentBrightness = val
                    }
                }
                
                detectedMonitors.append(Monitor(id: displayID, name: monitorName, brightness: currentBrightness, isBuiltIn: isBuiltIn))
            }
            
            DispatchQueue.main.async {
                self.monitors = detectedMonitors
                completion()
            }
        }
    }
    
    // MARK: - Synchronization (Two-Way Sync)
    func syncBrightness() {
        print("Syncing brightness from hardware...")
        
        for index in monitors.indices {
            let monitor = monitors[index]
            var actualBrightness: Float?
            
            // 1. Internal Display
            if monitor.isBuiltIn {
                actualBrightness = Float(DisplayServices.getBrightness(for: monitor.id))
            }
            // 2. External Display
            else if let service = displayServices[monitor.id] {
                // Read DDC (0x10 is Luminance)
                // Note: Reading DDC can be slow (40-100ms per display)
                if let values = AppleSiliconDDC.read(service: service, command: 0x10) {
                    let current = Float(values.current)
                    let max = Float(values.max)
                    
                    // Normalize (10-60 DDC scale to 0.0-1.0)
                    // We used minDDC=10, maxDDC=60 in performBrightnessUpdate
                    // Inverse: value = (ddc - 10) / (60 - 10)
                    // Ideally we should read the REAL Max from DDC, but we clamped our writes.
                    // If the monitor returns 0-100, we should probably respect that?
                    // Let's use the DDC 'max' returned by the display for now, or match our calibration?
                    // User complained about "state changed on hardware", so we should respect what the display says.
                    if max > 0 {
                        actualBrightness = current / max
                    }
                }
            }
            
            // Update Local State (Main Thread)
            if let newValue = actualBrightness {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    // Update cache immediately to prevent next ramp starting from stale value
                    self.lastKnownBrightness[monitor.id] = newValue
                    
                    // Only update if significantly different to avoid jitter
                    if abs(self.monitors[index].brightness - newValue) > 0.01 {
                        print("Sync: Updated \(monitor.name) to \(newValue)")
                        self.monitors[index].brightness = newValue
                        // Persist
                        let defaultsKey = "brightness-v2-\(monitor.id)"
                        UserDefaults.standard.set(newValue, forKey: defaultsKey)
                    }
                }
            }
        }
    }
    
    // MARK: - Sync Feature (V3)
    func syncExternalToInternal() {
        print("Syncing External Monitors to Internal Display Brightness...")
        
        // 1. Find Internal Display Brightness
        // We use the last known brightness or fetch it fresh
        guard let internalMonitor = monitors.first(where: { $0.isBuiltIn }) else {
            print("No internal display found to sync from.")
            return
        }
        
        // Get fresh value just in case
        let internalBrightness = Float(DisplayServices.getBrightness(for: internalMonitor.id))
        print("Internal Brightness: \(internalBrightness)")
        
        // 2. Apply to External Displays
        for monitor in monitors where !monitor.isBuiltIn {
            print("Syncing \(monitor.name) to \(internalBrightness)")
            setBrightness(for: monitor.id, value: internalBrightness, smooth: true)
        }
    }
    func setBrightness(for monitorID: UInt32, value: Float, smooth: Bool = false) {
        // Update local state immediately for UI responsiveness
        if let index = monitors.firstIndex(where: { $0.id == monitorID }) {
            // If smoothing, we don't jump the local state immediately unless it's a slider
            // But for UI feedback, we often want instant reflection.
            // Let's rely on the ramp to update the actual hardware.
            monitors[index].brightness = value
        }
        
        // Persist locally
        let defaultsKey = "brightness-v2-\(monitorID)"
        UserDefaults.standard.set(value, forKey: defaultsKey)
        
        if smooth {
            rampBrightness(for: monitorID, to: value)
        } else {
            // Cancel any ongoing ramp
            transitionTimers[monitorID]?.invalidate()
            transitionTimers[monitorID] = nil
            
            // Fix V2.10: Internal Display Slider Responsiveness
            // Bypass debounce for Internal Display to ensure 120Hz/60Hz fluid slider dragging
            // External displays still need debounce to prevent DDC choking
            let isBuiltIn = monitors.first(where: { $0.id == monitorID })?.isBuiltIn ?? false
            
            if isBuiltIn {
                 performBrightnessUpdate(for: monitorID, value: value)
            } else {
                 // Send to debouncer (External)
                 brightnessSubject.send((monitorID, value))
            }
        }
    }
    
    // MARK: - Smooth Transition Logic
    private var transitionTimers: [UInt32: Timer] = [:]
    private var lastKnownBrightness: [UInt32: Float] = [:] // Cache to avoid hardware read glitches
    
    // MARK: - ProMotion / High-Res Animation Logic
    // We use a recursive Dispatch loop or DispatchSourceTimer for better control than Timer
    // For 120Hz, we need ~8ms precision. Standard Timer is often 10-16ms tolerance.
    
    private func rampBrightness(for monitorID: UInt32, to targetValue: Float, duration: TimeInterval = 0.35) {
        // 1. Determine Start Value using Cache
        var startValue: Float = 0.5
        var isBuiltIn = false
        
        if let last = lastKnownBrightness[monitorID] {
             startValue = last
        } else if let monitor = monitors.first(where: { $0.id == monitorID }) {
            // If cache is empty, we trust the model BUT we check if it's 0.0 (uninitialized potentially?)
            // If it's 0.0, we might want to read hardware, but that's slow.
            // Let's stick to the model, but if it is vastly different from target, the user will see a jump.
            // The syncBrightness call on startup should minimize this.
            startValue = monitor.brightness
        }
        
        isBuiltIn = DisplayServices.isBuiltInDisplay(monitorID)
        
        if abs(startValue - targetValue) < 0.01 { return }
        
        // Cancel existing
        transitionTimers[monitorID]?.invalidate()
        transitionTimers[monitorID] = nil
        
        // 2. High Refresh Rate Configuration
        // Internal: 120Hz (ProMotion) - 8.3ms
        // External: 30Hz (Safe DDC) - 33ms
        let targetFPS: Double = isBuiltIn ? 120.0 : 30.0
        let interval = 1.0 / targetFPS
        
        let startTime = Date()
        let totalDuration = duration
        
        // We use a repeating Timer with high tolerance setting?
        // Actually, for smoothness on ProMotion, we should use a "Tick" approach based on elapsed time
        // rather than fixed steps. This handles frame drops gracefully.
        
        transitionTimers[monitorID] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            
            let now = Date()
            let elapsed = now.timeIntervalSince(startTime)
            var progress = Float(elapsed / totalDuration)
            
            if progress >= 1.0 {
                progress = 1.0
            }
            
            var interpolatedValue: Float = targetValue
            
            if isBuiltIn {
                // Quadratic Ease Out: f(t) = t * (2 - t)
                let t = progress
                let easedT = t * (2 - t)
                interpolatedValue = startValue + (targetValue - startValue) * easedT
            } else {
                // Linear
                interpolatedValue = startValue + (targetValue - startValue) * progress
            }
            
            self.performBrightnessUpdate(for: monitorID, value: interpolatedValue)
            
            if progress >= 1.0 {
                timer.invalidate()
                self.transitionTimers[monitorID] = nil
            }
        }
        
        // Note: Ideally we would use CVDisplayLink for true 120Hz, 
        // but Timer on Main Thread in simple apps usually gets boosted by macOS to match vsync 
        // if not blocked. This "Time-Delta" approach is robust against jitter.
    }
    
    private func performBrightnessUpdate(for monitorID: UInt32, value: Float) {
        // Cache the value we are about to set (Logical State)
        lastKnownBrightness[monitorID] = value
        
        // Check if Built-in
        if DisplayServices.isBuiltInDisplay(monitorID) {
            DisplayServices.setBrightness(for: monitorID, value: Double(value))
            return
        }
    
        guard let service = displayServices[monitorID] else {
            print("No service found for display \(monitorID)")
            return
        }
        
        // Move to SERIAL background thread to avoid race conditions
        ddcQueue.async {
            // Calibrated Scale: Map 0.0-1.0 to DDC 10-60
            // This removes dead zones at bottom (<10) and top (>60)
            let minDDC: Float = 10.0
            let maxDDC: Float = 60.0
            
            let scaledValue = minDDC + (value * (maxDDC - minDDC))
            let targetValue = UInt16(scaledValue)
            
            print("Setting brightness to \(targetValue) (Scaled 10-60) for display \(monitorID) (Moderate Mode: Serial, 20ms delay, 1 cycle)")
            
            // Moderate Mode Parameters:
            // writeSleepTime: 20000 (20ms) - Standard safety
            // numOfWriteCycles: 1 - Single write to avoid overwhelming controller
            let success = AppleSiliconDDC.write(service: service, 
                                                command: 0x10, 
                                                value: targetValue, 
                                                writeSleepTime: 20000,
                                                numOfWriteCycles: 1)
            
            if success {
               // Success
            } else {
                print("Failed to set brightness for display \(monitorID)")
            }
        }
    }
}
