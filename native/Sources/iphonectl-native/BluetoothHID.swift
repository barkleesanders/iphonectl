import Foundation

// Reproduces TapKit's "hands": a Bluetooth-Classic HID device (keyboard +
// absolute pointer) the iPhone pairs with, so the Mac can inject taps and text.
//
// TRANSPORT BOUNDARY (honest): TapKit carries HID reports over a Bluetooth
// Classic L2CAP channel (PSM 0x11 control / 0x13 interrupt) using the private
// CoreBluetooth classes CBClassicManager / CBClassicPeer / CBL2CAPChannel plus
// HIDP transactions. Those symbols still exist on macOS 27 (confirmed by the
// decompile) but are Apple-private and unentitled here. This module builds the
// exact, spec-correct HID input reports and hands them to a pluggable transport.
// The default transport prints the wire bytes so the report construction is
// verifiable end-to-end without the private entitlement; a real deployment
// swaps in an L2CAP transport (via the private CB classes or an IOBluetooth
// L2CAP channel) behind the same protocol.
protocol HIDTransport {
    func sendReport(_ bytes: [UInt8])
    var isConnected: Bool { get }
}

/// Prints reports instead of transmitting. Lets the pointer/keyboard math be
/// tested and demonstrated with no paired device and no private API.
struct DryRunTransport: HIDTransport {
    var isConnected: Bool { false }
    func sendReport(_ bytes: [UInt8]) {
        print("HID report: " + bytes.map { String(format: "%02X", $0) }.joined(separator: " "))
    }
}

final class BluetoothHIDDevice {
    // Logical coordinate ceiling from the absolute-pointer descriptor (0..32767).
    static let logicalMax: Double = 32767

    private let transport: HIDTransport

    init(transport: HIDTransport = DryRunTransport()) {
        self.transport = transport
    }

    var isConnected: Bool { transport.isConnected }

    // MARK: absolute pointer (report id 2): [id, buttons, xLo, xHi, yLo, yHi]

    /// Move the pointer to a normalized position. `nx`,`ny` in 0.0...1.0 of the
    /// device screen. `buttonsDown` sets the button bitfield (bit0 = primary).
    func movePointer(normalizedX nx: Double, normalizedY ny: Double, buttons: UInt8 = 0) {
        let x = UInt16((max(0, min(1, nx)) * Self.logicalMax).rounded())
        let y = UInt16((max(0, min(1, ny)) * Self.logicalMax).rounded())
        let report: [UInt8] = [
            0x02, buttons,
            UInt8(x & 0xFF), UInt8(x >> 8),
            UInt8(y & 0xFF), UInt8(y >> 8),
        ]
        transport.sendReport(report)
    }

    /// Tap: move to (nx,ny), press primary button, release.
    func tap(normalizedX nx: Double, normalizedY ny: Double) {
        movePointer(normalizedX: nx, normalizedY: ny, buttons: 0x00)
        movePointer(normalizedX: nx, normalizedY: ny, buttons: 0x01) // button down
        movePointer(normalizedX: nx, normalizedY: ny, buttons: 0x00) // release
    }

    // MARK: keyboard (report id 1): [id, modifiers, reserved, k1..k6]

    /// Press then release a single HID keycode with optional modifier byte.
    func pressKey(_ keycode: UInt8, modifiers: UInt8 = 0) {
        let down: [UInt8] = [0x01, modifiers, 0x00, keycode, 0, 0, 0, 0]
        let up:   [UInt8] = [0x01, 0x00, 0x00, 0x00, 0, 0, 0, 0]
        transport.sendReport(down)
        transport.sendReport(up)
    }

    /// Type an ASCII string via the US-keyboard usage table (letters/digits/space).
    func type(_ text: String) {
        for ch in text.unicodeScalars {
            guard let (code, shift) = Self.usbKeycode(for: ch) else { continue }
            pressKey(code, modifiers: shift ? 0x02 : 0x00) // 0x02 = LeftShift
        }
    }

    /// Minimal US-QWERTY ASCII -> (HID usage, needsShift) mapping.
    static func usbKeycode(for scalar: Unicode.Scalar) -> (UInt8, Bool)? {
        let c = Character(scalar)
        switch c {
        case "a"..."z": return (UInt8(0x04 + (scalar.value - Unicode.Scalar("a").value)), false)
        case "A"..."Z": return (UInt8(0x04 + (scalar.value - Unicode.Scalar("A").value)), true)
        case "1"..."9": return (UInt8(0x1E + (scalar.value - Unicode.Scalar("1").value)), false)
        case "0": return (0x27, false)
        case " ": return (0x2C, false)
        case "\n": return (0x28, false)  // Return
        case ".": return (0x37, false)
        case ",": return (0x36, false)
        case "-": return (0x2D, false)
        default: return nil
        }
    }
}
