//
//  AudioPlayerViewModel.swift
//  AudioExperiments
//
//  Created by temphee Reid on 2022/05/18.
//

import Foundation
import SwiftUI
import AVFoundation

class PlayerViewModel: NSObject, ObservableObject {
    var isPlaying = false {
        willSet {
            withAnimation {
                objectWillChange.send()
            }
        }
    }
    var isPlayerReady = false {
        willSet {
            objectWillChange.send()
        }
    }
    
    var playerProgress: Double = 0 {
        willSet {
            objectWillChange.send()
        }
    }
    var playerTime: PlayerTime = .zero {
        willSet {
            objectWillChange.send()
        }
    }
    var meterLevel: Float = 0 {
        willSet {
            objectWillChange.send()
        }
    }
    
    
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let timeEffect = AVAudioUnitTimePitch()
    
    private var buffer: AVAudioPCMBuffer!
    
    private var displayLink: CADisplayLink?
    
    private var needsFileScheduled = true
    
    private var audioFile: AVAudioFile?
    private var audioSampleRate: Double = 0
    private var audioLengthSeconds: Double = 0
    
    private var seekFrame: AVAudioFramePosition = 0
    private var currentPosition: AVAudioFramePosition = 0
    private var audioLengthSamples: AVAudioFramePosition = 0
    
    private var currentFrame: AVAudioFramePosition {
        guard
            let lastRenderTime = player.lastRenderTime,
            let playerTime = player.playerTime(forNodeTime: lastRenderTime)
        else {
            return 0
        }
        
        return playerTime.sampleTime
    }
    
    // MARK: - Public
    
    override init() {
        super.init()
        
//        do {
//            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
//            NSLog("Playback OK")
//            try AVAudioSession.sharedInstance().setActive(true)
//            NSLog("Session is Active")
//        } catch {
//            NSLog("ERROR: CANNOT PLAY MUSIC IN BACKGROUND. Message from code: \"\(error)\"")
//        }
        
        //setupAudio()
        setupAudioWithBuffer()
        setupDisplayLink()
    }
    
    func playOrPause() {
        isPlaying.toggle()
        
        if player.isPlaying {
            displayLink?.isPaused = true
            //disconnectVolumeTap()
            endRecording()
            
            player.pause()
        } else {
            displayLink?.isPaused = false
            //connectVolumeTap()
            startRecording()
            
            if needsFileScheduled {
                //scheduleAudioFile()
                scheduleAudioBuffer()
            }
            player.play()
        }
    }
    
    func skip(forwards: Bool) {
        let timeToSeek: Double
        
        if forwards {
            timeToSeek = 10
        } else {
            timeToSeek = -10
        }
        
        seek(to: timeToSeek)
    }
    
    // MARK: - Private
    
    private func setupAudioWithBuffer() {
        guard let fileURL = Bundle.main.url(forResource: "voice-sample", withExtension: "m4a") else {
            return
        }
        
        do {
            let file = try AVAudioFile(forReading: fileURL)
            self.buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
            try file.read(into: buffer)
            let format = file.processingFormat
            
            audioLengthSamples = file.length
            audioSampleRate = format.sampleRate
            audioLengthSeconds = Double(audioLengthSamples) / audioSampleRate
            
            audioFile = file
        
            configureEngineWithBuffer(with: self.buffer)
        } catch {
            print("Error reading the audio file: \(error.localizedDescription)")
        }
    }
    
    private func configureEngineWithBuffer(with buffer: AVAudioPCMBuffer) {
        engine.attach(player)
        engine.attach(timeEffect)
        
        engine.connect(
            player,
            to: timeEffect,
            format: buffer.format)
        engine.connect(
            timeEffect,
            to: engine.mainMixerNode,
            format: buffer.format)
        
//        let inputNode = engine.inputNode
//        let bus = 0
//        inputNode.installTap(onBus: bus, bufferSize: 2048, format: inputNode.inputFormat(forBus: bus)) {
//            (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in
//            //println("sfdljk")
//            
//        }
        
        engine.prepare()
        
        do {
            try engine.start()
            
            scheduleAudioBuffer()
            isPlayerReady = true
        } catch {
            print("Error starting the player: \(error.localizedDescription)")
        }
    }
    
    private func scheduleAudioBuffer() {
        guard
            let file = audioFile,
            needsFileScheduled
        else {
            return
        }
        
        needsFileScheduled = false
        seekFrame = 0
        
        player.scheduleBuffer(self.buffer) {
            print("buffer played")
            self.needsFileScheduled = true
        }
        
//        player.scheduleFile(file, at: nil) {
//            self.needsFileScheduled = true
//        }
    }
    
