/*
 *  Copyright 2017 The WebRTC Project Authors. All rights reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree. An additional intellectual property rights grant can be found
 *  in the file PATENTS.  All contributing project authors may
 *  be found in the AUTHORS file in the root of the source tree.
 */

#include <WebRTC/RTCCameraVideoCapturer.h>

@class ARDSettingsModel;
@protocol ARDCaptureControllerDelegate <NSObject>

//- (void)capturer:(ARDCaptureController *)capturer
//   didGetFrameFromCapture:(RTCAppClientState)frame;


@optional

@end

// Controls the camera. Handles starting the capture, switching cameras etc.
@interface ARDCaptureController : NSObject
@property(nonatomic, weak) id<ARDCaptureControllerDelegate> delegate;
// Convenience constructor since all expected use cases will need a delegate
// in order to receive remote tracks.

- (instancetype)initWithCapturer:(RTCCameraVideoCapturer *)capturer
                        settings:(ARDSettingsModel *)settings;
                        
- (void)startCapture;
- (void)stopCapture;
- (void)switchCamera;

// @property(nonatomic, weak) RTCCameraVideoCapturer *_capturer;

@end
