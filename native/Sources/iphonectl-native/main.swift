import Foundation

// iphonectl-native — Path A: TapKit-style native control with no on-device agent.
// "Eyes" = CoreMediaIO/AVFoundation USB screen capture (functional here).
// "Hands" = Bluetooth-Classic HID keyboard + absolute pointer (report
//           construction functional; L2CAP transport is the private-API boundary,
//           see BluetoothHID.swift). Runs in DryRun transport by default so the
//           pointer/keyboard wire bytes are demonstrable without pairing.

func usage() {
    let text = """
    iphonectl-native — native (no-agent) iPhone control, TapKit-style

    USAGE
      iphonectl-native <command> [args]

    EYES (CoreMediaIO USB screen capture — functional)
      devices                       List USB-attached iPhones/iPads as capture devices
      screenshot <out.png> [udid]   Capture one frame from the device to a PNG

    HANDS (Bluetooth-Classic HID — report bytes functional; transport is private-API)
      hid-descriptor                Print the keyboard + absolute-pointer HID descriptors
      tap <nx> <ny>                 Emit the HID reports for a tap at normalized (0..1) coords
      type <text>                   Emit the HID keyboard reports for an ASCII string

      help                          This text

    NOTES
      • screenshot/devices need the iPhone plugged in, unlocked, and Trusting this Mac.
      • tap/type run through a DryRun transport that prints the exact wire bytes.
        A real deployment plugs an L2CAP transport into HIDTransport (BluetoothHID.swift).
    """
    print(text)
}

let args = Array(CommandLine.arguments.dropFirst())
let cmd = args.first ?? "help"

switch cmd {
case "devices":
    CMIOScreenCapture.listDevices()

case "screenshot":
    guard args.count >= 2 else { FileHandle.standardError.write("usage: screenshot <out.png> [udid]\n".data(using: .utf8)!); exit(2) }
    let out = args[1]
    let udid = args.count >= 3 ? args[2] : nil
    exit(CMIOScreenCapture.screenshot(to: out, deviceID: udid) ? 0 : 5)

case "hid-descriptor":
    print("# keyboard (\(HIDDescriptors.keyboard.count) bytes)")
    print(HIDDescriptors.hex(HIDDescriptors.keyboard))
    print("# absolute-pointer (\(HIDDescriptors.absolutePointer.count) bytes)")
    print(HIDDescriptors.hex(HIDDescriptors.absolutePointer))

case "tap":
    guard args.count >= 3, let nx = Double(args[1]), let ny = Double(args[2]) else {
        FileHandle.standardError.write("usage: tap <nx 0..1> <ny 0..1>\n".data(using: .utf8)!); exit(2)
    }
    BluetoothHIDDevice().tap(normalizedX: nx, normalizedY: ny)

case "type":
    guard args.count >= 2 else { FileHandle.standardError.write("usage: type <text>\n".data(using: .utf8)!); exit(2) }
    BluetoothHIDDevice().type(args.dropFirst().joined(separator: " "))

case "help", "-h", "--help":
    usage()

default:
    FileHandle.standardError.write("unknown command: \(cmd)\n".data(using: .utf8)!)
    usage()
    exit(2)
}
