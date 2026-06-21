import AppKit

final class ShortcutTextView: NSTextView {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if handleEditingShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if handleEditingShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func handleEditingShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command),
              !flags.contains(.option),
              !flags.contains(.control),
              let key = event.charactersIgnoringModifiers?.lowercased()
        else { return false }

        switch key {
        case "a":
            selectAll(nil)
        case "c":
            copy(nil)
        case "x":
            cut(nil)
        case "v":
            paste(nil)
        case "z" where flags.contains(.shift):
            undoManager?.redo()
        case "z":
            undoManager?.undo()
        case "y":
            undoManager?.redo()
        default:
            return false
        }

        return true
    }
}
