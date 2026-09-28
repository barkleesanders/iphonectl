import Foundation

// USB-HID report descriptors reproducing TapKit's Bluetooth-Classic HID device:
// a boot keyboard plus an ABSOLUTE pointer (digitizer). An absolute pointer lets
// the host command "tap at (x,y)" directly, which is what screen-coordinate
// control needs — a relative mouse cannot.
//
// These are the wire contract the L2CAP/HIDP transport (see BluetoothHID.swift)
// carries. They are standard descriptors, verifiable against the USB HID Usage
// Tables (v1.4), not anything Apple-private.
enum HIDDescriptors {

    // Boot keyboard: 8-byte input report [modifiers, reserved, key1..key6].
    static let keyboard: [UInt8] = [
        0x05, 0x01,        // Usage Page (Generic Desktop)
        0x09, 0x06,        // Usage (Keyboard)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x01,        //   Report ID (1)
        0x05, 0x07,        //   Usage Page (Keyboard/Keypad)
        0x19, 0xE0,        //   Usage Minimum (LeftControl)
        0x29, 0xE7,        //   Usage Maximum (Right GUI)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0x01,        //   Logical Maximum (1)
        0x75, 0x01,        //   Report Size (1)
        0x95, 0x08,        //   Report Count (8)
        0x81, 0x02,        //   Input (Data,Var,Abs)  ; modifier byte
        0x95, 0x01,        //   Report Count (1)
        0x75, 0x08,        //   Report Size (8)
        0x81, 0x03,        //   Input (Const)          ; reserved byte
        0x95, 0x06,        //   Report Count (6)
        0x75, 0x08,        //   Report Size (8)
        0x15, 0x00,        //   Logical Minimum (0)
        0x25, 0xFF,        //   Logical Maximum (255)
        0x05, 0x07,        //   Usage Page (Keyboard/Keypad)
        0x19, 0x00,        //   Usage Minimum (0)
        0x29, 0xFF,        //   Usage Maximum (255)
        0x81, 0x00,        //   Input (Data,Array)     ; up to 6 keycodes
        0xC0               // End Collection
    ]

    // Absolute pointer: report [buttons, x_lo, x_hi, y_lo, y_hi], X/Y in 0..32767
    // (logical), which the host maps onto the device's point-space.
    static let absolutePointer: [UInt8] = [
        0x05, 0x01,        // Usage Page (Generic Desktop)
        0x09, 0x02,        // Usage (Mouse)
        0xA1, 0x01,        // Collection (Application)
        0x85, 0x02,        //   Report ID (2)
        0x09, 0x01,        //   Usage (Pointer)
        0xA1, 0x00,        //   Collection (Physical)
        0x05, 0x09,        //     Usage Page (Button)
        0x19, 0x01,        //     Usage Minimum (Button 1)
        0x29, 0x03,        //     Usage Maximum (Button 3)
        0x15, 0x00,        //     Logical Minimum (0)
        0x25, 0x01,        //     Logical Maximum (1)
        0x95, 0x03,        //     Report Count (3)
        0x75, 0x01,        //     Report Size (1)
        0x81, 0x02,        //     Input (Data,Var,Abs)   ; 3 buttons
        0x95, 0x01,        //     Report Count (1)
        0x75, 0x05,        //     Report Size (5)
        0x81, 0x03,        //     Input (Const)          ; padding
        0x05, 0x01,        //     Usage Page (Generic Desktop)
        0x09, 0x30,        //     Usage (X)
        0x09, 0x31,        //     Usage (Y)
        0x16, 0x00, 0x00,  //     Logical Minimum (0)
        0x26, 0xFF, 0x7F,  //     Logical Maximum (32767)
        0x75, 0x10,        //     Report Size (16)
        0x95, 0x02,        //     Report Count (2)
        0x81, 0x02,        //     Input (Data,Var,Abs)   ; absolute X,Y
        0xC0,              //   End Collection
        0xC0               // End Collection
    ]

    static func hex(_ bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
}
