import ConfigurableKit
import SnapKit
import UIKit

final class TrustedPublicKeysViewController: UITableViewController, UISearchResultsUpdating {
    private let searchController = UISearchController(searchResultsController: nil)

    private lazy var actionsButton = UIBarButtonItem(
        image: UIImage(systemName: "ellipsis.circle"),
        menu: buildActionsMenu(),
    )

    private lazy var doneButton = UIBarButtonItem(
        title: String(localized: "Done"),
        style: .done,
        target: self,
        action: #selector(exitEditingMode),
    )

    private lazy var dataSource = UITableViewDiffableDataSource<Int, UUID>(
        tableView: tableView,
    ) { [weak self] (tableView: UITableView, _: IndexPath, itemID: UUID) in
        guard let self, let item = item(for: itemID) else {
            return UITableViewCell()
        }

        let cellID = "TrustedPublicKeyCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID)
            ?? UITableViewCell(style: .default, reuseIdentifier: cellID)

        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.backgroundColor = .clear

        let configurableView = ConfigurableView()
        configurableView.translatesAutoresizingMaskIntoConstraints = false
        configurableView.isUserInteractionEnabled = false
        configurableView.configure(icon: .image(optionalName: "key.fill"))
        configurableView.configure(title: String.LocalizationValue(stringLiteral: item.titleText))
        configurableView.configure(description: String.LocalizationValue(stringLiteral: item.detailText))

        cell.contentView.addSubview(configurableView)
        configurableView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }

        let editingBackground = UIView()
        editingBackground.backgroundColor = .systemGray5
        cell.multipleSelectionBackgroundView = editingBackground

        return cell
    }

    private var allItems: [TrustedKeyListItem] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        title = String(localized: "Trusted Public Keys")
        view.backgroundColor = .systemBackground
        tableView.backgroundColor = .systemBackground
        tableView.separatorStyle = .singleLine
        tableView.separatorInset = .zero
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60

        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.hidesNavigationBarDuringPresentation = false
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.autocorrectionType = .no
        searchController.searchBar.placeholder = String(localized: "Search")
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        if #available(iOS 16.0, *) {
            navigationItem.preferredSearchBarPlacement = .stacked
        }

        rebuildNavigationItems()
        reloadItems(animated: false)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadItems(animated: false)
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        tableView.setEditing(editing, animated: animated)
        rebuildNavigationItems()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            rebuildNavigationItems()
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, didDeselectRowAt _: IndexPath) {
        if tableView.isEditing {
            rebuildNavigationItems()
        }
    }

    override func tableView(
        _: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath,
    ) -> UISwipeActionsConfiguration? {
        guard !tableView.isEditing,
              let itemID = dataSource.itemIdentifier(for: indexPath)
        else { return nil }

        let delete = UIContextualAction(
            style: .destructive,
            title: String(localized: "Delete"),
        ) { [weak self] _, _, completion in
            self?.deleteItems(with: [itemID], animated: true)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")

        return UISwipeActionsConfiguration(actions: [delete])
    }

    override func tableView(
        _: UITableView,
        contextMenuConfigurationForRowAt indexPath: IndexPath,
        point _: CGPoint,
    ) -> UIContextMenuConfiguration? {
        guard !tableView.isEditing,
              let itemID = dataSource.itemIdentifier(for: indexPath)
        else { return nil }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            UIMenu(children: [
                UIAction(
                    title: String(localized: "Delete"),
                    image: UIImage(systemName: "trash"),
                    attributes: [.destructive],
                ) { _ in
                    self?.deleteItems(with: [itemID], animated: true)
                },
            ])
        }
    }

    func updateSearchResults(for _: UISearchController) {
        applySnapshot(animated: false)
    }

    private func reloadItems(animated: Bool) {
        allItems = TrustedKeyStore.allTrusted().map { TrustedKeyListItem($0) }
        applySnapshot(animated: animated)
    }

    private func applySnapshot(animated: Bool) {
        var snapshot = NSDiffableDataSourceSnapshot<Int, UUID>()
        snapshot.appendSections([0])
        snapshot.appendItems(filteredItems().map(\.id), toSection: 0)
        dataSource.apply(snapshot, animatingDifferences: animated)
        rebuildNavigationItems()
    }

    private func filteredItems() -> [TrustedKeyListItem] {
        let query = searchController.searchBar.text?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else { return allItems }
        return allItems.filter { $0.matches(query: query) }
    }

    private func item(for id: UUID) -> TrustedKeyListItem? {
        allItems.first { $0.id == id }
    }

    private func buildActionsMenu() -> UIMenu {
        UIMenu(children: [
            UIAction(
                title: String(localized: "Select"),
                image: UIImage(systemName: "checkmark.circle"),
            ) { [weak self] _ in
                self?.setEditing(true, animated: true)
            },
        ])
    }

    private func rebuildNavigationItems() {
        if tableView.isEditing {
            let selectedCount = tableView.indexPathsForSelectedRows?.count ?? 0
            navigationItem.leftBarButtonItem = selectedCount > 0
                ? UIBarButtonItem(
                    title: deleteButtonTitle(for: selectedCount),
                    style: .plain,
                    target: self,
                    action: #selector(deleteSelectedItems),
                )
                : nil
            navigationItem.leftBarButtonItem?.tintColor = .systemRed
            navigationItem.rightBarButtonItem = doneButton
        } else {
            navigationItem.leftBarButtonItem = nil
            actionsButton.menu = buildActionsMenu()
            navigationItem.rightBarButtonItem = actionsButton
        }
    }

    private func deleteButtonTitle(for count: Int) -> String {
        guard count > 0 else { return String(localized: "Delete") }
        return String.localizedStringWithFormat(
            String(localized: "Delete (%lld)"),
            count,
        )
    }

    @objc private func exitEditingMode() {
        setEditing(false, animated: true)
    }

    @objc private func deleteSelectedItems() {
        let ids = Set(
            (tableView.indexPathsForSelectedRows ?? []).compactMap {
                dataSource.itemIdentifier(for: $0)
            },
        )
        guard !ids.isEmpty else { return }

        let alert = UIAlertController(
            title: String.localizedStringWithFormat(
                String(localized: "Delete %lld Item(s)?"),
                ids.count,
            ),
            message: String(localized: "This action cannot be undone."),
            preferredStyle: .actionSheet,
        )
        alert.addAction(UIAlertAction(
            title: String(localized: "Delete"),
            style: .destructive,
        ) { [weak self] _ in
            self?.deleteItems(with: ids, animated: true)
            self?.setEditing(false, animated: true)
        })
        alert.addAction(UIAlertAction(title: String(localized: "Cancel"), style: .cancel))
        alert.popoverPresentationController?.barButtonItem = navigationItem.leftBarButtonItem
        present(alert, animated: true)
    }

    private func deleteItems(with ids: Set<UUID>, animated: Bool) {
        for item in allItems where ids.contains(item.id) {
            TrustedKeyStore.remove(deviceID: item.trustedCLI.deviceID)
        }
        reloadItems(animated: animated)
    }
}
