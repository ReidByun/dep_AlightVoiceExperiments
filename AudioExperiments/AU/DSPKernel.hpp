//
//  DSPKernel.hpp
//  AudioUnitV3Template
//
//  Created by mhamilt7 on 10/07/2018.
//  Copyright © 2018 mhamilt7. All rights reserved.
//
//==============================================================================
#ifndef DSPKernel_h
#define DSPKernel_h
//==============================================================================
#import <vector>
//==============================================================================
/*
 DSPKernel Performs our filter signal processing.
 As a non-ObjC class, this is safe to use from render thread.
 */

extern bool    nowScrubbing;
extern AudioBufferList* pcmBuffer;
extern int nowFrameScrubbing;
extern int currentPlayingFrame;

class DSPKernel
{
public:
    bool myScrubbing = false;
    
    int targetFrame = 0;
    int lastScrubbingStartFrame = 0;
    bool isEnoughFrameOut = false;
    int miniumFrameOutCount = 4410;
    int accumFrameOut = 0;
    
    int testFrameOffset = 0;
    
    //==========================================================================
    // MARK: Member Functions
    DSPKernel() {}
    
    //==========================================================================
    void init(int channelCount, double inSampleRate)
    {
        channels = channelCount;
        sampleRate = float(inSampleRate);
        miniumFrameOutCount = sampleRate / 1000;
    }
    //==============================================================================
    /**
     The central DSP Algorithm: this is essentially 'where the magic happens'
     
     @param frameCount from the DSPKernel super class. This is the framesRemaining
     which is the 'AVAudioFrameCount frameCount' directly from
     internalRenderBlock in the main FilterDemo.mm file.
     
     @param bufferOffset  bufferOffset = frameCount - framesRemaining. frameCount
     from internalRenderBlock is copied and subtracted from
     processWithEvents in the DSPKernel in which the call to
     this function is made
     */
    void process(AUAudioFrameCount frameCount, AUAudioFrameCount bufferOffset)
    {
        if (myScrubbing != nowScrubbing) {
            myScrubbing = nowScrubbing;
            //NSLog(myScrubbing ? @"Yes" : @"No");
        }
        int channelCount = channels;
        
        if (!myScrubbing) {
            for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) // For each sample.
            {
                int frameOffset = int(frameIndex + bufferOffset);
                for (int channel = 0; channel < channelCount; ++channel)
                {
                    float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                    float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                    // MARK: Sample Processing
                    *out = *in;
                    //*out = 0;
                }
            }
            
            lastScrubbingStartFrame = currentPlayingFrame;
        }
        else {
            //double ratio = abs(double((targetFrame + frameCount) - lastScrubbingStartFrame)) / double(frameCount);
            targetFrame = nowFrameScrubbing;
            double diff = abs(double(targetFrame - lastScrubbingStartFrame));
//            double diff = abs(double(lastScrubbingStartFrame - targetFrame));
            double ratio = diff / double(frameCount);
            double stride = ratio;
            
//            if (int(stride) == 941) {
//                printf("as;ldfjas;lkdjf;la");
//            }
            //stride = 18;
            
            //printf("target = %d, now = %d, (%d), stride = %.2f, ratio = %.2f\n", targetFrame, nowFrameScrubbing, nowFrameScrubbing - targetFrame, stride, ratio);
            
            int lastTest = 0;
            if (targetFrame != lastScrubbingStartFrame || !isEnoughFrameOut) {
            //if (scrubbingStartFrame != nowFrameScrubbing) {
                if (accumFrameOut == 0) {
                    isEnoughFrameOut = true;
                    //targetFrame = nowFrameScrubbing;
                }
                printf("out data(%.1f)diff(%.2f) ", stride, diff);
                
                int maximumFrameCount = pcmBuffer->mBuffers[0].mDataByteSize / 4;
                
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) // For each sample.
                {
                    int frameOffset = int(frameIndex + bufferOffset);
                    int inputFrameOffset = int(double(lastScrubbingStartFrame + accumFrameOut + (frameIndex * stride)));
                    for (int channel = 0; channel < channelCount; ++channel)
                    {
                        if (inputFrameOffset < targetFrame) {
                            float* indata = (float *)(pcmBuffer->mBuffers[channel].mData);
                            float* in  = &indata[inputFrameOffset];
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            // MARK: Sample Processing
                            *out = *in;
                            lastTest = inputFrameOffset;
                            //lastScrubbingStartFrame = inputFrameOffset;
                        }
                        else {
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            // MARK: Sample Processing
                            *out = 0;
                            lastTest = maximumFrameCount;
                            //lastScrubbingStartFrame = maximumFrameCount;
                        }
                    }
                    //testFrameOffset++;
                    //testFrameOffset %= (pcmBuffer->mBuffers[0].mDataByteSize/4);
                }
                
                //accumFrameOut += frameCount;
                if (accumFrameOut >= miniumFrameOutCount) {
                    isEnoughFrameOut = true;
                    accumFrameOut = 0;
                }
                printf("target(%d), last(%d) lastTest(%d), now(%d), diff(%.1f)\n", targetFrame, lastScrubbingStartFrame, lastTest, nowFrameScrubbing, diff);
            }
            else {
                //printf("zero data(%.0f) ", stride);
                for (int channel = 0; channel < channelCount; ++channel)
                {
                    memset(outBufferListPtr->mBuffers[channel].mData, 0, outBufferListPtr->mBuffers[channel].mDataByteSize);
                }
                lastScrubbingStartFrame = targetFrame;
            }
            
//            printf("target(%d), last(%d) lastTest(%d), now(%d), diff(%d)\n", targetFrame, lastScrubbingStartFrame, lastTest, nowFrameScrubbing, diff);
            
            lastScrubbingStartFrame = targetFrame;
            
        }
    }
    //==============================================================================
    void processWithEvents(AUAudioFrameCount frameCount,
                           AudioBufferList* inBufferList,
                           AudioBufferList* outBufferList)
    {
        //----------------------------------------------------------------------
        inBufferListPtr = inBufferList;
        outBufferListPtr = outBufferList;
        //----------------------------------------------------------------------
        AUAudioFrameCount framesRemaining = frameCount;
        AUAudioFrameCount const bufferOffset = frameCount - framesRemaining;
        process(framesRemaining, bufferOffset);
        //----------------------------------------------------------------------
    }
    //==========================================================================
private:
    //==========================================================================
    // MARK: Member Variables
    float sampleRate = 44100.0;
    int channels;
    AudioBufferList* inBufferListPtr = nullptr;
    AudioBufferList* outBufferListPtr = nullptr;
};

#endif /* DSPKernel_h */
