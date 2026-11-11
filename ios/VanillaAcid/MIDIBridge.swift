import Foundation
import CoreMIDI
import WebKit

/// CoreMIDI <-> WebView。JS側は Resources/midi-polyfill.js が navigator.requestMIDIAccess を補完する。
final class MIDIBridge: NSObject, WKScriptMessageHandler {
    static let shared = MIDIBridge()
    weak var webView: WKWebView?

    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var outPort = MIDIPortRef()
    private var connected = Set<MIDIEndpointRef>()
    private var started = false
    private let timebase: mach_timebase_info_data_t = {
        var t = mach_timebase_info_data_t(); mach_timebase_info(&t); return t
    }()

    // MARK: setup
    private func start() {
        if started { return }
        started = true
        MIDIClientCreateWithBlock("VanillaAcid" as CFString, &client) { [weak self] _ in
            DispatchQueue.main.async { self?.publish() }
        }
        MIDIInputPortCreateWithBlock(client, "in" as CFString, &inPort) { [weak self] list, ref in
            self?.handle(list, ref)
        }
        MIDIOutputPortCreate(client, "out" as CFString, &outPort)
    }

    private func name(_ e: MIDIEndpointRef) -> String {
        var cf: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(e, kMIDIPropertyDisplayName, &cf)
        return (cf?.takeRetainedValue() as String?) ?? "MIDI"
    }

    private func publish() {
        var ins: [[String: Any]] = [], outs: [[String: Any]] = []
        var present = Set<MIDIEndpointRef>()
        for i in 0..<MIDIGetNumberOfSources() {
            let e = MIDIGetSource(i)
            present.insert(e)
            ins.append(["id": "\(e)", "name": name(e)])
            if !connected.contains(e) {
                MIDIPortConnectSource(inPort, e, UnsafeMutableRawPointer(bitPattern: UInt(e)))
            }
        }
        connected = present
        for i in 0..<MIDIGetNumberOfDestinations() {
            let e = MIDIGetDestination(i)
            outs.append(["id": "\(e)", "name": name(e)])
        }
        eval("window.__vaMidiPorts && window.__vaMidiPorts(\(json(["inputs": ins, "outputs": outs])))")
    }

    // MARK: JS -> native
    func userContentController(_ ucc: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let d = message.body as? [String: Any], let a = d["a"] as? String else { return }
        switch a {
        case "list":
            start(); publish()
        case "send":
            guard let idStr = d["id"] as? String, let e = UInt32(idStr),
                  let arr = d["d"] as? [Int] else { return }
            send(e, arr.map { UInt8(truncatingIfNeeded: $0) }, delayMs: (d["delay"] as? Double) ?? 0)
        default: break
        }
    }

    private func send(_ dest: MIDIEndpointRef, _ bytes: [UInt8], delayMs: Double) {
        guard !bytes.isEmpty, bytes.count <= 200 else { return }
        var ts: MIDITimeStamp = 0
        if delayMs > 0 {
            let ns = UInt64(delayMs * 1_000_000)
            ts = mach_absolute_time() + ns * UInt64(timebase.denom) / UInt64(timebase.numer)
        }
        var list = MIDIPacketList()
        let pkt = MIDIPacketListInit(&list)
        _ = MIDIPacketListAdd(&list, MemoryLayout<MIDIPacketList>.size, pkt, ts, bytes.count, bytes)
        MIDISend(outPort, dest, &list)
    }

    // MARK: native -> JS
    private func handle(_ list: UnsafePointer<MIDIPacketList>, _ ref: UnsafeMutableRawPointer?) {
        let id = Int(bitPattern: ref)
        var msgs: [[Int]] = []
        let packets = list.pointee
        var packet = packets.packet
        for _ in 0..<packets.numPackets {
            let len = Int(packet.length)
            let bytes: [UInt8] = withUnsafeBytes(of: packet.data) { Array($0.prefix(len)) }
            split(bytes, into: &msgs)
            packet = MIDIPacketNext(&packet).pointee
        }
        if msgs.isEmpty { return }
        DispatchQueue.main.async { [weak self] in
            self?.eval("window.__vaMidiIn && window.__vaMidiIn(\"\(id)\", \(self?.json(msgs) ?? "[]"))")
        }
    }

    private func split(_ b: [UInt8], into out: inout [[Int]]) {
        var i = 0
        while i < b.count {
            let s = b[i]
            if s >= 0xF8 { out.append([Int(s)]); i += 1 }
            else if s == 0xF0 {
                var j = i
                while j < b.count && b[j] != 0xF7 { j += 1 }
                let end = min(j, b.count - 1)
                out.append(b[i...end].map { Int($0) }); i = end + 1
            } else if s >= 0x80 {
                let n: Int
                switch s {
                case 0xC0...0xDF, 0xF1, 0xF3: n = 2
                case 0xF6: n = 1
                default: n = 3
                }
                let end = min(i + n - 1, b.count - 1)
                out.append(b[i...end].map { Int($0) }); i = end + 1
            } else { i += 1 }
        }
    }

    private func eval(_ js: String) {
        DispatchQueue.main.async { [weak self] in self?.webView?.evaluateJavaScript(js, completionHandler: nil) }
    }
    private func json(_ o: Any) -> String {
        guard let d = try? JSONSerialization.data(withJSONObject: o), let s = String(data: d, encoding: .utf8) else { return "null" }
        return s
    }
}
