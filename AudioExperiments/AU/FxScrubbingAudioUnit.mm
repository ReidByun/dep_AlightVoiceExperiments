#import "FxScrubbingAudioUnit.h"
#import <AVFoundation/AVFoundation.h>
#import "DSPKernel.hpp"
#import "BufferedAudioBus.hpp"
//==============================================================================

bool nowScrubbing = false;
AudioBufferList* pcmBuffer = nil;
int nowFrameScrubbing = 0;
int currentPlayingFrame = 0;
double nowScrollVelocity = 0.0;

//==============================================================================
@interface FxScrubbingAudioUnit ()
@property AUAudioUnitBus *outputBus;
@property AUAudioUnitBusArray *inputBusArray;
@property AUAudioUnitBusArray *outputBusArray;
@end
//==============================================================================
@implementation FxScrubbingAudioUnit
{
    // Add your C++ Classes Here:
    BufferedInputBus _inputBus;
    DSPKernel  _kernel;
}
//==============================================================================

- (instancetype)initWithComponentDescription:(AudioComponentDescription)componentDescription options:(AudioComponentInstantiationOptions)options error:(NSError **)outError
{
    //--------------------------------------------------------------------------
    self = [super initWithComponentDescription:componentDescription
                                       options:options
                                         error:outError];
    if (self == nil) { return nil; }
    //--------------------------------------------------------------------------
    // @invalidname: Initialize a default format for the busses.
    AVAudioFormat *defaultFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:44100.0 channels:2];
    //--------------------------------------------------------------------------
    _kernel.init(defaultFormat.channelCount, defaultFormat.sampleRate);
    //==========================================================================
    // Create the input and output busses.
    _inputBus.init(defaultFormat, 8);
    _outputBus = [[AUAudioUnitBus alloc] initWithFormat:defaultFormat error:nil];
    //--------------------------------------------------------------------------
    // Create the input and output bus arrays
    _inputBusArray  = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeInput busses: @[_inputBus.bus]];
    _outputBusArray = [[AUAudioUnitBusArray alloc] initWithAudioUnit:self busType:AUAudioUnitBusTypeOutput busses: @[_outputBus]];
    //--------------------------------------------------------------------------
    self.maximumFramesToRender = 512;
    //--------------------------------------------------------------------------
    return self;
}

-(void)dealloc
{
    
}

//==============================================================================
#pragma mark - AUAudioUnit Overrides

- (AUAudioUnitBusArray *)inputBusses
{
    return _inputBusArray;
}

- (AUAudioUnitBusArray *)outputBusses
{
    return _outputBusArray;
}

- (BOOL)allocateRenderResourcesAndReturnError:(NSError **)outError
{
    //--------------------------------------------------------------------------
    if (![super allocateRenderResourcesAndReturnError:outError])
    {
        return NO;
    }
    //--------------------------------------------------------------------------
    if (self.outputBus.format.channelCount != _inputBus.bus.format.channelCount)
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:kAudioUnitErr_FailedInitialization userInfo:nil];
        }
        // Notify superclass that initialization was not successful
        self.renderResourcesAllocated = NO;
        
        return NO;
    }
    //--------------------------------------------------------------------------
    _inputBus.allocateRenderResources(self.maximumFramesToRender);
    //--------------------------------------------------------------------------
    _kernel.init(self.outputBus.format.channelCount, self.outputBus.format.sampleRate);
    //--------------------------------------------------------------------------
    return YES;
}
//==============================================================================
// Deallocate resources allocated in allocateRenderResourcesAndReturnError:
// Subclassers should call the superclass implementation.
- (void)deallocateRenderResources
{
    //--------------------------------------------------------------------------
    _inputBus.deallocateRenderResources();
    //--------------------------------------------------------------------------
    [super deallocateRenderResources];
}

//==============================================================================
#pragma mark - AUAudioUnit (AUAudioUnitImplementation)

// Block which subclassers must provide to implement rendering.
- (AUInternalRenderBlock)internalRenderBlock
{
    //--------------------------------------------------------------------------
    // C++ pointers: Referred to as 'captures', make them mutable with __block
    // Capture in locals to avoid ObjC member lookups.
    __block DSPKernel *state = &_kernel;
    __block BufferedInputBus *input = &_inputBus;
    //--------------------------------------------------------------------------
    return ^AUAudioUnitStatus (AudioUnitRenderActionFlags *actionFlags,
                               const AudioTimeStamp *timestamp,
                               AVAudioFrameCount frameCount,
                               NSInteger outputBusNumber,
                               AudioBufferList *outputData,
                               const AURenderEvent *realtimeEventListHead,
                               AURenderPullInputBlock pullInputBlock)
    {
        //----------------------------------------------------------------------
        AudioUnitRenderActionFlags pullFlags = 0;
        AUAudioUnitStatus err = input->pullInput(&pullFlags, timestamp, frameCount, 0, pullInputBlock);
        if (err != 0) { return err; }
        //----------------------------------------------------------------------
        AudioBufferList *inAudioBufferList = input->mutableAudioBufferList;
        AudioBufferList *outAudioBufferList = outputData;
        if (outputData->mBuffers[0].mData == nullptr)
        {
            for (UInt32 i = 0; i < outputData->mNumberBuffers; ++i)
            {
                outputData->mBuffers[i].mData = inAudioBufferList->mBuffers[i].mData;
            }
        }
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        // DSP Goes in process method of DSPKernel
        state->processWithEvents(frameCount,
                                 inAudioBufferList,
                                 outAudioBufferList);
        //~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
        return noErr;
    };
}

