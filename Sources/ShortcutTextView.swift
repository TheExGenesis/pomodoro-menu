import AppKit

final class ShortcutTextField: NSTextField {
    var commandEnterAction: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if submitOnCommandEnter(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if submitOnCommandEnter(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func submitOnCommandEnter(_ event: NSEvent) -> Bool {
        guard isCommandEnter(event) else { return false }
        commandEnterAction?()
        return true
    }
}

final class ShortcutTextView: NSTextView {
    var commandEnterAction: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if submitOnCommandEnter(event) {
            return true
        }
        if handleEditingShortcut(event) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if submitOnCommandEnter(event) {
            return
        }
        if handleEditingShortcut(event) {
            return
        }
        super.keyDown(with: event)
    }

    private func submitOnCommandEnter(_ event: NSEvent) -> Bool {
        guard isCommandEnter(event) else { return false }
        commandEnterAction?()
        return true
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

private func isCommandEnter(_ event: NSEvent) -> Bool {
    let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    guard flags.contains(.command),
          !flags.contains(.option),
          !flags.contains(.control),
          let key = event.charactersIgnoringModifiers
    else { return false }

    return key == "\r" || key == "\u{3}"
}
