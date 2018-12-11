//
//  UnityApiController.h
//  Unity-iPhone
//
//  Created by 이다한 on 2018. 11. 12..
//

#ifndef UnityApiController_h
#define UnityApiController_h


#endif /* UnityApiController_h */


#import <Foundation/Foundation.h>
#import "JFRWebSocket.h"
#import "WebRTC/RTCPeerConnection.h"
#import "WebRTC/RTCVideoTrack.h"

@class UnityApiController;
@class RTCCameraVideoCapturer;

@protocol UnityApiControllerDelegate <NSObject>


- (void)controller:(UnityApiController *)controller
   didGetSocketMessage:(NSString *)message;

//- (void)controller:(UnityApiController *)controller
//didCreateLocalCapturer:(RTCCameraVideoCapturer *)localCapturer
//           source:(RTCVideoSource *)source;

- (void)controller:(UnityApiController *)controller
createLocalCapturerSource:(RTCVideoSource *)source;

- (void)controller:(UnityApiController *)controller
getRemotePixelBuffer:(CVPixelBufferRef)buffer
           trackId:(NSString *)trackId
           userId:(NSString *)userId;;
            

- (void)controller:(UnityApiController *)controller
connectionCompleted:(NSString *)userId;




//음성 데이터 전달
- (void)controller:(UnityApiController *)controller
        getPcmData:(bool)sttOnoff;


- (void)controller:(UnityApiController *)controller
       onEventPeer:(NSString *)eventType
            userId:(NSString *)userId
       stream_flag:(int)stream_flag
            videoId:(int)videoId
         mode_flag:(NSString *)mode_flag;

- (void)controller:(UnityApiController *)controller
       onErrorPeer:(NSString *)eventType
            userId:(NSString *)userId;

@optional

@end

@interface UnityApiController : NSObject

@property(nonatomic, weak) id<UnityApiControllerDelegate> delegate;
// Convenience constructor since all expected use cases will need a delegate
// in order to receive remote tracks.
- (instancetype)initWithDelegate:(id<UnityApiControllerDelegate>)delegate;


- (void)socketConnect:(JFRWebSocket*)getSocket mHandleId:(NSString *)mHandleId getSecret:(NSString *)getSecret;


- (void)setVideoResolution:(NSString *)setVideoResolution;


//int로 변경


- (void) peerConnectionDisConnect;

//TO DO
//requestJoin
-(void)requestJoin:(JFRWebSocket*)getSocket
          res_type:(NSString *)res_type
         handle_id:(NSString *)handle_id
           user_id:(NSString *)user_id
   resource_secret:(NSString *)resource_secret
         mode_flag:(NSString *)mode_flag;

-(void)requestLeave:(NSString *)handle_id
            user_id:(NSString *)user_id;

-(void)requestVideoOnOff:(NSString *)user_id
                  enable:(BOOL)enable
                 stream_flag:(int)stream_flag;

-(void)requestVoiceOnOff:(NSString *)user_id
                  enable:(BOOL)enable
             stream_flag:(int)stream_flag;

- (void)setMaxBitrate:(int) setMaxBitrate;

-(void)requestSetMode:(int)stream_flag
            mode_flag:(NSString *)mode_flag;





//-(void)websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)string;

@end
