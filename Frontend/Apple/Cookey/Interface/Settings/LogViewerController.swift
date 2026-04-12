import AlertController
import SnapKit
import UIKit

final class LogViewerController: UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchResultsUpdating {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let searchController = UISearchController(searchResultsController: nil)

    private var hasShownWarning = false
    private var allLines: [LogLine] = []
    private var filteredLines: [LogLine] = []

    private var selectedLevels: Set<LogLevel> = [.debug, .info, .error]
    private var selectedCategories: Set<String> = []
    private var allCategories: Set<String> = []

    private var isSearching: Bool {
        let text = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return searchController.isActive && !text.isEmpty
    }

    private var displayLines: [LogLine] {
        isSearching ? filteredLines : allLines
    }

    struct LogLine {
        let timestamp: String
        let level: LogLevel
        let category: String
        let message: String
        let fullText: String

        init?(from line: String) {
            guard !line.isEmpty else { return nil }

            let components = line.components(separatedBy: " ")
            if components.count >= 4,
               components[0].contains("T"),
               components[1].hasPrefix("["),
               components[1].hasSuffix("]"),
               components[2].hasPrefix("["),
               components[2].hasSuffix("]")
            {
                timestamp = components[0]
                let levelString = components[1].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                level = LogLevel(rawValue: levelString) ?? .info
                category = components[2].trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                message = components.dropFirst(3).joined(separator: " ")
                fullText = line
            } else {
                timestamp = ""
                level = .info
                category = "System"
                message = line
                fullText = line
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Logs")
        view.backgroundColor = .systemBackground

        setupSearchController()
        setupMenuButton()
        setupTableView()
        reload()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasShownWarning else { return }
        hasShownWarning = true
        let alert = AlertViewController(
            title: String(localized: "Sensitive Data Warning"),
            message: String(localized: "Logs may contain sensitive information such as session tokens and request details. Sharing or taking screenshots could expose your credentials."),
        ) { context in
            context.addAction(title: String(localized: "OK"), attribute: .dangerous) {
                context.dispose()
            }
        }
        present(alert, animated: true)
    }

    private func setupSearchController() {
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = String(localized: "Search logs...")
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
    }

    private func setupMenuButton() {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "ellipsis.circle"), for: .normal)
        button.showsMenuAsPrimaryAction = true
        button.menu = createMenu()
        button.frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: button)
    }

    private func createMenu() -> UIMenu {
        let levelActions = LogLevel.allCases.map { level in
            UIAction(
                title: level.rawValue,
                image: selectedLevels.contains(level) ? UIImage(systemName: "checkmark") : nil,
            ) { [weak self] _ in
                self?.toggleLevel(level)
            }
        }
        let levelMenu = UIMenu(
            title: String(localized: "Filter by Level"),
            image: UIImage(systemName: "slider.horizontal.3"),
            children: levelActions,
        )

        let categoryActions: [UIAction]
        if allCategories.isEmpty {
            categoryActions = [
                UIAction(title: String(localized: "No categories")) { _ in },
            ]
        } else {
            var actions = [
                UIAction(
                    title: String(localized: "All Categories"),
                    image: selectedCategories.isEmpty ? UIImage(systemName: "checkmark") : nil,
                ) { [weak self] _ in
                    self?.selectedCategories.removeAll()
                    self?.applyFilters()
                    self?.updateMenu()
                },
            ]
            actions.append(contentsOf: allCategories.sorted().map { category in
                UIAction(
                    title: category,
                    image: selectedCategories.contains(category) ? UIImage(systemName: "checkmark") : nil,
                ) { [weak self] _ in
                    self?.toggleCategory(category)
                }
            })
            categoryActions = actions
        }
        let categoryMenu = UIMenu(
            title: String(localized: "Filter by Category"),
            image: UIImage(systemName: "tag"),
            children: categoryActions,
        )

        let refreshAction = UIAction(
            title: String(localized: "Refresh"),
            image: UIImage(systemName: "arrow.clockwise"),
        ) { [weak self] _ in
            self?.reload()
        }

        let shareAction = UIAction(
            title: String(localized: "Share"),
            image: UIImage(systemName: "square.and.arrow.up"),
        ) { [weak self] _ in
            self?.shareLog()
        }

        let clearAction = UIAction(
            title: String(localized: "Clear"),
            image: UIImage(systemName: "trash"),
            attributes: .destructive,
        ) { [weak self] _ in
            self?.clearLog()
        }

        return UIMenu(children: [
            levelMenu,
            categoryMenu,
            UIMenu(options: .displayInline, children: [refreshAction]),
            UIMenu(options: .displayInline, children: [shareAction, clearAction]),
        ])
    }

    private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .singleLine
        tableView.backgroundColor = .systemBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    private func toggleLevel(_ level: LogLevel) {
        if selectedLevels.contains(level) {
            selectedLevels.remove(level)
        } else {
            selectedLevels.insert(level)
        }
        applyFilters()
        updateMenu()
    }

    private func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        applyFilters()
        updateMenu()
    }

    private func updateMenu() {
        guard let button = navigationItem.rightBarButtonItem?.customView as? UIButton else { return }
        button.menu = createMenu()
    }

    private func applyFilters() {
        allLines = parseLogLines()
        if isSearching {
            updateSearchResults(for: searchController)
        } else {
            filteredLines = []
        }
        updateBackgroundView()
        tableView.reloadData()
        scrollToBottom()
    }

    private func parseLogLines() -> [LogLine] {
        let text = LogStore.shared.readTail(maxBytes: 512 * 1024)
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        var parsedLines: [LogLine] = []
        var categories = Set<String>()

        for line in lines {
            guard let logLine = LogLine(from: line) else { continue }
            categories.insert(logLine.category)

            guard selectedLevels.contains(logLine.level) else { continue }
            if !selectedCategories.isEmpty, !selectedCategories.contains(logLine.category) {
                continue
            }
            parsedLines.append(logLine)
        }

        allCategories = categories
        return parsedLines
    }

    private func updateBackgroundView() {
        guard displayLines.isEmpty else {
            tableView.backgroundView = nil
            return
        }

        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .body)
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.text = isSearching
            ? String(localized: "No matching logs.")
            : String(localized: "No logs yet.")
        tableView.backgroundView = label
    }

    @objc private func reload() {
        applyFilters()
        updateMenu()
    }

    @objc private func shareLog() {
        let text = LogStore.shared.readTail(maxBytes: 512 * 1024)
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("Cookey-Logs-\(UUID().uuidString)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let fileURL = directory.appendingPathComponent("cookey-logs.txt")
            try Data(text.utf8).write(to: fileURL, options: .atomic)

            let controller = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            controller.completionWithItemsHandler = { _, _, _, _ in
                try? FileManager.default.removeItem(at: directory)
            }
            present(controller, animated: true)
        } catch {
            let controller = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            if let popover = controller.popoverPresentationController {
                popover.sourceView = view
                popover.sourceRect = view.bounds
            }
            present(controller, animated: true)
        }
    }

    @objc private func clearLog() {
        LogStore.shared.clear()
        reload()
    }

    private func scrollToBottom() {
        guard !displayLines.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let indexPath = IndexPath(row: displayLines.count - 1, section: 0)
            tableView.scrollToRow(at: indexPath, at: .bottom, animated: false)
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard let searchText = searchController.searchBar.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !searchText.isEmpty
        else {
            filteredLines = []
            updateBackgroundView()
            tableView.reloadData()
            return
        }

        let query = searchText.localizedLowercase
        filteredLines = allLines.filter { line in
            line.fullText.localizedLowercase.contains(query)
        }
        updateBackgroundView()
        tableView.reloadData()
    }

    func numberOfSections(in _: UITableView) -> Int {
        1
    }

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        displayLines.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let identifier = "LogCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: identifier) ?? UITableViewCell(
            style: .subtitle,
            reuseIdentifier: identifier,
        )

        let logLine = displayLines[indexPath.row]
        cell.textLabel?.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        cell.textLabel?.numberOfLines = 0
        cell.textLabel?.text = logLine.message
        cell.textLabel?.textColor = color(for: logLine.level)

        cell.detailTextLabel?.font = .monospacedSystemFont(ofSize: 9, weight: .regular)
        cell.detailTextLabel?.numberOfLines = 1
        cell.detailTextLabel?.textColor = .secondaryLabel
        cell.detailTextLabel?.text = logLine.timestamp.isEmpty
            ? logLine.category
            : "\(logLine.timestamp) • \(logLine.category)"
        cell.backgroundColor = .systemBackground
        return cell
    }

    private func color(for level: LogLevel) -> UIColor {
        switch level {
        case .debug:
            .secondaryLabel
        case .info:
            .label
        case .error:
            .systemRed
        }
    }
}
