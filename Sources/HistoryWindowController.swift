import AppKit

final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private enum ColumnID {
        static let started = NSUserInterfaceItemIdentifier("started")
        static let duration = NSUserInterfaceItemIdentifier("duration")
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
        addColumn(id: ColumnID.duration, title: "Minutes", width: 70)
        addColumn(id: ColumnID.outcome, title: "Did it?", width: 70)
        addColumn(id: ColumnID.intention, title: "Doing", width: 230)
        addColumn(id: ColumnID.review, title: "Review", width: 270)
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
        sessions = store.sessions()
        tableView.reloadData()
        summaryLabel.stringValue = summaryText

        if sessions.isEmpty {
            tableView.deselectAll(nil)
            detailTextView.string = "No pomodoros logged yet."
        } else if tableView.selectedRow < 0 || tableView.selectedRow >= sessions.count {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            updateDetail()
        } else {
            updateDetail()
        }
    }

    private var summaryText: String {
        let completed = sessions.filter { $0.outcome == .done }.count
        let partial = sessions.filter { $0.outcome == .partial }.count
        let plannedMinutes = sessions.reduce(0) { total, session in
            total + Int(ceil(Double(session.plannedSeconds) / 60.0))
        }
        return "\(sessions.count) pomodoros - \(completed) done, \(partial) partial - \(plannedMinutes) planned minutes"
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        sessions.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard sessions.indices.contains(row), let tableColumn else { return nil }

        let cellIdentifier = NSUserInterfaceItemIdentifier("cell-\(tableColumn.identifier.rawValue)")
        let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: self) as? NSTableCellView ?? makeCell(identifier: cellIdentifier)
        cell.textField?.stringValue = value(for: tableColumn.identifier, session: sessions[row])
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier

        let field = NSTextField(labelWithString: "")
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

    private func value(for column: NSUserInterfaceItemIdentifier, session: PomodoroSession) -> String {
        switch column {
        case ColumnID.started:
            return startedFormatter.string(from: session.startedAt)
        case ColumnID.duration:
            return "\(Int(ceil(Double(session.plannedSeconds) / 60.0)))"
        case ColumnID.outcome:
            return session.outcome.title
        case ColumnID.intention:
            return displayText(session.intention)
        case ColumnID.review:
            return displayText(session.review)
        default:
            return ""
        }
    }

    private func displayText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
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
        Planned: \(Int(ceil(Double(session.plannedSeconds) / 60.0))) minutes
        Did you do it?: \(session.outcome.title)

        Doing:
        \(displayText(session.intention))

        What happened:
        \(displayText(session.review))
        """
    }

    @objc private func closeWindow() {
        close()
    }
}
