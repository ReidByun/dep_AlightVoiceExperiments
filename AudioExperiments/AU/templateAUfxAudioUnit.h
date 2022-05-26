//==============================================================================
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
//==============================================================================
@interface templateAUfxAudioUnit : AUAudioUnit
+ (AudioBufferList *)getBufferListFromBuffer:(AVAudioPCMBuffer *)buffer;
@end
//==============================================================================

extern bool nowScrubbing;
extern int nowFrameScrubbing;
extern int currentPlayingFrame;
extern AudioBufferList* pcmBuffer;
