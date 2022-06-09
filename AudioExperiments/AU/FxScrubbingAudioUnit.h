#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
//==============================================================================
@interface FxScrubbingAudioUnit : AUAudioUnit
+ (AudioBufferList *)getBufferListFromBuffer:(AVAudioPCMBuffer *)buffer;
@end
//==============================================================================

extern bool nowScrubbing;
extern int nowFrameScrubbing;
extern int currentPlayingFrame;
extern AudioBufferList* pcmBuffer;
extern double nowScrollVelocity;
