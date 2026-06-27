import AppKit
import SwiftUI

private struct LocalKeyEventMonitorModifier: ViewModifier {
  let isEnabled: Bool
  let handler: (NSEvent) -> Bool
  @State private var monitor: Any?

  func body(content: Content) -> some View {
    content
      .onAppear {
        installMonitorIfNeeded()
      }
      .onDisappear {
        removeMonitor()
      }
      .onChange(of: isEnabled) { _, enabled in
        if enabled {
          installMonitorIfNeeded()
        } else {
          removeMonitor()
        }
      }
  }

  private func installMonitorIfNeeded() {
    guard isEnabled, monitor == nil else {
      return
    }

    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      handler(event) ? nil : event
    }
  }

  private func removeMonitor() {
    guard let monitor else {
      return
    }

    NSEvent.removeMonitor(monitor)
    self.monitor = nil
  }
}

extension View {
  func onLocalKeyDown(
    when isEnabled: Bool,
    perform handler: @escaping (NSEvent) -> Bool
  ) -> some View {
    modifier(
      LocalKeyEventMonitorModifier(
        isEnabled: isEnabled,
        handler: handler
      )
    )
  }
}
