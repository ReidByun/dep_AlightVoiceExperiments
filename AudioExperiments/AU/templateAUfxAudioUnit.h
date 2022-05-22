//
//  templateAUfxAudioUnit.h
//  templateAUfx
//
//  Created by mhamilt7 on 10/07/2018.
//  Copyright © 2018 mhamilt7. All rights reserved.
//
//==============================================================================
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
//==============================================================================
@interface templateAUfxAudioUnit : AUAudioUnit
+ (AudioBufferList *)getBufferListFromBuffer:(AVAudioPCMBuffer *)buffer;
@end
//==============================================================================

extern bool nowScrubbing;
extern int currentFrame;
extern AudioBufferList* pcmBuffer;
