import AppKit
import XCTest

final class ClipboardStoreTests: XCTestCase {
    private var dir: URL!
    private var pasteboard: NSPasteboard!
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        pasteboard = NSPasteboard(name: NSPasteboard.Name("PasteShelfTests-\(UUID().uuidString)"))
        suiteName = "PasteShelfTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        defaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: dir)
    }

    private func makeStore(maxHistory: Int = 100) -> ClipboardStore {
        ClipboardStore(directory: dir, pasteboard: pasteboard, defaults: defaults, maxHistory: maxHistory)
    }

    private func copyToPasteboard(_ text: String, extraTypes: [String] = []) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        for t in extraTypes { pasteboard.setString("", forType: NSPasteboard.PasteboardType(t)) }
    }

    func testCapturesNewTextAndPutsNewestFirst() {
        let store = makeStore()
        copyToPasteboard("first"); store.checkPasteboard()
        copyToPasteboard("second"); store.checkPasteboard()
        XCTAssertEqual(store.items.map(\.text), ["second", "first"])
    }

    func testDuplicateMovesToTopInsteadOfRepeating() {
        let store = makeStore()
        for t in ["a", "b", "a"] { copyToPasteboard(t); store.checkPasteboard() }
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])
    }

    func testIgnoresWhitespaceOnlyAndConcealedContent() {
        let store = makeStore()
        copyToPasteboard("   \n"); store.checkPasteboard()
        copyToPasteboard("hunter2", extraTypes: ["org.nspasteboard.ConcealedType"]); store.checkPasteboard()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testHistoryLimitNeverDropsFavorites() {
        let store = makeStore(maxHistory: 3)
        store.addText("keep me")
        store.toggleFavorite(store.items[0])
        for i in 1...10 { store.addText("item \(i)") }
        XCTAssertEqual(store.history.count, 3)
        XCTAssertEqual(store.favorites.map(\.text), ["keep me"])
    }

    func testCopyingFromHistoryIsNotRecordedAsNewEntry() {
        let store = makeStore()
        store.addText("one")
        store.addText("two")
        store.copy(store.items[1]) // "one"
        store.checkPasteboard()
        XCTAssertEqual(store.items.map(\.text), ["one", "two"])
        XCTAssertEqual(pasteboard.string(forType: .string), "one")
    }

    func testPlainCopyDropsFormatting() {
        let store = makeStore()
        let rtf = NSAttributedString(string: "bold").rtf(from: NSRange(location: 0, length: 4), documentAttributes: [:])
        store.addText("bold", rtf: rtf)
        store.copy(store.items[0], plain: true)
        XCTAssertNil(pasteboard.data(forType: .rtf))
        store.copy(store.items[0], plain: false)
        XCTAssertNotNil(pasteboard.data(forType: .rtf))
    }

    func testImagesAreStoredOnceAndDeletedWithTheirItem() throws {
        let store = makeStore()
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
        store.addImage(png, size: NSSize(width: 4, height: 4))
        store.addImage(png, size: NSSize(width: 4, height: 4))
        XCTAssertEqual(store.items.count, 1)

        let file = store.imagesDir.appendingPathComponent(try XCTUnwrap(store.items[0].imageFile))
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
        store.delete(store.items[0])
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testHistoryPersistsAcrossLaunches() {
        let store = makeStore()
        store.addText("remember me")
        store.toggleFavorite(store.items[0])
        let reopened = makeStore()
        XCTAssertEqual(reopened.items.map(\.text), ["remember me"])
        XCTAssertTrue(reopened.items[0].favorite)
    }

    func testSearchIsCaseInsensitive() {
        let store = makeStore()
        store.addText("Hello World")
        store.addText("something else")
        XCTAssertEqual(store.visible(search: "hello").hist.map(\.text), ["Hello World"])
    }
}
