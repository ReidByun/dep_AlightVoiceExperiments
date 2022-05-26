//
//  ContentView.swift
//  AudioExperiments
//
//  Created by temphee Reid on 2022/05/18.
//

import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = PlayerViewModel()
    
    var body: some View {
        VStack {
            Image.artwork
                .resizable() 
                .aspectRatio(
                    nil,
                    contentMode: .fit)
                .padding()
                .layoutPriority(1)
            
            PlayerControlView
                .padding(.bottom)
        }
    }
    
    private var PlayerControlView: some View {
        VStack {
            SliderBarView(value: $viewModel.playerProgress, isEditing: $viewModel.isScrubbing)
                .padding(.bottom, 8)
                .frame(height: 40)
//            ProgressBarView(value: $viewModel.playerProgress)
//                .padding(.bottom, 8)
//                .frame(height: 10)
            
//            ProgressView(value: viewModel.playerProgress)
//                .progressViewStyle(
//                    LinearProgressViewStyle(tint: .blue))
//                .padding(.bottom, 8)
            
            HStack {
                Text(viewModel.playerTime.elapsedText)
                
                Spacer()
                
                Text(viewModel.playerTime.remainingText)
            }
            .font(.system(size: 14, weight: .semibold))
            
            //Spacer()
            
            AudioControlButtonsView
                .disabled(!viewModel.isPlayerReady)
                .padding(.bottom)
            
        }
        .padding(.horizontal)
    }
    
    private var AudioControlButtonsView: some View {
        HStack(spacing: 20) {
            Spacer()
            
            Button {
                viewModel.skip(forwards: false)
            } label: {
                Image.backward
            }
            .font(.system(size: 32))
            
            Spacer()
            
            Button {
                viewModel.playOrPause()
            } label: {
                ZStack {
                    Color.blue
                        .frame(
                            width: 10,
                            height: 35 * CGFloat(viewModel.meterLevel))
                        .opacity(0.5)
                    
                    viewModel.isPlaying ? Image.pause : Image.play
                }
            }
            .frame(width: 40)
            .font(.system(size: 45))
            
            Spacer()
            
            Button {
                viewModel.skip(forwards: true)
            } label: {
                Image.forward
            }
            .font(.system(size: 32))
            
            Spacer()
        }
        .foregroundColor(.primary)
        .padding(.vertical, 20)
        .frame(height: 58)
    }
}

fileprivate struct SliderBarView: View {
    @Binding var value: Double
    //@State private var isEditing = false
    @Binding var isEditing: Bool


    var body: some View {
        VStack {
            Slider(
                value: $value,
                in: 0...100,
                onEditingChanged: { editing in
                    isEditing = editing
                    
                }
            )
            Text("\(value)")
                .foregroundColor(isEditing ? .red : .blue)
        }
    }
}



fileprivate struct ProgressBarView: View {
    @Binding var value: Double
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().frame(width: geometry.size.width , height: geometry.size.height)
                    .foregroundColor(Color(UIColor.systemTeal))
                
                Rectangle().frame(width: min(CGFloat(self.value)*geometry.size.width, geometry.size.width), height: geometry.size.height)
                    .foregroundColor(Color(UIColor.blue))
                    .animation(.linear)
            }.cornerRadius(22)
        }
    }
}




struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
