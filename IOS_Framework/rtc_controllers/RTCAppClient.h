//
//  RTCAppClient.h
//  VaristarWebRtc_IOS
//
//  Created by 이다한 on 2018. 10. 11..
//

#import <Foundation/Foundation.h>
#import "WebRTC/RTCPeerConnection.h"
#import "WebRTC/RTCVideoTrack.h"
#import "WebRTC/RTCAudioTrack.h"

typedef NS_ENUM(NSInteger, RTCAppClientState) {
    // Disconnected from servers.
    kRTCAppClientStateDisconnected,
    // Connecting to servers.
    kRTCAppClientStateConnecting,
    // Connected to servers.
    kRTCAppClientStateConnected,
};

@class RTCAppClient;
@class ARDSettingsModel;
@class RTCMediaConstraints;
@class RTCCameraVideoCapturer;
@class RTCFileVideoCapturer;

// The delegate is informed of pertinent events and will be called on the
// main queue.
@protocol RTCAppClientDelegate <NSObject>

- (void)appClient:(RTCAppClient *)client
   didChangeState:(RTCAppClientState)state;

- (void)appClient:(RTCAppClient *)client
didChangeConnectionState:(RTCIceConnectionState)state;

- (void)appClient:(RTCAppClient *)client
didCreateLocalCapturer:(RTCCameraVideoCapturer *)localCapturer
                source:(RTCVideoSource *)source;

- (void)appClient:(RTCAppClient *)client
createLocalCapturerSource:(RTCVideoSource *)source;



//- (void)appClient:(RTCAppClient *)client
//sendVideoCapturer:(RTCVideoCapturer *)rtcVideoCapturer
//           source:(RTCVideoSource *)source;


- (void)appClient:(RTCAppClient *)client
didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack;

- (void)appClient:(RTCAppClient *)client
didReceiveLocalAudioTrack:(RTCAudioTrack *)localATrack;


- (void)appClient:(RTCAppClient *)client
didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack
                    userId:(NSString *)userId;

- (void)appClient:(RTCAppClient *)client
didReceiveRemoteAudioTrack:(RTCAudioTrack *)remoteAudioTrack;


- (void)appClient:(RTCAppClient *)client
         didError:(NSError *)error;

- (void)appClient:(RTCAppClient *)client
      didGetStats:(NSArray *)stats;

- (void)appClient:(RTCAppClient *)client
didSetSessionDescriptionWithError:(NSError *)error
             type:(NSString *)type;

- (void)appClient:(RTCAppClient *)client
didCreateSessionDescription:(RTCSessionDescription *)sdp
            error:(NSError *)error;

- (void)appClient:(RTCAppClient *)client
          didAddStream:(RTCMediaStream *)stream;


- (void)appClient:(RTCAppClient *)client
    updateCameraCreated:(BOOL *)cameraCreated;


- (void)appClient:(RTCAppClient *)client
clientClosed:(NSString *)userId;




@optional

@end

// Handles connections to the AppRTC server for a given room. Methods on this
// class should only be called from the main queue.
@interface RTCAppClient : NSObject

// If |shouldGetStats| is true, stats will be reported in 1s intervals through
// the delegate.
@property(nonatomic, assign) BOOL shouldGetStats;
@property(nonatomic, readonly) RTCAppClientState state;
@property(nonatomic, weak) id<RTCAppClientDelegate> delegate;
// Convenience constructor since all expected use cases will need a delegate
// in order to receive remote tracks.
- (instancetype)initWithDelegate:(id<RTCAppClientDelegate>)delegate;

// Establishes a connection with the AppRTC servers for the given room id.
// |settings| is an object containing settings such as video codec for the call.
// If |isLoopback| is true, the call will connect to itself.
- (void)connectWithId:(NSString *)handleId
             settings:(ARDSettingsModel *)settings
                count:(NSUInteger)count
        cameraCreated:(BOOL)cameraCreated
  setVideoResolution:(NSString *)setVideoResolution
        setMaxBitrate:(NSNumber *)setMaxBitrate
        userid:(NSString *)userid;
//                 isLoopback:(BOOL)isLoopback;


// Disconnects from the AppRTC servers and any connected clients.
- (void)disconnect;

-(void)setRemoteDescription:(RTCSessionDescription *)description;

-(void)addIceCandiDate:(RTCIceCandidate *)iceCandidate;
-(void)updateCameraCreated:(BOOL)cameraCreated;

-(void)localVoiceOnoff:(bool)enable;

@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCIceCandidate *generatedVideoIceCandidate;
@property(nonatomic, strong) RTCIceCandidate *generatedAudioIceCandidate;
@property(nonatomic, strong) NSString *userId;
@property(nonatomic, strong) NSString *trackId;

@property(nonatomic, strong) RTCVideoTrack *remoteVideoTrack;
@property(nonatomic, strong) RTCAudioTrack *remoteAudioTrack;
@property(nonatomic, strong) RTCAudioTrack *localAudioTrack;

@end
