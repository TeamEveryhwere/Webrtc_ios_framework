/*
 *  Copyright 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#import "RTCMediaStreamTrack.h"

#import "RTCMacros.h"

#include "RTCVideoFrame.h"
// #import "api/RTCVideoRendererAdapter.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RTCVideoRenderer;
@class RTCPeerConnectionFactory;
@class RTCVideoSource;
@class RTCVideoTrack;
RTC_OBJC_EXPORT


@protocol RTCVideoTrackDelegate <NSObject>

- (void)rtcVideoTrack:(RTCVideoTrack *)track
   didGetFrame:(RTCVideoFrame *)frame;


@optional

@end

@interface RTCVideoTrack : RTCMediaStreamTrack

/** The video source for this video track. */
@property(nonatomic, readonly) RTCVideoSource *source;
// @property(nonatomic, weak) RTCVideoRendererAdapter *adapter;
@property(nonatomic, weak) id<RTCVideoTrackDelegate> delegate;
// Convenience constructor since all expected use cases will need a delegate
// in order to receive remote tracks.



- (instancetype)init NS_UNAVAILABLE;

/** Register a renderer that will render all frames received on this track. */
- (void)addRenderer:(id<RTCVideoRenderer>)renderer;

/** Deregister a renderer. */
- (void)removeRenderer:(id<RTCVideoRenderer>)renderer;

- (void) getFrameFromVideoTrack:(RTCVideoFrame *)frameFromAdapter;

// -(RTCVideoFrame *) getFrameFromVideoTrack:(id<RTCVideoRenderer>)renderer;

@end

NS_ASSUME_NONNULL_END
