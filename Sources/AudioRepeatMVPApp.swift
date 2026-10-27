import SwiftUI

@main
struct AudioRepeatMVPApp: App {
    var body: some Scene {
        WindowGroup("너는 생각보다 언어를 잘한다") {
            ContentView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .windowResizability(.contentSize)
    }
}
