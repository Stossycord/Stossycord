//
//  NavigationSplitViewBackport.swift
//  Stossycord
//
//  Created by Stossy11 on 26/1/2026.
//

import SwiftUI
import UIKit

struct NavigationSplitViewBackport<Sidebar: View, Detail: View>: UIViewControllerRepresentable {
    @Binding var columnVisibility: NavigationSplitViewVisibilityBackport
    let sidebar: () -> Sidebar
    let detail: () -> Detail
    
    init(
        columnVisibility: Binding<NavigationSplitViewVisibilityBackport>,
        @ViewBuilder sidebar: @escaping () -> Sidebar,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self._columnVisibility = columnVisibility
        self.sidebar = sidebar
        self.detail = detail
    }
    
    func makeUIViewController(context: Context) -> BackportSplitViewController {
        let controller = BackportSplitViewController(
            sidebar: sidebar,
            detail: detail,
            columnVisibility: $columnVisibility
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: BackportSplitViewController, context: Context) {
        uiViewController.columnVisibility = columnVisibility
        uiViewController.updateDetail(detail())
    }
}

enum NavigationSplitViewVisibilityBackport {
    case automatic
    case all
    case detailOnly
    case doubleColumn

    @available(iOS 16.0, *)
    static func convertToNavigationViewVisibility(
        _ visibility: Binding<NavigationSplitViewVisibilityBackport>
    ) -> Binding<NavigationSplitViewVisibility> {

        Binding(
            get: {
                switch visibility.wrappedValue {
                case .automatic:
                    return .automatic
                case .all:
                    return .all
                case .detailOnly:
                    return .detailOnly
                case .doubleColumn:
                    return .doubleColumn
                }
            },
            set: { val in
                switch val {
                case .automatic:
                    visibility.wrappedValue = .automatic
                case .all:
                    visibility.wrappedValue = .all
                case .detailOnly:
                    visibility.wrappedValue = .detailOnly
                case .doubleColumn:
                    visibility.wrappedValue = .doubleColumn
                default:
                    visibility.wrappedValue = .automatic
                }
            }
        )
    }
}

class BackportSplitViewController: UISplitViewController {
    private var sidebarContent: AnyView
    private var detailContent: AnyView
    @Binding var columnVisibility: NavigationSplitViewVisibilityBackport
    
    var columnVisibilityInternal: NavigationSplitViewVisibilityBackport {
        didSet {
            updateSidebarVisibility()
        }
    }
    
    init<S: View, D: View>(
        sidebar: () -> S,
        detail: () -> D,
        columnVisibility: Binding<NavigationSplitViewVisibilityBackport>
    ) {
        self.sidebarContent = AnyView(sidebar())
        self.detailContent = AnyView(detail())
        self._columnVisibility = columnVisibility
        self.columnVisibilityInternal = columnVisibility.wrappedValue
        
        if #available(iOS 14.0, *) {
            super.init(style: .doubleColumn)
        } else {
            super.init(nibName: nil, bundle: nil)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        preferredDisplayMode = .oneBesideSecondary
        if #available(iOS 14.0, *) {
            preferredSplitBehavior = .tile
        }
        
        let sidebarHosting = UIHostingController(rootView: sidebarContent)
        let sidebarNav = UINavigationController(rootViewController: sidebarHosting)
        setViewController(sidebarNav, for: .primary)
        
        // Setup detail
        let detailHosting = UIHostingController(rootView: detailContent)
        let detailNav = UINavigationController(rootViewController: detailHosting)
        setViewController(detailNav, for: .secondary)
        
        delegate = self
        
        updateSidebarVisibility()
    }
    
    func updateDetail<D: View>(_ detail: D) {
        detailContent = AnyView(detail)
        let detailHosting = UIHostingController(rootView: detailContent)
        let detailNav = UINavigationController(rootViewController: detailHosting)
        setViewController(detailNav, for: .secondary)
    }
    
    private func updateSidebarVisibility() {
        // Sync internal state with binding
        if columnVisibilityInternal != columnVisibility {
            columnVisibility = columnVisibilityInternal
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            switch self.columnVisibilityInternal {
            case .all, .doubleColumn, .automatic:
                self.preferredDisplayMode = .oneBesideSecondary
                self.show(.primary)
            case .detailOnly:
                self.preferredDisplayMode = .secondaryOnly
                self.hide(.primary)
            }
        })
    }
}

extension BackportSplitViewController: UISplitViewControllerDelegate {
    func splitViewController(
        _ svc: UISplitViewController,
        topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column
    ) -> UISplitViewController.Column {
        return .primary
    }
    
    func splitViewControllerDidCollapse(_ svc: UISplitViewController) {
        columnVisibilityInternal = .detailOnly
    }
    
    func splitViewControllerDidExpand(_ svc: UISplitViewController) {
        columnVisibilityInternal = .all
    }
}
