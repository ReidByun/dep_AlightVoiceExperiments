//
//  TrackableScrollView.swift
//  AudioExperiments
//
//  Created by Reid Byun on 2022/06/07.
//

import SwiftUI

@available(iOS 13.0, *)
struct ScrollOffsetPreferenceKey: PreferenceKey {
    typealias Value = [CGFloat]
    
    static var defaultValue: [CGFloat] = [0]
    
    static func reduce(value: inout [CGFloat], nextValue: () -> [CGFloat]) {
        value.append(contentsOf: nextValue())
    }
}

@available(iOS 13.0, *)
public struct TrackableScrollView<Content>: View where Content: View {
    let axes: Axis.Set
    let showIndicators: Bool
    @Binding var contentOffset: CGFloat
    let content: Content
    
    public init(_ axes: Axis.Set = .vertical, showIndicators: Bool = true, contentOffset: Binding<CGFloat>, @ViewBuilder content: () -> Content) {
        self.axes = axes
        self.showIndicators = showIndicators
        self._contentOffset = contentOffset
        self.content = content()
    }
    
    public var body: some View {
//        ScrollViewReader { reader in
        GeometryReader { outsideProxy in
            ScrollView(self.axes, showsIndicators: self.showIndicators) {
                ZStack(alignment: self.axes == .vertical ? .top : .leading) {
                    GeometryReader { insideProxy in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self, value: [self.calculateContentOffset(fromOutsideProxy: outsideProxy, insideProxy: insideProxy)])
                    }
                    VStack {
                        self.content
                    }
                }
            }
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                self.contentOffset = value[0]
            }
//            .onAppear {
//                reader.scrollTo(2, anchor: .topLeading)
//            }
        }
//        }
    }
    
    private func calculateContentOffset(fromOutsideProxy outsideProxy: GeometryProxy, insideProxy: GeometryProxy) -> CGFloat {
        if axes == .vertical {
            return outsideProxy.frame(in: .global).minY - insideProxy.frame(in: .global).minY
        } else {
            return outsideProxy.frame(in: .global).minX - insideProxy.frame(in: .global).minX
        }
    }
}



// Our custom view modifier to track rotation and
// call our action
struct DeviceRotationViewModifier: ViewModifier {
    let action: (UIDeviceOrientation) -> Void

    func body(content: Content) -> some View {
        content
            .onAppear()
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                action(UIDevice.current.orientation)
            }
    }
}

// A View wrapper to make the modifier easier to use
extension View {
    func onRotate(perform action: @escaping (UIDeviceOrientation) -> Void) -> some View {
        self.modifier(DeviceRotationViewModifier(action: action))
    }
}



struct TestHorizontalScrollView: View {
    @State private var scrollViewContentOffset = CGFloat(0)
    @State var screenSize: CGRect = UIScreen.main.bounds
    @State private var orientation = UIDeviceOrientation.unknown
    
    
    var body: some View {
        ScrollViewReader { proxy in
        VStack {
            Text("off: \(Int(scrollViewContentOffset))")
            ZStack {
                TrackableScrollView(.horizontal, showIndicators: false, contentOffset: $scrollViewContentOffset) {
                    ZStack {
                        Color.clear
                            .frame(width: screenSize.width*2, height: 60)
                        HStack(spacing: 0) {
                            Color.black
                                .frame(width: screenSize.width/2, height: 60)
                            Color.green
                                .frame(width: screenSize.width, height: 60)
                            Color.black
                                .frame(width: screenSize.width/2, height: 60)
                                .id(3)  //Set the Id
                        }
                        //.offset(x: 30)
                        
                    }
                }
                
                VStack(spacing: 0) {
                    Color.black
                        .frame(width: 3, height: 100)
                }
            }
        }
        .onTapGesture {
            print("tap")
            proxy.scrollTo(3)
            
        }
        .onRotate { newOrientation in
            orientation = newOrientation
            screenSize = UIScreen.main.bounds
        }
        .onAppear {
            proxy.scrollTo(2, anchor: .leading)
        }
        .ignoresSafeArea()
        }
    }
}



//////
///
///
///
///
public enum ScrollDirection {
    case top
    case center
    case bottom
}

public extension UIScrollView {

    func scroll(to direction: ScrollDirection) {

        DispatchQueue.main.async {
            switch direction {
            case .top:
                self.scrollToTop()
            case .center:
                self.scrollToCenter()
            case .bottom:
                self.scrollToBottom()
            }
        }
    }

    private func scrollToTop() {
        setContentOffset(.zero, animated: true)
    }

    private func scrollToCenter() {
        let centerOffset = CGPoint(x: 0, y: (contentSize.height - bounds.size.height) / 2)
        setContentOffset(centerOffset, animated: true)
    }

    private func scrollToBottom() {
        let bottomOffset = CGPoint(x: 0, y: contentSize.height - bounds.size.height + contentInset.bottom)
        if(bottomOffset.y > 0) {
            setContentOffset(bottomOffset, animated: true)
        }
    }
}
