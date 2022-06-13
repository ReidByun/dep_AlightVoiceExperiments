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
    int accumFrameCount = 0;
    bool isEndedPreviouseOut = true;
    
    double diff = 0;
    double stride = 1;
    
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
            if (isEndedPreviouseOut == true) {
                targetFrame = nowFrameScrubbing;
                diff = double(targetFrame) - double(lastScrubbingStartFrame);
                //double stride = diff / double(frameCount-1);
                if (nowScrollVelocity < 25) {
                    //nowScrollVelocity = 25;
                }
                else if (nowScrollVelocity > 400) {
                    nowScrollVelocity = 400;
                }
                stride = nowScrollVelocity / 100.0;
                double calcTarget = lastScrubbingStartFrame + (double(frameCount - 1) * stride);
                if (calcTarget >= targetFrame) {
                    //stride = diff / double(frameCount-1);
                    //printf("calcTarget(%f) >= target(%f)\n4535", calcTarget, targetFrame);
                }
                else {
                    //printf("calcTarget(%f) < target(%d)\n", calcTarget, targetFrame);
                }
                //printf("diff %f velocity(%f) // ", diff, nowScrollVelocity);
                
                
                printf("new? %s -> stride(%.3f), calcTarget(%.3f), target(%d), last(%d), diff(%.3f) \n", isEndedPreviouseOut ? "true":"false", stride, calcTarget, targetFrame, lastScrubbingStartFrame, diff);
                
            }
            else {
                double calcTarget = lastScrubbingStartFrame + (double(frameCount - 1) * stride);
                printf("new? %s -> stride(%.3f), calcTarget(%.3f), target(%d), last(%d), diff(%.3f) \n", isEndedPreviouseOut ? "true":"false", stride, calcTarget, targetFrame, lastScrubbingStartFrame, diff);
            }
            
            
            
            
            int lastOutFrame = 0;
            if (targetFrame != lastScrubbingStartFrame) {
                int maximumFrameCount = pcmBuffer->mBuffers[0].mDataByteSize / 4;
                
                for (int frameIndex = 0; frameIndex < frameCount; ++frameIndex) // For each sample.
                {
                    int frameOffset = int(frameIndex + bufferOffset);
                    int inputFrameOffset = int(double(lastScrubbingStartFrame + (frameIndex * stride)));
//                    int inputFrameOffset = int(lastScrubbingStartFrame + double(frameIndex * diff) / double(frameCount-1));
                    
                    for (int channel = 0; channel < channelCount; ++channel)
                    {
                        if (    (diff > 0 && inputFrameOffset <= targetFrame)
                            ||  (diff < 0 && inputFrameOffset >= targetFrame) ){
                            float* indata = (float *)(pcmBuffer->mBuffers[channel].mData);
                            float* in  = &indata[inputFrameOffset];
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            // MARK: Sample Processing
                            *out = *in;
                            lastOutFrame = inputFrameOffset;
                        }
                        else {
                            float* out = (float*)outBufferListPtr->mBuffers[channel].mData + frameOffset;
                            *out = 0;
                            lastOutFrame = targetFrame;
                        }
                    }
                }
                
                if (lastOutFrame != 0 && lastOutFrame != targetFrame) {
                    printf("target(%d), lastOutFrame(%d) =>> %d \n", targetFrame, lastOutFrame, targetFrame - lastOutFrame);
                    accumFrameCount += abs(lastScrubbingStartFrame - lastOutFrame);
                    lastScrubbingStartFrame = lastOutFrame;
                    isEndedPreviouseOut = false;
                    
                    //if (accumFrameCount > )
                }
                else {
                    lastScrubbingStartFrame = targetFrame;
                    accumFrameCount = 0;
                    isEndedPreviouseOut = true;
                }
            }
            else {
                //printf("zero data(%.0f) ", stride);
                for (int channel = 0; channel < channelCount; ++channel)
                {
                    memset(outBufferListPtr->mBuffers[channel].mData, 0, outBufferListPtr->mBuffers[channel].mDataByteSize);
                }
                lastScrubbingStartFrame = targetFrame;
                isEndedPreviouseOut = true;
            }
            currentPlayingFrame = lastScrubbingStartFrame;
            printf("last(%d)\n", lastScrubbingStartFrame);
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
