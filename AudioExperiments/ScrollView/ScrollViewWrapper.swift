//
//  ScrollViewWrapper.swift
//  AudioExperiments
//
//  Created by Reid Byun on 2022/06/07.
//

import SwiftUI

import SwiftUI

public struct ScrollViewWrapper<Content: View>: UIViewRepresentable {
    @Binding var contentOffset: CGPoint
    let content: () -> Content
    
    public init(contentOffset: Binding<CGPoint>, @ViewBuilder _ content: @escaping () -> Content) {
        self._contentOffset = contentOffset
        self.content = content
    }
    
    public func makeUIView(context: UIViewRepresentableContext<ScrollViewWrapper>) -> UIScrollView {
        let view = UIScrollView()
        view.delegate = context.coordinator
        
        let controller = UIHostingController(rootView: content())
        controller.view.sizeToFit()
                
        view.addSubview(controller.view)
        view.contentSize = controller.view.bounds.size
        
        return view
    }
    
    public func updateUIView(_ uiView: UIScrollView, context: UIViewRepresentableContext<ScrollViewWrapper>) {
//        uiView.showsVerticalScrollIndicator = false
        uiView.contentOffset = self.contentOffset
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(contentOffset: self._contentOffset)
    }
    
    public class Coordinator: NSObject, UIScrollViewDelegate {
        let contentOffset: Binding<CGPoint>
        
        init(contentOffset: Binding<CGPoint>) {
            self.contentOffset = contentOffset
        }
        
        public func scrollViewDidScroll(_ scrollView: UIScrollView) {
            contentOffset.wrappedValue = scrollView.contentOffset
            //scrollView.setContentOffset(<#T##contentOffset: CGPoint##CGPoint#>, animated: <#T##Bool#>)
        }
        
        public func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            print("beggin Dragging")
        }
        
        public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            print("scrollView Did End Dragging")
        }
        
        public func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) {
            print("scrollView Will End Dragging")
        }
    }
}

//
//private struct ScrollOffsetPreferenceKey: PreferenceKey {
//    static var defaultValue: CGPoint = .zero
//
//    static func reduce(value: inout CGPoint, nextValue: () -> CGPoint) {}
//}


//struct ScrollView<Content: View>: View {
//    let axes: Axis.Set
//    let showsIndicators: Bool
//    let offsetChanged: (CGPoint) -> Void
//    let content: Content
//
//    init(
//        axes: Axis.Set = .vertical,
//        showsIndicators: Bool = true,
//        offsetChanged: @escaping (CGPoint) -> Void = { _ in },
//        @ViewBuilder content: () -> Content
//    ) {
//        self.axes = axes
//        self.showsIndicators = showsIndicators
//        self.offsetChanged = offsetChanged
//        self.content = content()
//    }
//    
//    var body: some View {
//        SwiftUI.ScrollView(axes, showsIndicators: showsIndicators) {
//            GeometryReader { geometry in
//                Color.clear.preference(
//                    key: ScrollOffsetPreferenceKey.self,
//                    value: geometry.frame(in: .named("scrollView")).origin
//                )
//            }.frame(width: 0, height: 0)
//            content
//        }
//        .coordinateSpace(name: "scrollView")
//        .onPreferenceChange(ScrollOffsetPreferenceKey.self, perform: offsetChanged)
//    }
//}
