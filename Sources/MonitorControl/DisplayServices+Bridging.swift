import Foundation
import IOKit
import CoreGraphics

// Unified Brightness Control (IOKit + CoreDisplay)
struct DisplayServices {
    
    // DisplayServices (Best for M1/M2)
    private static var _setBrightness: (@convention(c) (CGDirectDisplayID, Float) -> Int32)?
    private static var _getBrightness: (@convention(c) (CGDirectDisplayID) -> Float)?

    // CoreDisplay (Safe Fallback)
    private static var _setBrightnessCD: (@convention(c) (CGDirectDisplayID, Double) -> Void)?
    private static var _getBrightnessCD: (@convention(c) (CGDirectDisplayID) -> Double)?
    private static var isCoreDisplayLoaded = false
    
    static func initialize() {
        guard !isCoreDisplayLoaded else { return }
        
        // 1. Load CoreBrightness (Critical Dependency to prevent Segfault)
        let cbPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/Current/CoreBrightness"
        _ = dlopen(cbPath, RTLD_LAZY)
        
        // 2. Load DisplayServices (Private Framework)
        let dsPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/Versions/Current/DisplayServices"
        if let dsHandle = dlopen(dsPath, RTLD_LAZY) {
             // Load SetBrightness
            if let sym = dlsym(dsHandle, "DisplayServicesSetBrightness") {
                _setBrightness = unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, Float) -> Int32).self)
            }
            // Load GetBrightness
            if let sym = dlsym(dsHandle, "DisplayServicesGetBrightness") {
                _getBrightness = unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID) -> Float).self)
            }
            print("DisplayServices Loaded (via CoreBrightness trick)")
        }
        
        // 3. Load CoreDisplay (Fallback)
        let path = "/System/Library/Frameworks/CoreDisplay.framework/Versions/Current/CoreDisplay"
        if let handle = dlopen(path, RTLD_LAZY) {
            if let sym = dlsym(handle, "CoreDisplay_Display_SetUserBrightness") {
                _setBrightnessCD = unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID, Double) -> Void).self)
            }
            if let sym = dlsym(handle, "CoreDisplay_Display_GetUserBrightness") {
                _getBrightnessCD = unsafeBitCast(sym, to: (@convention(c) (CGDirectDisplayID) -> Double).self)
            }
            isCoreDisplayLoaded = true
            print("CoreDisplay Loaded")
        }
    }
    
    static func setBrightness(for displayID: CGDirectDisplayID, value: Double) {
        // Method 0: DisplayServices (The "Real" Way)
        if let setFunc = _setBrightness {
             _ = setFunc(displayID, Float(value))
             return
        }

        // Method 1: IOKit (Primary for Internal Display)
        if isBuiltInDisplay(displayID) {
            if setBrightnessIOKit(value: value) {
                print("IOKit Brightness Set: \(value)")
                return
            }
        }
        
        // Method 2: CoreDisplay (Fallback)
        if !isCoreDisplayLoaded { initialize() }
        _setBrightnessCD?(displayID, value)
    }
    
    static func getBrightness(for displayID: CGDirectDisplayID) -> Double {
        // Method 1: IOKit (Primary for Built-in)
        if isBuiltInDisplay(displayID) {
            // Try IOKit first
            if let val = getBrightnessIOKit() {
                return val
            }
            // Try CoreBrightness (CBClient) via Runtime
            if let val = getBrightnessCoreBrightness() {
                return val
            }
        }
        
        // Method 2: CoreDisplay (Fallback)
        // Warning: User reports this returns 1.0 on M4 Pro.
        // We only use this if NOT built-in (External) or if everything else failed?
        // Actually, for built-in, we prefer 0.5 (unknown) over 1.0 (blind max) if we can't read it.
        // Let's rely on CoreDisplay only for External if needed, or remove it for internal.
        
        return 0.5
    }
    
    static func isBuiltInDisplay(_ displayID: CGDirectDisplayID) -> Bool {
        return CGDisplayIsBuiltin(displayID) == 1
    }
    
    // MARK: - CoreBrightness Implementation (Safe Runtime)
    private static func getBrightnessCoreBrightness() -> Double? {
        // Ensure CoreBrightness is loaded
        let cbPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/Versions/Current/CoreBrightness"
        guard let _ = dlopen(cbPath, RTLD_LAZY) else { return nil }
        
        // Use Runtime to instantiate CBClient
        guard let cbClientClass = NSClassFromString("CBClient") as? NSObject.Type else { return nil }
        let client = cbClientClass.init()
        
        // Try getting "brightness" property
        // Note: CBClient has a 'brightness' property on some versions, or 'blueLightStatus'.
        // Let's try KVC which is safe.
        // On macOS, CBClient might serve TrueTone/NightShift primarily.
        // Actually, 'CBAdaptationClient' or 'CBBlueLightClient' are common.
        // What about "DisplayServices" via CoreBrightness?
        // Let's try the IOKit registry via IORegistryEntryCreateCFProperty, effectively standard IOKit but via a cleaner path? 
        // No, let's stick to the previous IOKit method but fix the iteration?
        
        // Wait, best approach for modern macOS internal brightness:
        // Use the IOKit method but with the correct SERVICE match.
        // If AppleCLCD2, AppleCLCD, etc failed, maybe "AppleEmbeddedOSSupportHost"? No.
        
        // Let's try to blindly return nil here for now and rely on refined IOKit below?
        // Actually, `DisplayServicesGetBrightness` (Function 0 in previous attempt) IS the wrapper around CBClient.
        // If that crashed, using CBClient raw might technically be similar or safer if done via objc msgSend.
        
        return nil 
    }

    // MARK: - IOKit Implementation
    private static func setBrightnessIOKit(value: Double) -> Bool {
        var service: io_service_t = 0
        let services = ["AppleCLCD2", "AppleCLCD", "AppleBacklight", "ApplePanel"]
        
        for serviceName in services {
            service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(serviceName))
            if service != 0 {
                let key = "brightness" as CFString
                let err = IODisplaySetFloatParameter(service, 0, key, Float(value))
                IOObjectRelease(service)
                if err == kIOReturnSuccess { return true }
            }
        }
        return false
    }
    
    private static func getBrightnessIOKit() -> Double? {
        var service: io_service_t = 0
        // Expanded list of possibilities
        let services = ["AppleCLCD2", "AppleCLCD", "AppleBacklight", "ApplePanel", "AppleM2CLCD"] 
        
        for serviceName in services {
            service = IOServiceGetMatchingService(kIOMasterPortDefault, IOServiceMatching(serviceName))
            if service != 0 {
                let key = "brightness" as CFString
                var value: Float = 0.0
                let err = IODisplayGetFloatParameter(service, 0, key, &value)
                IOObjectRelease(service)
                if err == kIOReturnSuccess { return Double(value) }
            }
        }
        
        // Fallback: Iterate ALL "IODisplay" services and look for "brightness"?
        // This is expensive but robust.
        return nil
    }
}
