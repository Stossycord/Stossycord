//
//  ScrollView.swift
//  Stossycord
//
//  Created by Stossy11 on 30/12/2025.
//

import SwiftUI
#if canImport(UIKit)
import UIKit


struct UIKitScrollView<Content: View>: UIViewRepresentable {
    enum AnchorPosition {
        case top
        case bottom
    }
    
    let anchorTo: AnchorPosition
    let content: ((@escaping (String) -> Void) -> Content)
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        
        let hc = context.coordinator.hostingController
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 16.0, *) {
            hc.sizingOptions = [.intrinsicContentSize]
        }
        
        scrollView.addSubview(hc.view)
        
        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hc.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hc.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            hc.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        context.coordinator.setupObservation(for: scrollView)
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        let scrollTo = context.coordinator.makeScrollTo(scrollView: scrollView)
        context.coordinator.hostingController.rootView = content(scrollTo)
        
        context.coordinator.hostingController.view.invalidateIntrinsicContentSize()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, anchorTo: anchorTo)
    }
    
    class Coordinator: NSObject {
        var hostingController: UIHostingController<Content>
        var anchorTo: AnchorPosition
        var hasAnchored = false
        private var observation: NSKeyValueObservation?
        
        init(content: @escaping (@escaping (String) -> Void) -> Content, anchorTo: AnchorPosition) {
            self.anchorTo = anchorTo
            self.hostingController = UIHostingController(rootView: content({ _ in }))
        }
        
        func setupObservation(for scrollView: UIScrollView) {
            observation = scrollView.observe(\.contentSize, options: [.new]) { [weak self] scrollView, change in
                guard let self = self, !self.hasAnchored else { return }
                
                let newSize = change.newValue?.height ?? 0
                
                if newSize > 0 {
                    self.applyAnchor(scrollView: scrollView)
                }
            }
        }
        
        private func applyAnchor(scrollView: UIScrollView) {
            DispatchQueue.main.async {
                switch self.anchorTo {
                case .top:
                    scrollView.setContentOffset(.zero, animated: false)
                case .bottom:
                    let bottomOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                    scrollView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: false)
                }

                self.hasAnchored = true
            }
        }
        
        func makeScrollTo(scrollView: UIScrollView) -> (String) -> Void {
            return { [weak self, weak scrollView] id in
                guard let self = self, let scrollView = scrollView else { return }
                

                DispatchQueue.main.async {
                    if let target = self.findView(id: id, in: scrollView) {
                        print("found \(id)")
                        
                        let targetRect = target.convert(target.bounds, to: scrollView)
                        
        
                        let targetBottomY = targetRect.maxY
                        let scrollViewHeight = scrollView.bounds.height
                        
                        var targetOffsetY = targetBottomY - scrollViewHeight
                        
                        let maxOffsetY = scrollView.contentSize.height - scrollView.bounds.height
                        targetOffsetY = max(0, min(targetOffsetY, maxOffsetY))
                        
                        scrollView.setContentOffset(CGPoint(x: 0, y: targetOffsetY), animated: true)
                        
                    } else {
                        print("not found \(id)")
                    }
                }
            }
        }
        
        private func findView(id: String, in view: UIView) -> UIView? {
            if view.accessibilityIdentifier == id { return view }
            
            if let idValue = Mirror(reflecting: view).descendant("id") as? String,
               idValue == id {
                return view
            }
            
            for subview in view.subviews {
                if let found = findView(id: id, in: subview) { return found }
            }
            return nil
        }
    }
}
#elseif canImport(AppKit)
import SwiftUI
import AppKit

struct UIKitScrollView<Content: View>: NSViewRepresentable {
    enum AnchorPosition {
        case top
        case bottom
    }
    
    let anchorTo: AnchorPosition
    let content: ((@escaping (String) -> Void) -> Content)
    
    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        
        let hostingView = context.coordinator.hostingView
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        
        // In AppKit, we set the documentView
        scrollView.documentView = hostingView
        
        // Constraint to ensure the content matches the width of the scroll view
        if let clipView = scrollView.contentView as? NSClipView {
            NSLayoutConstraint.activate([
                hostingView.leadingAnchor.constraint(equalTo: clipView.leadingAnchor),
                hostingView.trailingAnchor.constraint(equalTo: clipView.trailingAnchor),
                hostingView.topAnchor.constraint(equalTo: clipView.topAnchor)
            ])
        }
        
        context.coordinator.setupObservation(for: scrollView)
        
        return scrollView
    }
    
    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        let scrollTo = context.coordinator.makeScrollTo(scrollView: scrollView)
        context.coordinator.hostingView.rootView = content(scrollTo)
        
        context.coordinator.hostingView.needsLayout = true
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, anchorTo: anchorTo)
    }
    
    class Coordinator: NSObject {
        var hostingView: NSHostingView<Content>
        var anchorTo: AnchorPosition
        var hasAnchored = false
        private var observation: NSKeyValueObservation?
        
        init(content: @escaping (@escaping (String) -> Void) -> Content, anchorTo: AnchorPosition) {
            self.anchorTo = anchorTo
            self.hostingView = NSHostingView(rootView: content({ _ in }))
        }
        
        func setupObservation(for scrollView: NSScrollView) {
            observation = scrollView.documentView?.observe(\.frame, options: [.new]) { [weak self] _, _ in
                guard let self = self, !self.hasAnchored else { return }
                self.applyAnchor(scrollView: scrollView)
            }
        }
        
        private func applyAnchor(scrollView: NSScrollView) {
            DispatchQueue.main.async {
                guard let documentView = scrollView.documentView else { return }
                
                let contentHeight = documentView.frame.height
                if contentHeight > 0 {
                    switch self.anchorTo {
                    case .top:
                        scrollView.contentView.scroll(to: NSPoint(x: 0, y: documentView.isFlipped ? 0 : contentHeight))
                    case .bottom:
                        let bottomPoint = NSPoint(x: 0, y: documentView.isFlipped ? contentHeight : 0)
                        scrollView.contentView.scroll(to: bottomPoint)
                    }
                    self.hasAnchored = true
                }
            }
        }
        
        func makeScrollTo(scrollView: NSScrollView) -> (String) -> Void {
            return { [weak self, weak scrollView] id in
                guard let self = self, let scrollView = scrollView, let documentView = scrollView.documentView else { return }
                
                DispatchQueue.main.async {
                    if let target = self.findView(id: id, in: documentView) {
                        let targetRect = target.convert(target.bounds, to: documentView)
                        
                        target.scrollToVisible(target.bounds)
                    }
                }
            }
        }
        
        private func findView(id: String, in view: NSView) -> NSView? {
            if view.identifier?.rawValue == id { return view }
            
            
            if view.accessibilityIdentifier() == id { return view }
            
            // Mirror check for SwiftUI internal IDs if accessibilityIdentifier isn't used
            if let idValue = Mirror(reflecting: view).descendant("id") as? String,
               idValue == id {
                return view
            }
            
            for subview in view.subviews {
                if let found = findView(id: id, in: subview) { return found }
            }
            return nil
        }
    }
}
#endif
