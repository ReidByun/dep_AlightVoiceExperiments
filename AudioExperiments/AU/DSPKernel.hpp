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
extern double nowScrollVelocity;

class DSPKernel
{
public:
    bool myScrubbing = false;
    
    int targetFrame = 0;
    int lastScrubbingStartFrame = 0;
    
    int prevNowScrubbing = 0;
    int scrubbingStoppedFrame = 0;
    bool isForwardScrubbing = true;
    
    //==========================================================================
    // MARK: Member Functions
    DSPKernel() {}
    
    //==========================================================================
    void init(int channelCount, double inSampleRate)
    {
        channels = channelCount;
        sampleRate = float(inSampleRate);
        //miniumFrameOutCount = sampleRate / 1000;
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
                //int inframeOffset = int(frameIndex/2 + acc);
                for (int channel = 0; channel < channelCount; ++channel)
                {
                    float* in  = (float*)inBufferListPtr->mBuffers[channel].mData  + frameOffset;
                    //float* indata = (float *)(pcmBuffer->mBuffers[channel].mData);
                    //float* in  = indata  + inframeOffset;
                    
                    float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                    // MARK: Sample Processing
                    *out = *in;
                    //*out = 0;
                }
            }
            //acc += frameCount/2;
            
            lastScrubbingStartFrame = currentPlayingFrame;
        }
        else {
            int currentNow = nowFrameScrubbing;
            targetFrame = nowFrameScrubbing;
            //targetFrame = lastScrubbingStartFrame + frameCount/2;
            
            printf("--- target(%d), lastScrub(%d), prevNow(%d), now(%d)\n", targetFrame,lastScrubbingStartFrame, prevNowScrubbing, nowFrameScrubbing);
            
            
            if (prevNowScrubbing != nowFrameScrubbing) {
                scrubbingStoppedFrame = 0;
                if (prevNowScrubbing - nowFrameScrubbing < 0) {
                    isForwardScrubbing = true;
                }
                else {
                    isForwardScrubbing = false;
                }
            }
            
            int maximumFrameCount = pcmBuffer->mBuffers[0].mDataByteSize / 4;
            if (targetFrame == lastScrubbingStartFrame || prevNowScrubbing == nowFrameScrubbing) {
//                if (targetFrame == lastScrubbingStartFrame) {
//                    printf("--> target==lastscrubb\n");
//                }
//
//                if (prevNowScrubbing == nowFrameScrubbing) {
//                    printf("-------> prev == now\n");
//                }

                scrubbingStoppedFrame += frameCount;
                if (scrubbingStoppedFrame < sampleRate / 5.0) { // 200ms
                    printf("using velocity->  ");
                    double velocity = (nowScrollVelocity / 100.f);
//                    if (velocity < 0.1) {
//                        velocity = 0.10;
//                    }
                    if (isForwardScrubbing) {
                        targetFrame = lastScrubbingStartFrame + int(double(frameCount) * velocity);

                        if (targetFrame >= maximumFrameCount) {
                            targetFrame = maximumFrameCount - 1;
                        }
                    }
                    else {
                        targetFrame = lastScrubbingStartFrame - int(double(frameCount) * velocity);
                        if (targetFrame < 0) {
                            targetFrame = 0;
                        }
                    }
                    //printf("use velocity!!!!! velocity(%.3f), newTarget(%d) -> stride(%.3f)\n", velocity, targetFrame, (double(targetFrame) - double(lastScrubbingStartFrame)) / double(frameCount - 1));
                }
                else {
                    printf("mute");
                    targetFrame = lastScrubbingStartFrame;
                }
            }
            prevNowScrubbing = currentNow;
            double diff = double(targetFrame) - double(lastScrubbingStartFrame);
            double stride = diff / double(frameCount-1);
            printf("diff %f velocity(%.3f) // ", diff, nowScrollVelocity / 100.f);
            
            int lastOutFrame = 0;
            
            if (targetFrame != lastScrubbingStartFrame) {
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) // For each sample.
                {
                    int frameOffset = int(frameIndex + bufferOffset);
                    //int inputFrameOffset = int(double(lastScrubbingStartFrame + (frameIndex * stride)));
                    //int inputFrameOffset = floor(double(lastScrubbingStartFrame + (frameIndex * stride)));
                    //int inputFrameNextOffset = ceil(double(lastScrubbingStartFrame + (frameIndex * stride)));
                    
                    int inputFrameOffset = int(lastScrubbingStartFrame + double(frameIndex * diff) / double(frameCount-1));
                    //int inputFrameOffset = floor(lastScrubbingStartFrame + double(frameIndex * diff) / double(frameCount-1));
                    int inputFrameNextOffset = ceil(lastScrubbingStartFrame + double(frameIndex * diff) / double(frameCount-1));
                    if (inputFrameOffset >= maximumFrameCount) {
                        inputFrameOffset = maximumFrameCount;
                    }
                    if (inputFrameNextOffset >= maximumFrameCount) {
                        inputFrameNextOffset = inputFrameOffset;
                    }
                    
                    
//                    if (diff < 500) {
//                        for (int channel = 0; channel < channelCount; ++channel)
//                        {
//
//                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
//                            lastOutFrame = inputFrameOffset;
//                            *out = 0;
//                        }
//                    }
//                    else {
//
                    for (int channel = 0; channel < channelCount; ++channel)
                    {
                        if (    (diff > 0 && inputFrameOffset <= targetFrame)
                            ||  (diff < 0 && inputFrameOffset >= targetFrame) ){
                            float* indata = (float *)(pcmBuffer->mBuffers[channel].mData);
                            float* in  = &indata[inputFrameOffset];
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            // MARK: Sample Processing
                            float* inNext = &indata[inputFrameNextOffset];
                            float outSample = interpolation(*in, *inNext);
                            
                            *out = *in;
                            lastOutFrame = inputFrameOffset;
                        }
                        else {
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            printf("mute");
                            *out = 0;
                        }
                    }
                    //}
                }
                
                if (lastOutFrame != 0 && lastOutFrame != targetFrame) {
                    printf("not same!! target(%d), lastOutFrame(%d) =>> %d \n", targetFrame, lastOutFrame, targetFrame - lastOutFrame);
                    lastScrubbingStartFrame = lastOutFrame;
                }
                else {
                    printf("last is same\n");
                    lastScrubbingStartFrame = targetFrame;
                }
            }
            else {
                //printf("zero data(%.0f) ", stride);
                for (int channel = 0; channel < channelCount; ++channel)
                {
                    memset(outBufferListPtr->mBuffers[channel].mData, 0, outBufferListPtr->mBuffers[channel].mDataByteSize);
                }
                lastScrubbingStartFrame = targetFrame;
                //printf("mute");
            }
        }
    }
    
    float interpolation(float sampleA, float sampleB) {
        float p = sampleA - floor(sampleA);
        float q = 1.0f - p;
        //printf("%f\n", p);
        
//        float result = sampleA * q + sampleB * p;
//        printf("%f -> %f (%s)\n", sampleA, result, sampleA != result ? "true" : "false");
        
        return sampleA * q + sampleB * p;
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
