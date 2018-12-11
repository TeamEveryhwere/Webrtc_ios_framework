//
//  RTCAppClient+Internal.h
//  VaristarWebRtc_IOS
//
//  Created by 이다한 on 2018. 10. 11..
//

#import "RTCAppClient.h"

#import "WebRTC/RTCPeerConnection.h"

//#import "ARDSignalingChannel.h"
//#import "ARDTURNClient.h"

@class RTCPeerConnectionFactory;

//@interface RTCAppClient () <ARDSignalingChannelDelegate,
//RTCPeerConnectionDelegate>
@interface RTCAppClient () <RTCPeerConnectionDelegate>


// All properties should only be mutated from the main queue.
//@property(nonatomic, strong) id<ARDRoomServerClient> roomServerClient;
//@property(nonatomic, strong) id<ARDSignalingChannel> channel;
//@property(nonatomic, strong) id<ARDSignalingChannel> loopbackChannel;
//@property(nonatomic, strong) id<ARDTURNClient> turnClient;

//@property(nonatomic, strong) RTCPeerConnection *peerConnection;
@property(nonatomic, strong) RTCPeerConnectionFactory *factory;
@property(nonatomic, strong) NSMutableArray *messageQueue;

@property(nonatomic, assign) BOOL isTurnComplete;
@property(nonatomic, assign) BOOL hasReceivedSdp;
@property(nonatomic, readonly) BOOL hasJoinedRoomServerRoom;

@property(nonatomic, strong) NSString *roomId;
@property(nonatomic, strong) NSString *clientId;
@property(nonatomic, assign) BOOL isInitiator;
@property(nonatomic, strong) NSMutableArray *iceServers;
@property(nonatomic, strong) NSURL *webSocketURL;
@property(nonatomic, strong) NSURL *webSocketRestURL;
@property(nonatomic, readonly) BOOL isLoopback;
@property(nonatomic, readonly) BOOL localCameraSourceCreated;

@property(nonatomic, strong)
RTCMediaConstraints *defaultPeerConnectionConstraints;

//- (instancetype)initWithRoomServerClient:(id<ARDRoomServerClient>)rsClient
//                        signalingChannel:(id<ARDSignalingChannel>)channel
//                              turnClient:(id<ARDTURNClient>)turnClient
//                                delegate:(id<RTCAppClientDelegate>)delegate;

@end