//==============================================================================
+ (AudioBufferList *)getBufferListFromBuffer:(AVAudioPCMBuffer *)buffer {
    NSData* dataL = [[NSData alloc] initWithBytes:buffer.floatChannelData[0] length:buffer.frameLength * 4];
    NSData* dataR = [[NSData alloc] initWithBytes:buffer.floatChannelData[1] length:buffer.frameLength * 4];
    if (dataL.length > 0)
    {
        NSUInteger lenL = [dataL length];
        NSUInteger lenR = [dataR length];
        //Byte* byteDataL = (Byte*) malloc (lenL);
        //memcpy (byteDataL, [dataL bytes], lenL);
        if (lenL)
        {
            if (pcmBuffer != nil) {
                delete[] (Byte*)pcmBuffer->mBuffers[0].mData;
                delete[] (Byte*)pcmBuffer->mBuffers[1].mData;
                delete[] pcmBuffer;
            }
            
            pcmBuffer =(AudioBufferList*)malloc(sizeof(AudioBufferList) * 2);
            pcmBuffer->mNumberBuffers = 2;
            pcmBuffer->mBuffers[0].mDataByteSize =(UInt32) lenL;
            pcmBuffer->mBuffers[0].mNumberChannels = 1;
            
            float * dataLfloat =(float*) dataL.bytes;
            pcmBuffer->mBuffers[0].mData = (Byte*) malloc (lenL);
            float* left = (float *)(pcmBuffer->mBuffers[0].mData);
            for (int i = 0; i < buffer.frameLength; i++) {
                //left[i] = buffer.floatChannelData[0][i];
                left[i] = dataLfloat[i];
            }
            
            
            pcmBuffer->mBuffers[1].mDataByteSize =(UInt32) lenR;
            pcmBuffer->mBuffers[1].mNumberChannels = 1;
            float * dataRfloat =(float*) dataR.bytes;
            pcmBuffer->mBuffers[1].mData = (Byte*) malloc (lenR);
            float* right = (float *)(pcmBuffer->mBuffers[1].mData);
            for (int i = 0; i < buffer.frameLength; i++) {
                //right[i] = buffer.floatChannelData[0][i];
                //right[i] = avAudioPCMBuffer[2*i];
                right[i] = dataRfloat[i];
            }
            return pcmBuffer;
        }
    }
    return nil;
}

+ (AudioBufferList *)getBufferListFromBufferMono:(AVAudioPCMBuffer *)buffer {
    NSData* dataL = [[NSData alloc] initWithBytes:buffer.floatChannelData[0] length:buffer.frameLength * 4];
    //NSData* dataR = [[NSData alloc] initWithBytes:buffer.floatChannelData[1] length:buffer.frameLength * 4];
    if (dataL.length > 0)
    {
        NSUInteger lenL = [dataL length];
        //NSUInteger lenR = [dataR length];
        //Byte* byteDataL = (Byte*) malloc (lenL);
        //memcpy (byteDataL, [dataL bytes], lenL);
        if (lenL)
        {
            if (pcmBuffer != nil) {
                delete[] (Byte*)pcmBuffer->mBuffers[0].mData;
                //delete[] (Byte*)pcmBuffer->mBuffers[1].mData;
                delete[] pcmBuffer;
            }
            
            pcmBuffer =(AudioBufferList*)malloc(sizeof(AudioBufferList) * 1);
            pcmBuffer->mNumberBuffers = 1;
            pcmBuffer->mBuffers[0].mDataByteSize =(UInt32) lenL;
            pcmBuffer->mBuffers[0].mNumberChannels = 1;
            
            float * dataLfloat =(float*) dataL.bytes;
            pcmBuffer->mBuffers[0].mData = (Byte*) malloc (lenL);
            float* left = (float *)(pcmBuffer->mBuffers[0].mData);
            for (int i = 0; i < buffer.frameLength; i++) {
                //left[i] = buffer.floatChannelData[0][i];
                left[i] = dataLfloat[i];
            }
            
            return pcmBuffer;
        }
    }
    return nil;
}
//==============================================================================
@end


