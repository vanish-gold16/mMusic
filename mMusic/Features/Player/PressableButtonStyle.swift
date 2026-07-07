import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        PressableLabel(configuration: configuration)
    }
    
    private struct PressableLabel: View {
        @State private var pressed = false
        
        let configuration: Configuration
        
        var body: some View {
            configuration.label
                .scaleEffect(pressed ? 0.0 : 1.0)
                .animation(.spring(response: 0.5, dampingFraction: 0.6), value: pressed)
                .onChange(of: configuration.isPressed) { _, isNowPressed in
                    if isNowPressed {
                        pressed = true
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            pressed = false
                        }
                    }
                }
        }
    }
}
