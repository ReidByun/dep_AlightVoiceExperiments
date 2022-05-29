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
            
            if isScrubbing {
                nowFrameScrubbing = Int32(getCurrentFrame(from: playerProgress));
                //print("scrubbing progress \(playerProgress) ---> \(nowFrameScrubbing)")
            }
            else {
                currentPlayingFrame = Int32(getCurrentFrame(from: playerProgress));
            }
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
    
    private var scrubbingInPlaying = false
    
    @Published var isScrubbing = false {
        didSet {
            nowScrubbing = isScrubbing
            if isScrubbing {
                print("START scrubbing")
                if player.isPlaying {
                    scrubbingInPlaying = true
                    //player.pause()
                }
            }
            else {
                print("END scrubbing")
                if scrubbingInPlaying {
                    seek(to: currentTime(from: playerProgress))
                    scrubbingInPlaying = false
                    //var progress = Double(currentPosition) / Double(audioLengthSamples) * 100.0
                    print(playerProgress)
                    
                }
            }
        }
    }
    
    
    private let engine: AVAudioEngine!
    private let player = AVAudioPlayerNode()
    private let timeEffect = AVAudioUnitTimePitch()
    private var myAUNode: AVAudioUnit?        =  nil
    
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
        engine = AVAudioEngine()
        
        super.init()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback, options: AVAudioSession.CategoryOptions.mixWithOthers)
            NSLog("Playback OK")
            //try AVAudioSession.sharedInstance().setPreferredSampleRate(48000.0)
            //sampleRateHz  = 48000.0
            //let duration = 1.00 * (960/48000.0)
            let duration = 1.00 * (44100/48000.0)
            try AVAudioSession.sharedInstance().setPreferredIOBufferDuration(duration)
            try AVAudioSession.sharedInstance().setActive(true)
            NSLog("Session is Active")
        } catch {
            NSLog("ERROR: CANNOT PLAY MUSIC IN BACKGROUND. Message from code: \"\(error)\"")
        }
        
        //setupAudio()
        setupAudioWithBuffer()
        setupDisplayLink()
    }
    
    func playOrPause() {
        isPlaying.toggle()
        
        if player.isPlaying {
            displayLink?.isPaused = true
            //disconnectVolumeTap()
            //endRecording()
            
            player.pause()
        } else {
            displayLink?.isPaused = false
            //connectVolumeTap()
            //startRecording()
            
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
        
        seek(fromTimeOffset: timeToSeek)
    }
    
    // MARK: - Private
    
    private func setupAudioWithBuffer() {
//        guard let fileURL = Bundle.main.url(forResource: "voice-sample", withExtension: "m4a") else {
//        guard let fileURL = Bundle.main.url(forResource: "drums", withExtension: "mp3") else {
//        guard let fileURL = Bundle.main.url(forResource: "IU", withExtension: "mp3") else {
        guard let fileURL = Bundle.main.url(forResource: "IU-short", withExtension: "mp3") else {
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
            
            //sampleRateHz = buffer.format.sampleRate
            
            templateAUfxAudioUnit.getBufferList(from: buffer)
        
            configureEngineConnection(with: self.buffer)
            //configureEngineWithBuffer(with: self.buffer)
        } catch {
            print("Error reading the audio file: \(error.localizedDescription)")
        }
    }
    
    private func configureEngineWithBuffer(with buffer: AVAudioPCMBuffer) {
        engine.attach(player)
        engine.attach(timeEffect)
        engine.attach(self.myAUNode!)
        
//        engine.connect(
//            player,
//            to: timeEffect,
//            format: buffer.format)
        
        engine.connect(
            player,
            to: myAUNode!,
            format: buffer.format)
        
        engine.connect(
            myAUNode!,
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
        
        
        
        player.scheduleBuffer(self.buffer, at: nil, options: [.interruptsAtLoop, .loops]) {
        //player.scheduleBuffer(self.buffer) {
            print("play done.!!!")
            
            self.needsFileScheduled = true
            //self.scheduleAudioBuffer()
        }
        
//        player.scheduleFile(file, at: nil) {
//            self.needsFileScheduled = true
//        }
    }
    
    private func configureEngineConnection(with buffer: AVAudioPCMBuffer) {
        let myUnitType = kAudioUnitType_Effect
        let mySubType : OSType = 1
        
        let compDesc = AudioComponentDescription(componentType:     myUnitType,
                                                 componentSubType:  mySubType,
                                                 componentManufacturer: 0x666f6f20, // 4 hex byte OSType 'foo '
            componentFlags:        0,
            componentFlagsMask:    0 )
        
//        AUAudioUnit.registerSubclass(MyV3AudioUnit5.self,
//                                     as:        compDesc,
//                                     name:      "MyV3AudioUnit5",   // my AUAudioUnit subclass
//            version:   1 )
        AUAudioUnit.registerSubclass(templateAUfxAudioUnit.self,
                                     as:        compDesc,
                                     name:      "templateAUfxAudioUnit",   // my AUAudioUnit subclass
            version:   1 )
        
        let outFormat = self.engine.outputNode.outputFormat(forBus: 0)
        
        AVAudioUnit.instantiate(with: compDesc,
                                options: .init(rawValue: 0)) { (audiounit, error) in
            
            self.myAUNode = audiounit   // save AVAudioUnit
            self.configureEngineWithBuffer(with: buffer)
        }
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
    
    // MARK: Audio adjustments
    
    private func calcSeekFramePosition(fromTimeOffset timeOffset: Double,
                                       currentPos: AVAudioFramePosition,
                                       audioSamples: AVAudioFramePosition,
                                       sampleRate: Double) -> AVAudioFramePosition {
        let offset = AVAudioFramePosition(timeOffset * sampleRate)
        var posToseek = currentPos + offset
        posToseek = max(posToseek, 0)
        posToseek = min(posToseek, audioSamples)
        
        return posToseek
    }
    
    private func calcSeekFramePosition(fromAbsTime time: Double,
                                       currentPos: AVAudioFramePosition,
                                       audioSamples: AVAudioFramePosition,
                                       sampleRate: Double) -> AVAudioFramePosition {
        let timeToSeek = AVAudioFramePosition(time * sampleRate)
        var posToseek = timeToSeek
        posToseek = max(posToseek, 0)
        posToseek = min(posToseek, audioSamples)
        
        return posToseek
    }
    
    private func seek(fromTimeOffset time: Double) {
        seekFrame = calcSeekFramePosition(fromTimeOffset: time,
                                          currentPos: currentPosition,
                                          audioSamples: audioLengthSamples,
                                          sampleRate: audioSampleRate)
        currentPosition = seekFrame
        
        seekToCurrent()
    }
    
    private func seek(to time: Double) {
        seekFrame = calcSeekFramePosition(fromAbsTime: time,
                                          currentPos: currentPosition,
                                          audioSamples: audioLengthSamples,
                                          sampleRate: audioSampleRate)
        currentPosition = seekFrame
        seekToCurrent()
    }
    
    private func seekToCurrent() {
        guard let audioFile = audioFile else {
            return
        }
        
        
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
                print("seek done")
                self.needsFileScheduled = true
                //self.player.play()
                //self.scheduleAudioBuffer()
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
            //endRecording()
        }
        
        if !isScrubbing {
            playerProgress = Double(currentPosition) / Double(audioLengthSamples) * 100.0
        }
        
        let time = Double(currentPosition) / audioSampleRate
        playerTime = PlayerTime(
            elapsedTime: time,
            remainingTime: audioLengthSeconds - time)
    }
    
    func getCurrentFrame(from progress: Double) -> AVAudioFramePosition {
        return AVAudioFramePosition((progress / 100.0) * Double(audioLengthSamples))
    }
    
    func currentTime(from progress: Double) -> Double {
        return (progress / 100.0) * Double(audioLengthSeconds)
    }
}
// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertFromAVAudioSessionCategory(_ input: AVAudioSession.Category) -> String {
    return input.rawValue
}
