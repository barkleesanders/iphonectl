import Foundation
import CoreMediaIO
import AVFoundation
import CoreImage
import CoreVideo
import AppKit

// Reproduces TapKit's "eyes": the iPhone, plugged in over USB, is exposed to the
// Mac as an AVCaptureDevice once the CoreMediaIO DAL screen-capture toggle is on.
// This is the exact mechanism QuickTime uses for "New Movie Recording -> iPhone".
enum CMIOScreenCapture {

    /// Flip kCMIOHardwarePropertyAllowScreenCaptureDevices = 1 so USB-attached
    /// iOS devices publish their screen as a DAL video device.
    static func enableScreenCaptureDevices() {
        var addr = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyAllowScreenCaptureDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var allow: UInt32 = 1
        let size = UInt32(MemoryLayout<UInt32>.size)
        let status = CMIOObjectSetPropertyData(
            CMIOObjectID(kCMIOObjectSystemObject), &addr, 0, nil, size, &allow)
        if status != kCMIOHardwareNoError {
            FileHandle.standardError.write(
                "warning: enabling DAL screen-capture devices returned status \(status)\n".data(using: .utf8)!)
        }
    }

    /// All external (USB) capture devices, i.e. connected iPhones/iPads.
    static func externalDevices() -> [AVCaptureDevice] {
        enableScreenCaptureDevices()
        var types: [AVCaptureDevice.DeviceType] = []
        if #available(macOS 14.0, *) { types.append(.external) }
        let session = AVCaptureDevice.DiscoverySession(
            deviceTypes: types, mediaType: nil, position: .unspecified)
        return session.devices
    }

    static func listDevices() {
        let devs = externalDevices()
        if devs.isEmpty {
            print("no external capture devices. Plug in the iPhone, unlock it, and Trust this Mac.")
            return
        }
        for d in devs {
            print("\(d.uniqueID)\t\(d.localizedName)\t[\(d.manufacturer)]")
        }
    }

    /// Grab one frame from the first (or named) device and write a PNG.
    static func screenshot(to path: String, deviceID: String?) -> Bool {
        let devs = externalDevices()
        guard let device = deviceID.flatMap({ id in devs.first { $0.uniqueID == id } }) ?? devs.first else {
            FileHandle.standardError.write("error: no external capture device found\n".data(using: .utf8)!)
            return false
        }

        let session = AVCaptureSession()
        session.sessionPreset = .high
        guard let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            FileHandle.standardError.write("error: cannot open capture input for \(device.localizedName)\n".data(using: .utf8)!)
            return false
        }
        session.addInput(input)

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        let grabber = FrameGrabber()
        let queue = DispatchQueue(label: "iphonectl.capture")
        output.setSampleBufferDelegate(grabber, queue: queue)
        guard session.canAddOutput(output) else {
            FileHandle.standardError.write("error: cannot add video output\n".data(using: .utf8)!)
            return false
        }
        session.addOutput(output)

        session.startRunning()
        let got = grabber.wait(seconds: 10)
        session.stopRunning()

        guard got, let image = grabber.pngData() else {
            FileHandle.standardError.write("error: no frame captured within 10s\n".data(using: .utf8)!)
            return false
        }
        do {
            try image.write(to: URL(fileURLWithPath: path))
            print("wrote \(image.count) bytes -> \(path)")
            return true
        } catch {
            FileHandle.standardError.write("error: writing PNG: \(error)\n".data(using: .utf8)!)
            return false
        }
    }
}

final class FrameGrabber: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let sem = DispatchSemaphore(value: 0)
    private var buffer: CVPixelBuffer?
    private let ciContext = CIContext()

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard buffer == nil, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        buffer = pb
        sem.signal()
    }

    func wait(seconds: Int) -> Bool {
        sem.wait(timeout: .now() + .seconds(seconds)) == .success
    }

    func pngData() -> Data? {
        guard let pb = buffer else { return nil }
        let ci = CIImage(cvPixelBuffer: pb)
        guard let cg = ciContext.createCGImage(ci, from: ci.extent) else { return nil }
        let rep = NSBitmapImageRep(cgImage: cg)
        return rep.representation(using: .png, properties: [:])
    }
}
