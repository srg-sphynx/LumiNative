import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var currentPage = 0
    
    var body: some View {
        VStack {
            // Header / Decoration
            HStack {
                Spacer()
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(Theme.accentColor.opacity(0.3))
                    .rotationEffect(.degrees(Double(currentPage * 45)))
                    .animation(.spring(), value: currentPage)
            }
            .padding(.top, -20)
            .padding(.trailing, -20)
            
            Spacer()
            
            // Content
            ZStack {
                if currentPage == 0 {
                    // Page 1: Welcome
                    VStack(spacing: 20) {
                        Image(systemName: "display.2")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .padding(.bottom, 20)
                        
                        Text("Welcome to LumiNative")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text("The seamless way to control your external monitors on Apple Silicon.")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 40)
                    }
                    .transition(.opacity)
                } else if currentPage == 1 {
                    // Page 2: Features
                    VStack(spacing: 25) {
                        FeatureRow(icon: "sun.max.fill", title: "Brightness Sync", description: "Automatically matches your external monitor brightness to your built-in display.")
                        FeatureRow(icon: "slider.horizontal.3", title: "Presets", description: "Switch between Work, Gaming, and Movie modes instantly.")
                        FeatureRow(icon: "macwindow", title: "Native UI", description: "Designed with a beautiful Liquid Glass aesthetic that feels right at home.")
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                } else if currentPage == 2 {
                    // Page 3: Permissions
                    VStack(spacing: 20) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Permissions")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        
                        Text("To control monitor volume and use keyboard shortcuts, LumiNative needs Accessibility permissions.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        if AXIsProcessTrusted() {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Permissions Granted")
                                    .fontWeight(.medium)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                        } else {
                            Button("Grant Permissions") {
                                let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
                                AXIsProcessTrustedWithOptions(options as CFDictionary)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            
                            Text("You may need to restart the app after granting access.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut, value: currentPage)
            .frame(height: 300)
            
            Spacer()
            
            // Footer Controls
            HStack {
                if currentPage < 2 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        if currentPage < 2 {
                            currentPage += 1
                        } else {
                            completeOnboarding()
                        }
                    }
                }) {
                    Text(currentPage == 2 ? "Get Started" : "Next")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Theme.accentColor)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(30)
        }
        .frame(width: 600, height: 450)
        .glassBackground(material: Theme.backgroundMaterial)
    }
    
    private func completeOnboarding() {
        withAnimation {
            hasCompletedOnboarding = true
            // close window?
            // In SwiftUI Scene, we might just hide the view or rely on state.
            // If this is an NSWindow, we can close it.
            if let window = NSApplication.shared.windows.first(where: { $0.title == "Welcome" || $0.identifier?.rawValue == "onboarding" }) {
                window.close()
            } else {
                // Fallback for standalone window usage
                NSApplication.shared.windows.last?.close()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Theme.controlBackground)
                .cornerRadius(10)
                .foregroundColor(Theme.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.primaryText)
                Text(description)
                    .font(.caption)
                    .foregroundColor(Theme.secondaryText)
            }
            Spacer()
        }
    }
}