    func startRecording() {

        let mixer = engine.mainMixerNode
        let format = mixer.outputFormat(forBus: 0)

        mixer.installTap(onBus: 0, bufferSize: 1024, format: format, block:
            { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) -> Void in

//            let arraySize = Int(buffer.frameLength)
//            var samples = Array(UnsafeBufferPointer(start: buffer.floatChannelData![0], count:arraySize))
            
            
//            let numChans = Int(buffer.format.channelCount)
//            let frameLength = buffer.frameLength
//            if let chans = buffer.floatChannelData?.pointee {
//                for a in 0..<numChans {
//                    let samples = chans[a]// samples is type Float.  should be pointer to Floats.
//                    for b in 0..<flength {
//                        print("sample: \(b)") // should be samples[b] but that gives error as "samples" is Float
//                    }
//                }
//            }
            
            guard let channelData = buffer.floatChannelData else {
                return
            }
            let channelDataValue = channelData.pointee
            for i in stride(
                from: 0,
                to: Int(buffer.frameLength),
                by: buffer.stride) {
                channelData[i]
            }
        })
    }
    
    func endRecording() {
        engine.mainMixerNode.removeTap(onBus: 0)
        
    }
    
//    private func setupAudio() {
//        guard let fileURL = Bundle.main.url(forResource: "voice-sample", withExtension: "m4a") else {
//            return
//        }
//
//        do {
//            let file = try AVAudioFile(forReading: fileURL)
//            let format = file.processingFormat
//
//            audioLengthSamples = file.length
//            audioSampleRate = format.sampleRate
//            audioLengthSeconds = Double(audioLengthSamples) / audioSampleRate
//
//            audioFile = file
//
//            configureEngine(with: format)
//        } catch {
//            print("Error reading the audio file: \(error.localizedDescription)")
//        }
//    }
//
//    private func configureEngine(with format: AVAudioFormat) {
//        engine.attach(player)
//        engine.attach(timeEffect)
//
//        engine.connect(
//            player,
//            to: timeEffect,
//            format: format)
//        engine.connect(
//            timeEffect,
//            to: engine.mainMixerNode,
//            format: format)
//
//        engine.prepare()
//
//        do {
//            try engine.start()
//
//            scheduleAudioFile()
//            isPlayerReady = true
//        } catch {
//            print("Error starting the player: \(error.localizedDescription)")
//        }
//    }
//
//    private func scheduleAudioFile() {
//        guard
//            let file = audioFile,
//            needsFileScheduled
//        else {
//            return
//        }
//
//        needsFileScheduled = false
//        seekFrame = 0
//
//        player.scheduleFile(file, at: nil) {
//            self.needsFileScheduled = true
//        }
//    }
    
    // MARK: Audio adjustments
    
    private func seek(to time: Double) {
        guard let audioFile = audioFile else {
            return
        }
        
        let offset = AVAudioFramePosition(time * audioSampleRate)
        seekFrame = currentPosition + offset
        seekFrame = max(seekFrame, 0)
        seekFrame = min(seekFrame, audioLengthSamples)
        currentPosition = seekFrame
        
        let wasPlaying = player.isPlaying
        player.stop()
        
        if currentPosition < audioLengthSamples {
            updateDisplay()
            needsFileScheduled = false
            
            let frameCount = AVAudioFrameCount(audioLengthSamples - seekFrame)
            player.scheduleSegment(
                audioFile,
                startingFrame: seekFrame,
                frameCount: frameCount,
                at: nil
            ) {
                self.needsFileScheduled = true
            }
            
            if wasPlaying {
                player.play()
            }
        }
    }
    
    
    // MARK: Audio metering
    
    private func scaledPower(power: Float) -> Float {
        guard power.isFinite else {
            return 0.0
        }
        
        let minDb: Float = -80
        
        if power < minDb {
            return 0.0
        } else if power >= 1.0 {
            return 1.0
        } else {
            return (abs(minDb) - abs(power)) / abs(minDb)
        }
    }
    
    private func connectVolumeTap() {
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { buffer, _ in
            guard let channelData = buffer.floatChannelData else {
                return
            }

            
            let channelDataValue = channelData.pointee
            let channelDataValueArray = stride(
                from: 0,
                to: Int(buffer.frameLength),
                by: buffer.stride)
                .map { channelDataValue[$0] }
            
            let rms = sqrt(channelDataValueArray.map {
                return $0 * $0
            }
                .reduce(0, +) / Float(buffer.frameLength))
            
            let avgPower = 20 * log10(rms)
            let meterLevel = self.scaledPower(power: avgPower)
            
            DispatchQueue.main.async {
                self.meterLevel = self.isPlaying ? meterLevel : 0
            }
        }
    }
    
    private func disconnectVolumeTap() {
        engine.mainMixerNode.removeTap(onBus: 0)
        meterLevel = 0
    }
    
    // MARK: Display updates
    
    private func setupDisplayLink() {
        displayLink = CADisplayLink(
            target: self,
            selector: #selector(updateDisplay))
        displayLink?.add(to: .current, forMode: .default)
        displayLink?.isPaused = true
    }
    
    @objc private func updateDisplay() {
        currentPosition = currentFrame + seekFrame
        currentPosition = max(currentPosition, 0)
        currentPosition = min(currentPosition, audioLengthSamples)
        
        if currentPosition >= audioLengthSamples {
            player.stop()
            
            seekFrame = 0
            currentPosition = 0
            
            isPlaying = false
            displayLink?.isPaused = true
            
            //disconnectVolumeTap()
            endRecording()
        }
        
        playerProgress = Double(currentPosition) / Double(audioLengthSamples)
        
        let time = Double(currentPosition) / audioSampleRate
        playerTime = PlayerTime(
            elapsedTime: time,
            remainingTime: audioLengthSeconds - time)
    }
    
    
}
