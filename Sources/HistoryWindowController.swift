import AppKit

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private enum ColumnID {
        static let started = NSUserInterfaceItemIdentifier("started")
        static let actual = NSUserInterfaceItemIdentifier("actual")
        static let planned = NSUserInterfaceItemIdentifier("planned")
        static let outcome = NSUserInterfaceItemIdentifier("outcome")
        static let intention = NSUserInterfaceItemIdentifier("intention")
        static let review = NSUserInterfaceItemIdentifier("review")
    }

    private let store = PomodoroHistoryStore.shared
    private let tableView = NSTableView(frame: .zero)
    private let summaryLabel = NSTextField(labelWithString: "")
    private let detailTextView = NSTextView(frame: .zero)
    private let startedFormatter = DateFormatter()

    private var sessions: [PomodoroSession] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pomodoro History"
        window.center()
        super.init(window: window)

        startedFormatter.dateStyle = .medium
        startedFormatter.timeStyle = .short
        startedFormatter.isLenient = true

        buildContent()
        reloadHistory()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadHistory),
            name: .pomodoroHistoryChanged,
            object: nil
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    func show() {
        reloadHistory()
        showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let contentView = window?.contentView else { return }

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 12
        root.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            root.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            root.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            root.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])

        summaryLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        root.addArrangedSubview(summaryLabel)

        configureTable()
        let tableScroll = NSScrollView()
        tableScroll.borderType = .bezelBorder
        tableScroll.hasVerticalScroller = true
        tableScroll.documentView = tableView
        tableScroll.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(tableScroll)

        detailTextView.isEditable = false
        detailTextView.isSelectable = true
        detailTextView.font = NSFont.systemFont(ofSize: 13)
        detailTextView.textContainerInset = NSSize(width: 8, height: 8)

        let detailScroll = NSScrollView()
        detailScroll.borderType = .bezelBorder
        detailScroll.hasVerticalScroller = true
        detailScroll.documentView = detailTextView
        detailScroll.translatesAutoresizingMaskIntoConstraints = false
        root.addArrangedSubview(detailScroll)

        let controls = buttonRow()
        root.addArrangedSubview(controls)

        NSLayoutConstraint.activate([
            tableScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            tableScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            detailScroll.widthAnchor.constraint(equalTo: root.widthAnchor),
            detailScroll.heightAnchor.constraint(equalToConstant: 128),
            controls.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
    }

    private func configureTable() {
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 26
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle

        addColumn(id: ColumnID.started, title: "Started", width: 150)
        addColumn(id: ColumnID.actual, title: "Actual", width: 66)
        addColumn(id: ColumnID.planned, title: "Planned", width: 70)
        addColumn(id: ColumnID.outcome, title: "Did it?", width: 70)
        addColumn(id: ColumnID.intention, title: "Doing", width: 220)
        addColumn(id: ColumnID.review, title: "Review", width: 240)
    }

    private func addColumn(id: NSUserInterfaceItemIdentifier, title: String, width: CGFloat) {
        let column = NSTableColumn(identifier: id)
        column.title = title
        column.width = width
        column.minWidth = min(width, 70)
        tableView.addTableColumn(column)
    }

    private func buttonRow() -> NSStackView {
        let refresh = NSButton(title: "Refresh", target: self, action: #selector(reloadHistory))
        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.keyEquivalent = "\r"

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [refresh, spacer, done])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        return row
    }

    @objc private func reloadHistory() {
        let previouslySelectedID = selectedSessionID
        sessions = store.sessions()
        tableView.reloadData()
        summaryLabel.stringValue = summaryText

        if sessions.isEmpty {
            tableView.deselectAll(nil)
            detailTextView.string = "No pomodoros logged yet."
        } else {
            let selectedRow = previouslySelectedID
                .flatMap { id in sessions.firstIndex { $0.id == id } } ?? 0
            tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
            updateDetail()
        }
    }

    private var summaryText: String {
        let completed = sessions.filter { $0.outcome == .done }.count
        let partial = sessions.filter { $0.outcome == .partial }.count
        let totalPlannedMinutes = sessions.reduce(0) { total, session in
            total + plannedMinutes(for: session)
        }
        let totalActualMinutes = sessions.reduce(0) { total, session in
            total + actualMinutes(for: session)
        }
        return "\(sessions.count) pomodoros - \(completed) done, \(partial) partial - \(totalActualMinutes) actual / \(totalPlannedMinutes) planned minutes"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard sessions.indices.contains(row), let tableColumn else { return nil }
        if tableColumn.identifier == ColumnID.outcome {
            let popup = tableView.makeView(withIdentifier: ColumnID.outcome, owner: self) as? NSPopUpButton ?? makeOutcomePopup()
            popup.tag = row
            popup.selectItem(withTitle: sessions[row].outcome.title)
            return popup
        }

        let cellIdentifier = NSUserInterfaceItemIdentifier("cell-\(tableColumn.identifier.rawValue)")
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView ?? makeCell(identifier: cellIdentifier)
        configureTextCell(cell, column: tableColumn.identifier, session: sessions[row], row: row)
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let field = NSTextField(frame: .zero)
        field.isBordered = false
        field.drawsBackground = false
        field.delegate = self
        field.lineBreakMode = .byTruncatingTail
        field.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(field)
        cell.textField = field

        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            field.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            field.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])

        return cell
    }

    private func configureTextCell(_ cell: NSTableCellView, column: NSUserInterfaceItemIdentifier, session: PomodoroSession, row: Int) {
        guard let field = cell.textField else { return }
        field.identifier = column
        field.tag = row
        field.stringValue = value(for: column, session: session)
        field.isEditable = isEditableTextColumn(column)
        field.isSelectable = true
        field.textColor = isEditableTextColumn(column) ? .controlTextColor : .secondaryLabelColor
    }

    private func makeOutcomePopup() -> NSPopUpButton {
        let popup = NSPopUpButton(frame: .zero, pullsDown: false)
        popup.identifier = ColumnID.outcome
        popup.controlSize = .small
        popup.font = NSFont.systemFont(ofSize: 12)
        popup.target = self
        popup.action = #selector(outcomeChanged)

        for outcome in [PomodoroOutcome.done, .partial, .missed, .notRecorded] {
            popup.addItem(withTitle: outcome.title)
            popup.lastItem?.representedObject = outcome.rawValue
        }

        return popup
    }

    private func isEditableTextColumn(_ column: NSUserInterfaceItemIdentifier) -> Bool {
        switch column {
        case ColumnID.started, ColumnID.actual, ColumnID.planned, ColumnID.intention, ColumnID.review:
            return true
        default:
            return false
        }
    }

    private func value(for column: NSUserInterfaceItemIdentifier, session: PomodoroSession) -> String {
        switch column {
        case ColumnID.started:
            return startedFormatter.string(from: session.startedAt)
        case ColumnID.actual:
            return "\(actualMinutes(for: session))"
        case ColumnID.planned:
            return "\(plannedMinutes(for: session))"
        case ColumnID.outcome:
            return session.outcome.title
        case ColumnID.intention:
            return session.intention
        case ColumnID.review:
            return session.review
        default:
            return ""
        }
    }

    private func displayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        guard let field = notification.object as? NSTextField else { return }
        commitTextEdit(from: field)
    }

    private func commitTextEdit(from field: NSTextField) {
        let detectedRow = tableView.row(for: field)
        let row = detectedRow >= 0 ? detectedRow : field.tag
        guard sessions.indices.contains(row),
              let column = field.identifier
        else { return }

        var session = sessions[row]
        let original = session
        switch column {
        case ColumnID.started:
            guard let startedAt = startedFormatter.date(from: field.stringValue) else {
                reload(row: row)
                return
            }
            let elapsed = session.endedAt?.timeIntervalSince(session.startedAt)
            session.startedAt = startedAt
            if let elapsed {
                session.endedAt = startedAt.addingTimeInterval(elapsed)
            }
        case ColumnID.actual:
            guard let minutes = integerValue(field.stringValue, min: 0, max: 24 * 60) else {
                reload(row: row)
                return
            }
            session.endedAt = session.startedAt.addingTimeInterval(TimeInterval(minutes * 60))
        case ColumnID.planned:
            guard let minutes = integerValue(field.stringValue, min: 1, max: 24 * 60) else {
                reload(row: row)
                return
            }
            session.plannedSeconds = minutes * 60
        case ColumnID.intention:
            session.intention = normalizedText(field.stringValue)
        case ColumnID.review:
            session.review = normalizedText(field.stringValue)
        default:
            return
        }

        guard session != original else {
            reload(row: row)
            return
        }
        saveEditedSession(session, row: row)
    }

    @objc private func outcomeChanged(_ sender: NSPopUpButton) {
        let detectedRow = tableView.row(for: sender)
        let row = detectedRow >= 0 ? detectedRow : sender.tag
        guard sessions.indices.contains(row),
              let rawValue = sender.selectedItem?.representedObject as? String,
              let outcome = PomodoroOutcome(rawValue: rawValue)
        else { return }

        var session = sessions[row]
        guard session.outcome != outcome else { return }
        session.outcome = outcome
        saveEditedSession(session, row: row)
    }

    private func saveEditedSession(_ session: PomodoroSession, row: Int) {
        sessions[row] = session
        store.update(session)
        summaryLabel.stringValue = summaryText
        updateDetail()
    }

    private func reload(row: Int) {
        guard sessions.indices.contains(row) else { return }
        tableView.reloadData(
            forRowIndexes: IndexSet(integer: row),
            columnIndexes: IndexSet(integersIn: 0..<tableView.numberOfColumns)
        )
        updateDetail()
    }

    private var selectedSessionID: UUID? {
        let row = tableView.selectedRow
        guard sessions.indices.contains(row) else { return nil }
        return sessions[row].id
    }

    private func integerValue(_ text: String, min: Int, max: Int) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int(trimmed) else { return nil }
        return Swift.max(min, Swift.min(max, value))
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDetail()
    }

    private func updateDetail() {
        let row = tableView.selectedRow
        guard sessions.indices.contains(row) else {
            detailTextView.string = "Select a pomodoro."
            return
        }

        let session = sessions[row]
        let endedText = session.endedAt.map { startedFormatter.string(from: $0) } ?? "-"
        detailTextView.string = """
        Started: \(startedFormatter.string(from: session.startedAt))
        Ended: \(endedText)
        Actual: \(actualMinutes(for: session)) minutes
        Planned: \(plannedMinutes(for: session)) minutes
        Did you do it?: \(session.outcome.title)

        Doing:
        \(displayText(session.intention))

        What happened:
        \(displayText(session.review))
        """
    }

    private func actualMinutes(for session: PomodoroSession) -> Int {
        guard let endedAt = session.endedAt else { return 0 }
        let elapsed = max(0, endedAt.timeIntervalSince(session.startedAt))
        return Int(ceil(elapsed / 60.0))
    }

    private func plannedMinutes(for session: PomodoroSession) -> Int {
        Int(ceil(Double(session.plannedSeconds) / 60.0))
    }

    @objc private func closeWindow() {
        close()
    }
}
