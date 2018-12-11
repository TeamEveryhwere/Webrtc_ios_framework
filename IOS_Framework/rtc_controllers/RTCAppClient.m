//
//  RTCAppClient.m
//  VaristarWebRtc_IOS
//
//  Created by 이다한 on 2018. 10. 11..
//

#import "RTCAppClient+Internal.h"

#import "WebRTC/RTCAudioTrack.h"
#import "WebRTC/RTCCameraVideoCapturer.h"
#import "WebRTC/RTCConfiguration.h"
#import "WebRTC/RTCFileLogger.h"
#import "WebRTC/RTCFileVideoCapturer.h"
#import "WebRTC/RTCIceServer.h"
#import "WebRTC/RTCLogging.h"
#import "WebRTC/RTCMediaConstraints.h"
#import "WebRTC/RTCMediaStream.h"
#import "WebRTC/RTCPeerConnectionFactory.h"
#import "WebRTC/RTCRtpSender.h"
#import "WebRTC/RTCRtpTransceiver.h"
#import "WebRTC/RTCTracing.h"
//#import "WebRTC/RTCVideoCodecFactory.h"
#import "WebRTC/RTCDefaultVideoEncoderFactory.h"
#import "WebRTC/RTCDefaultVideoDecoderFactory.h"
#import "WebRTC/RTCVideoSource.h"
#import "WebRTC/RTCVideoTrack.h"

//#import "ARDAppEngineClient.h"
//#import "ARDJoinResponse.h"
//#import "ARDMessageResponse.h"
#import "ARDSettingsModel.h"
//#import "ARDSignalingMessage.h"
//#import "ARDTURNClient+Internal.h"
#import "ARDUtilities.h"
//#import "ARDWebSocketChannel.h"
#import "RTCIceCandidate+JSON.h"
#import "RTCSessionDescription+JSON.h"
#import "RTCVideoCodecInfo+HumanReadable.h"

static NSString * const kRTCIceServerRequestUrl = @"https://appr.tc/params";

static NSString * const kARDAppClientErrorDomain = @"ARDAppClient";
static NSInteger const kARDAppClientErrorUnknown = -1;
static NSInteger const kARDAppClientErrorRoomFull = -2;
static NSInteger const kARDAppClientErrorCreateSDP = -3;
static NSInteger const kARDAppClientErrorSetSDP = -4;
static NSInteger const kARDAppClientErrorInvalidClient = -5;
static NSInteger const kARDAppClientErrorInvalidRoom = -6;
static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";
static NSString * const kARDVideoTrackKind = @"video";

// TODO(tkchin): Add these as UI options.
static BOOL const kARDAppClientEnableTracing = NO;
static BOOL const kARDAppClientEnableRtcEventLog = YES;
static int64_t const kARDAppClientAecDumpMaxSizeInBytes = 5e6;  // 5 MB.
static int64_t const kARDAppClientRtcEventLogMaxSizeInBytes = 5e6;  // 5 MB.
static int const kKbpsMultiplier = 1000;
NSUInteger *clientCount;

// We need a proxy to NSTimer because it causes a strong retain cycle. When
// using the proxy, |invalidate| must be called before it properly deallocs.
@interface RTCTimerProxy : NSObject

- (instancetype)initWithInterval:(NSTimeInterval)interval
                         repeats:(BOOL)repeats
                    timerHandler:(void (^)(void))timerHandler;
- (void)invalidate;

@end

@implementation RTCTimerProxy {
    NSTimer *_timer;
    void (^_timerHandler)(void);
}

- (instancetype)initWithInterval:(NSTimeInterval)interval
                         repeats:(BOOL)repeats
                    timerHandler:(void (^)(void))timerHandler {
    NSParameterAssert(timerHandler);
    if (self = [super init]) {
        _timerHandler = timerHandler;
        _timer = [NSTimer scheduledTimerWithTimeInterval:interval
                                                  target:self
                                                selector:@selector(timerDidFire:)
                                                userInfo:nil
                                                 repeats:repeats];
    }
    return self;
}

- (void)invalidate {
    [_timer invalidate];
}

- (void)timerDidFire:(NSTimer *)timer {
    _timerHandler();
}

@end

@interface RTCAppClient () <RTCVideoCapturerDelegate>
@end

@implementation RTCAppClient {
    RTCFileLogger *_fileLogger;
    RTCTimerProxy *_statsTimer;
    ARDSettingsModel *_settings;
    RTCVideoTrack *_localVideoTrack;
}

@synthesize shouldGetStats = _shouldGetStats;
@synthesize state = _state;
@synthesize delegate = _delegate;
//@synthesize roomServerClient = _roomServerClient;
//@synthesize channel = _channel;
//@synthesize loopbackChannel = _loopbackChannel;
//@synthesize turnClient = _turnClient;
@synthesize peerConnection = _peerConnection;
@synthesize factory = _factory;
@synthesize messageQueue = _messageQueue;
@synthesize isTurnComplete = _isTurnComplete;
@synthesize hasReceivedSdp  = _hasReceivedSdp;
@synthesize roomId = _roomId;
@synthesize clientId = _clientId;
@synthesize isInitiator = _isInitiator;
@synthesize iceServers = _iceServers;
@synthesize webSocketURL = _websocketURL;
@synthesize webSocketRestURL = _websocketRestURL;
@synthesize defaultPeerConnectionConstraints =
_defaultPeerConnectionConstraints;
@synthesize isLoopback = _isLoopback;
@synthesize localCameraSourceCreated = _localCameraSourceCreated;

- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<RTCAppClientDelegate>)delegate {
    if (self = [super init]) {
//        _roomServerClient = [[ARDAppEngineClient alloc] init];
        _delegate = delegate;
//        NSURL *turnRequestURL = [NSURL URLWithString:kRTCIceServerRequestUrl];
//        _turnClient = [[ARDTURNClient alloc] initWithURL:turnRequestURL];
        [self configure];
    }
    return self;
}

// TODO(tkchin): Provide signaling channel factory interface so we can recreate
// channel if we need to on network failure. Also, make this the default public
// constructor.
//- (instancetype)initWithRoomServerClient:(id<ARDRoomServerClient>)rsClient
//                        signalingChannel:(id<ARDSignalingChannel>)channel
//                              turnClient:(id<ARDTURNClient>)turnClient
//                                delegate:(id<RTCAppClientDelegate>)delegate {
//    NSParameterAssert(rsClient);
//    NSParameterAssert(channel);
//    NSParameterAssert(turnClient);
//    if (self = [super init]) {
//        _roomServerClient = rsClient;
//        _channel = channel;
//        _turnClient = turnClient;
//        _delegate = delegate;
//        [self configure];
//    }
//    return self;
//}

- (void)configure {
    _messageQueue = [NSMutableArray array];
    _iceServers = [NSMutableArray array];
    _fileLogger = [[RTCFileLogger alloc] init];
    [_fileLogger start];
}

- (void)dealloc {
    self.shouldGetStats = NO;
    [self disconnect];
    
    
}

- (void)setShouldGetStats:(BOOL)shouldGetStats {
    if (_shouldGetStats == shouldGetStats) {
        return;
    }
    if (shouldGetStats) {
        __weak RTCAppClient *weakSelf = self;
        _statsTimer = [[RTCTimerProxy alloc] initWithInterval:1
                                                      repeats:YES
                                                 timerHandler:^{
                                                     RTCAppClient *strongSelf = weakSelf;
                                                     [strongSelf.peerConnection statsForTrack:nil
                                                                             statsOutputLevel:RTCStatsOutputLevelDebug
                                                                            completionHandler:^(NSArray *stats) {
                                                                                dispatch_async(dispatch_get_main_queue(), ^{
                                                                                    RTCAppClient *strongSelf = weakSelf;
                                                                                    [strongSelf.delegate appClient:strongSelf didGetStats:stats];
                                                                                });
                                                                            }];
                                                 }];
    } else {
        [_statsTimer invalidate];
        _statsTimer = nil;
    }
    _shouldGetStats = shouldGetStats;
}

- (void)setState:(RTCAppClientState)state {
    if (_state == state) {
        return;
    }
    _state = state;
    [_delegate appClient:self didChangeState:_state];
}

- (NSArray<NSString *> *)videoResolutionArray {
    return [_settings availableVideoResolutions];
}


- (NSArray<RTCVideoCodecInfo *> *)videoCodecArray {
    return [_settings availableVideoCodecs];
}

- (void)connectWithId:(NSString *)handleId
             settings:(ARDSettingsModel *)settings
                count:(NSUInteger)count
        cameraCreated:(BOOL)cameraCreated
   setVideoResolution:(NSString *)setVideoResolution
        setMaxBitrate:(NSNumber *)setMaxBitrate
               userid:(NSString *)userid{
    //                 isLoopback:(BOOL)isLoopback {
    NSParameterAssert(handleId.length);
    NSParameterAssert(_state == kRTCAppClientStateDisconnected);
    _userId = userid;
    _settings = settings;
    //    _isLoopback = isLoopback;
    _localCameraSourceCreated = cameraCreated;
    NSLog(@"localCameraSourceCreated : %d", _localCameraSourceCreated);
    self.state = kRTCAppClientStateConnecting;
    clientCount = count;
    RTCDefaultVideoDecoderFactory *decoderFactory = [[RTCDefaultVideoDecoderFactory alloc] init];
    RTCDefaultVideoEncoderFactory *encoderFactory = [[RTCDefaultVideoEncoderFactory alloc] init];
    NSLog(@"decoderFactory : %@", decoderFactory.description);

    for (int i = 0; i < [encoderFactory.supportedCodecs count]; i++)
    {
        NSLog(@"전 encoderFactory.supportedCodecs : %@", [[encoderFactory.supportedCodecs objectAtIndex:i] humanReadableDescription]);
        NSString *codec = [[encoderFactory.supportedCodecs objectAtIndex:i] humanReadableDescription];
        if([codec isEqualToString:@"H264 (Baseline)"]){
            RTCVideoCodecInfo *videoCodec = self.videoCodecArray[i];
            [settings storeVideoCodecSetting:videoCodec];
            encoderFactory.preferredCodec = videoCodec;
        }
    }
    
    encoderFactory.preferredCodec = [settings currentVideoCodecSettingFromStore];
//    NSString *codecInfo = [[settings currentVideoCodecSettingFromStore] humanReadableDescription];
//    NSLog(@"encoderFactory : %@", codecInfo);
    for (int i = 0; i < [self.videoResolutionArray count]; i++)
    {
        NSString *videoResolution = self.videoResolutionArray[i];
        NSLog(@"setVideoResolution : %@, videoResolution : %@", setVideoResolution, videoResolution);
//        if([self.videoResolutionArray[i] isEqualToString:@"640x480"]){
        if([self.videoResolutionArray[i] isEqualToString:setVideoResolution]){
            [settings storeVideoResolutionSetting:videoResolution];
        }
        
    }
    
    RTCVideoCodecInfo *codecInfo = [settings currentVideoCodecSettingFromStore];
    int currentResolution_h = [settings currentVideoResolutionHeightFromStore];
    int currentResolution_w = [settings currentVideoResolutionWidthFromStore];
//    NSNumber *maxBitrate = [[NSNumber alloc] initWithInt:500];
    [settings storeMaxBitrateSetting:setMaxBitrate];
    
    NSNumber *maxbitrate = [settings currentMaxBitrateSettingFromStore];
    
    
    
    NSLog(@"maxbitrate : %@", setMaxBitrate);
    NSLog(@"currentMaxBitrateSettingFromStore : %@", maxbitrate);
    
    NSLog(@"currentResolution : %dX%d", currentResolution_w,currentResolution_h);
    
    NSString *stCodecInfo = [codecInfo humanReadableDescription];
    NSLog(@"currentCodec : %@", stCodecInfo);
    
    _factory = [[RTCPeerConnectionFactory alloc] initWithEncoderFactory:encoderFactory
                                                         decoderFactory:decoderFactory];
    
    
#if defined(WEBRTC_IOS)
    if (kARDAppClientEnableTracing) {
        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-trace.txt"];
        RTCStartInternalCapture(filePath);
    }
#endif
    
    // Request TURN.
    //    __weak RTCAppClient *weakSelf = self;
    [self startSignalingIfReady];
    //    [_turnClient requestServersWithCompletionHandler:^(NSArray *turnServers,
    //                                                       NSError *error) {
    //        if (error) {
    //            RTCLogError("Error retrieving TURN servers: %@",
    //                        error.localizedDescription);
    //        }
    //        RTCAppClient *strongSelf = weakSelf;
    //        [strongSelf.iceServers addObjectsFromArray:turnServers];
    //        strongSelf.isTurnComplete = YES;
    //        [strongSelf startSignalingIfReady];
    //    }];
    //
    //    // Join room on room server.
    //    [_roomServerClient joinRoomWithRoomId:roomId
    //                               isLoopback:isLoopback
    //                        completionHandler:^(ARDJoinResponse *response, NSError *error) {
    //                            RTCAppClient *strongSelf = weakSelf;
    //                            if (error) {
    //                                [strongSelf.delegate appClient:strongSelf didError:error];
    //                                return;
    //                            }
    //                            NSError *joinError =
    //                            [[strongSelf class] errorForJoinResultType:response.result];
    //                            if (joinError) {
    //                                RTCLogError(@"Failed to join room:%@ on room server.", roomId);
    //                                [strongSelf disconnect];
    //                                [strongSelf.delegate appClient:strongSelf didError:joinError];
    //                                return;
    //                            }
    //                            RTCLog(@"Joined room:%@ on room server.", roomId);
    //                            strongSelf.roomId = response.roomId;
    //                            strongSelf.clientId = response.clientId;
    //                            strongSelf.isInitiator = response.isInitiator;
    //                            for (ARDSignalingMessage *message in response.messages) {
    //                                if (message.type == kARDSignalingMessageTypeOffer ||
    //                                    message.type == kARDSignalingMessageTypeAnswer) {
    //                                    strongSelf.hasReceivedSdp = YES;
    //                                    [strongSelf.messageQueue insertObject:message atIndex:0];
    //                                } else {
    //                                    [strongSelf.messageQueue addObject:message];
    //                                }
    //                            }
    //                            strongSelf.webSocketURL = response.webSocketURL;
    //                            strongSelf.webSocketRestURL = response.webSocketRestURL;
    //                            [strongSelf registerWithColliderIfReady];
    //                            [strongSelf startSignalingIfReady];
    //                        }];
}

- (void)disconnect {
    
#if defined(WEBRTC_IOS)
    [_factory stopAecDump];
    [_peerConnection stopRtcEventLog];
#endif
    [_factory stopAecDump];
    [_peerConnection close];
    _peerConnection = nil;
    self.state = kRTCAppClientStateDisconnected;
    NSLog(@"%@ client closed", _userId);
    [_delegate appClient:self clientClosed:_userId];
    
#if defined(WEBRTC_IOS)
//    if (kARDAppClientEnableTracing) {
//        RTCStopInternalCapture();
//    }
#endif
}

#pragma mark - ARDSignalingChannelDelegate

//- (void)channel:(id<ARDSignalingChannel>)channel
//didReceiveMessage:(ARDSignalingMessage *)message {
//    switch (message.type) {
//        case kARDSignalingMessageTypeOffer:
//        case kARDSignalingMessageTypeAnswer:
//            // Offers and answers must be processed before any other message, so we
//            // place them at the front of the queue.
//            _hasReceivedSdp = YES;
//            [_messageQueue insertObject:message atIndex:0];
//            break;
//        case kARDSignalingMessageTypeCandidate:
//        case kARDSignalingMessageTypeCandidateRemoval:
//            [_messageQueue addObject:message];
//            break;
//        case kARDSignalingMessageTypeBye:
//            // Disconnects can be processed immediately.
//            [self processSignalingMessage:message];
//            return;
//    }
//    [self drainMessageQueueIfReady];
//}
//
//- (void)channel:(id<ARDSignalingChannel>)channel
// didChangeState:(ARDSignalingChannelState)state {
//    switch (state) {
//        case kARDSignalingChannelStateOpen:
//            break;
//        case kARDSignalingChannelStateRegistered:
//            break;
//        case kARDSignalingChannelStateClosed:
//        case kARDSignalingChannelStateError:
//            // TODO(tkchin): reconnection scenarios. Right now we just disconnect
//            // completely if the websocket connection fails.
//            [self disconnect];
//            break;
//    }
//}

#pragma mark - RTCPeerConnectionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeSignalingState:(RTCSignalingState)stateChanged {
    NSLog(@"Signaling state changed: %ld", (long)stateChanged);
    
   
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
          didAddStream:(RTCMediaStream *)stream {
    NSLog(@"Stream with %lu video tracks and %lu audio tracks was added.",
           (unsigned long)stream.videoTracks.count,
           (unsigned long)stream.audioTracks.count);
//        [stream.audioTracks[0] setIsEnabled:0];
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didStartReceivingOnTransceiver:(RTCRtpTransceiver *)transceiver {
    RTCMediaStreamTrack *track = transceiver.receiver.track;
    NSLog(@"Now receiving %@ on track %@.", track.kind, track.trackId);
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
       didRemoveStream:(RTCMediaStream *)stream {
    NSLog(@"Stream was removed.");
}

- (void)peerConnectionShouldNegotiate:(RTCPeerConnection *)peerConnection {
    NSLog(@"WARNING: Renegotiation needed but unimplemented.");
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceConnectionState:(RTCIceConnectionState)newState {
    switch (newState) {
        case RTCIceConnectionStateNew:
            NSLog(@"ICE state changed RTCIceConnectionStateNew: %ld", (long)newState);
            break;
        case RTCIceConnectionStateCount:
            NSLog(@"ICE state changed RTCIceConnectionStateCount: %ld", (long)newState);
            break;
        case RTCIceConnectionStateClosed:
            NSLog(@"ICE state changed RTCIceConnectionStateClosed: %ld", (long)newState);
            break;
        case RTCIceConnectionStateFailed:
            NSLog(@"ICE state changed RTCIceConnectionStateFailed: %ld", (long)newState);
            break;
        case RTCIceConnectionStateChecking:
            NSLog(@"ICE state changed RTCIceConnectionStateChecking: %ld", (long)newState);
            break;
        case RTCIceConnectionStateCompleted:
            NSLog(@"ICE state changed RTCIceConnectionStateCompleted: %ld", (long)newState);
            break;
        case RTCIceConnectionStateConnected:
            NSLog(@"ICE state changed RTCIceConnectionStateConnected: %ld", (long)newState);
            break;
        case RTCIceConnectionStateDisconnected:
            NSLog(@"ICE state changed RTCIceConnectionStateDisconnected: %ld", (long)newState);
            break;
        default:
            break;
    }
    NSLog(@"ICE state changed: %ld", (long)newState);
    dispatch_async(dispatch_get_main_queue(), ^{
        [_delegate appClient:self didChangeConnectionState:newState];
    });
    
   
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didChangeIceGatheringState:(RTCIceGatheringState)newState {
    switch (newState) {
        case RTCIceGatheringStateNew:
            NSLog(@"ICE gathering state changed RTCIceGatheringStateNew: %ld", (long)newState);
            break;
        case RTCIceGatheringStateGathering:
            NSLog(@"ICE gathering state changed RTCIceGatheringStateGathering: %ld", (long)newState);
            break;
        case RTCIceGatheringStateComplete:
            NSLog(@"ICE gathering state changed RTCIceGatheringStateComplete: %ld", (long)newState);
            break;
        default:
            break;
    }
    
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didGenerateIceCandidate:(RTCIceCandidate *)candidate {
    
    
    NSString *sdpMid = candidate.sdpMid;
    NSString *sdp = candidate.sdp;
    NSArray *array = [sdp componentsSeparatedByString:@" "];
    NSString *c = [@"::ffff:" stringByAppendingString:[array objectAtIndex:4]];
    
    NSString *newSdp= [sdp stringByReplacingOccurrencesOfString:[array objectAtIndex:4] withString:c];
    NSLog(@"newSdp : %@", newSdp);
//    [array replaceObjectAtIndex:3 withObject:c];
    
    for (int i=0; i<[array count];i++){
        if (i == [array count] -1){
//            newSdp += [array obje]
        }
    }
//    RTCIceCandidate *newCandidate = [[RTCIceCandidate alloc]initWithSdp:newSdp sdpMLineIndex:candidate.sdpMLineIndex sdpMid:candidate.sdpMid];
    
    NSLog(@"peerConnection ICE sdpMid %@, length : %lu", sdpMid, (unsigned long)_generatedVideoIceCandidate.sdp.length);
    if ([sdpMid isEqualToString:@"video"] || [sdpMid isEqualToString:@"1"]) {
        if (_generatedVideoIceCandidate.sdp.length < 1) {
            NSString *sdp = candidate.sdp;
            
            _generatedVideoIceCandidate = candidate;
        }
        NSLog(@"peerConnection  generatedVideoIceCandidate : %@", _generatedVideoIceCandidate.sdp);
    } else {
        if (_generatedAudioIceCandidate.sdp.length < 1) {
            _generatedAudioIceCandidate = candidate;
        }
        NSLog(@"peerConnection generatedAudioIceCandidate : %@", _generatedAudioIceCandidate.sdp);
    }
    
}



- (void)peerConnection:(RTCPeerConnection *)peerConnection
didRemoveIceCandidates:(NSArray<RTCIceCandidate *> *)candidates {
    dispatch_async(dispatch_get_main_queue(), ^{
        //        ARDICECandidateRemovalMessage *message =
        //        [[ARDICECandidateRemovalMessage alloc]
        //         initWithRemovedCandidates:candidates];
        //        [self sendSignalingMessage:message];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
    didOpenDataChannel:(RTCDataChannel *)dataChannel {
}

#pragma mark - RTCSessionDescriptionDelegate
// Callbacks for this delegate occur on non-main thread and need to be
// dispatched back to main queue as needed.

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didCreateSessionDescription:(RTCSessionDescription *)sdp
                 error:(NSError *)error {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to create session description. Error: %@", error);
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to create session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorCreateSDP
                                   userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
            return;
        }
                NSLog(@"sdp : %@",sdp.sdp);
        __weak RTCAppClient *weakSelf = self;
        [_peerConnection setLocalDescription:sdp
                           completionHandler:^(NSError *error) {
                               RTCAppClient *strongSelf = weakSelf;
                               [strongSelf peerConnection:strongSelf.peerConnection
                        didSetSessionDescriptionWithError:error type:@"offer"];
                           }];
        //        ARDSessionDescriptionMessage *message =
        //        [[ARDSessionDescriptionMessage alloc] initWithDescription:sdp];
        //
        //        [self sendSignalingMessage:message];
        [self setMaxBitrateForPeerConnectionVideoSender];
    });
}

- (void)peerConnection:(RTCPeerConnection *)peerConnection
didSetSessionDescriptionWithError:(NSError *)error
                  type:(NSString *)type{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error) {
            NSLog(@"Failed to set session description. Error: %@", error);
            [self disconnect];
            NSDictionary *userInfo = @{
                                       NSLocalizedDescriptionKey: @"Failed to set session description.",
                                       };
            NSError *sdpError =
            [[NSError alloc] initWithDomain:kARDAppClientErrorDomain
                                       code:kARDAppClientErrorSetSDP
                                   userInfo:userInfo];
            [_delegate appClient:self didError:sdpError];
            return;
        }
        // If we're answering and we've just set the remote offer we need to create
        // an answer and set the local description.
        [_delegate appClient:self didSetSessionDescriptionWithError:nil type:type];
        //        if (!_isInitiator && !_peerConnection.localDescription) {
        //            RTCMediaConstraints *constraints = [self defaultAnswerConstraints];
        //            __weak RTCAppClient *weakSelf = self;
        //            [_peerConnection answerForConstraints:constraints
        //                                completionHandler:^(RTCSessionDescription *sdp,
        //                                                    NSError *error) {
        //                                    RTCAppClient *strongSelf = weakSelf;
        //                                    [strongSelf peerConnection:strongSelf.peerConnection
        //                                   didCreateSessionDescription:sdp
        //                                                         error:error];
        //                                }];
        //        }
    });
}

#pragma mark - Private

#if defined(WEBRTC_IOS)

- (NSString *)documentsFilePathForFileName:(NSString *)fileName {
    NSParameterAssert(fileName.length);
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
                                                         NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirPath = paths.firstObject;
    NSString *filePath =
    [documentsDirPath stringByAppendingPathComponent:fileName];
    return filePath;
}

#endif

- (BOOL)hasJoinedRoomServerRoom {
    return _clientId.length;
}

// Begins the peer connection connection process if we have both joined a room
// on the room server and tried to obtain a TURN server. Otherwise does nothing.
// A peer connection object will be created with a stream that contains local
// audio and video capture. If this client is the caller, an offer is created as
// well, otherwise the client will wait for an offer to arrive.
- (void)startSignalingIfReady {
    //    if (!_isTurnComplete || !self.hasJoinedRoomServerRoom) {
    //        return;
    //    }
    self.state = kRTCAppClientStateConnected;
    
    // Create peer connection.
    RTCMediaConstraints *constraints = [self defaultPeerConnectionConstraints];
    RTCConfiguration *config = [[RTCConfiguration alloc] init];
    //    config.iceServers = _iceServers;
    config.sdpSemantics = RTCSdpSemanticsUnifiedPlan;
    config.maxIPv6Networks = 1;
    _peerConnection = [_factory peerConnectionWithConfiguration:config
                                                    constraints:constraints
                                                       delegate:self];
    // Create AV senders.
    [self createMediaSenders];
    //    if (_isInitiator) {
    // Send offer.
    __weak RTCAppClient *weakSelf = self;
    [_peerConnection offerForConstraints:[self defaultOfferConstraints]
                       completionHandler:^(RTCSessionDescription *sdp,
                                           NSError *error) {
                           RTCAppClient *strongSelf = weakSelf;
                          NSLog(@"create offer sdp : %@",sdp);
                           [strongSelf peerConnection:strongSelf.peerConnection
                          didCreateSessionDescription:sdp
                                                error:error];
                       }];
    //    } else {
    //        // Check if we've received an offer.
    //        [self drainMessageQueueIfReady];
    //    }
#if defined(WEBRTC_IOS)
    // Start event log.
//    if (kARDAppClientEnableRtcEventLog) {
//        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-rtceventlog"];
//        if (![_peerConnection startRtcEventLogWithFilePath:filePath
//                                            maxSizeInBytes:kARDAppClientRtcEventLogMaxSizeInBytes]) {
//            RTCLogError(@"Failed to start event logging.");
//        }
//    }
//
//    // Start aecdump diagnostic recording.
//    if ([_settings currentCreateAecDumpSettingFromStore]) {
//        NSString *filePath = [self documentsFilePathForFileName:@"webrtc-audio.aecdump"];
//        if (![_factory startAecDumpWithFilePath:filePath
//                                 maxSizeInBytes:kARDAppClientAecDumpMaxSizeInBytes]) {
//            RTCLogError(@"Failed to start aec dump.");
//        }
//    }
#endif
}

// Processes the messages that we've received from the room server and the
// signaling channel. The offer or answer message must be processed before other
// signaling messages, however they can arrive out of order. Hence, this method
// only processes pending messages if there is a peer connection object and
// if we have received either an offer or answer.
- (void)drainMessageQueueIfReady {
    if (!_peerConnection || !_hasReceivedSdp) {
        return;
    }
//    for (ARDSignalingMessage *message in _messageQueue) {
//        [self processSignalingMessage:message];
//    }
    [_messageQueue removeAllObjects];
}

-(void)setRemoteDescription:(RTCSessionDescription *)description {
    [_peerConnection setRemoteDescription:description
                        completionHandler:^(NSError *error) {
                            [self peerConnection:self.peerConnection
               didSetSessionDescriptionWithError:error type:@"answer"];
                        }];
}
-(void)addIceCandiDate:(RTCIceCandidate *)iceCandidate{
    [_peerConnection addIceCandidate:iceCandidate];
}






- (void)setMaxBitrateForPeerConnectionVideoSender {
    for (RTCRtpSender *sender in _peerConnection.senders) {
        if (sender.track != nil) {
            if ([sender.track.kind isEqualToString:kARDVideoTrackKind]) {
                [self setMaxBitrate:[_settings currentMaxBitrateSettingFromStore] forVideoSender:sender];
            }
        }
    }
}

- (void)setMaxBitrate:(NSNumber *)maxBitrate forVideoSender:(RTCRtpSender *)sender {
    if (maxBitrate.intValue <= 0) {
        return;
    }
    
    RTCRtpParameters *parametersToModify = sender.parameters;
    for (RTCRtpEncodingParameters *encoding in parametersToModify.encodings) {
        encoding.maxBitrateBps = @(maxBitrate.intValue * kKbpsMultiplier);
    }
    [sender setParameters:parametersToModify];
}

- (RTCRtpTransceiver *)videoTransceiver {
    for (RTCRtpTransceiver *transceiver in _peerConnection.transceivers) {
        if (transceiver != nil){
            NSLog(@"transceiver.mediaType : %lu", transceiver.mediaType);
            if (transceiver.mediaType == RTCRtpMediaTypeVideo) {
                return transceiver;
            }
            
        }
        
    }
    return nil;
}
- (RTCRtpTransceiver *)audioTranceiver {
    for (RTCRtpTransceiver *transceiver in _peerConnection.transceivers) {
        if (transceiver != nil){
            NSLog(@"transceiver.mediaType : %lu", transceiver.mediaType);
            if (transceiver.mediaType == RTCRtpMediaTypeAudio) {
                return transceiver;
            }
            
        }
        
    }
    return nil;
}


- (void)createMediaSenders {
    RTCMediaConstraints *constraints = [self defaultMediaAudioConstraints];
    RTCAudioSource *source = [_factory audioSourceWithConstraints:constraints];
    _localAudioTrack = [_factory audioTrackWithSource:source
                                                  trackId:kARDAudioTrackId];
    
    [_peerConnection addTrack:_localAudioTrack streamIds:@[ kARDMediaStreamId ]];
    
        _localVideoTrack = [self createLocalVideoTrack];
        if (_localVideoTrack) {
            [_delegate appClient:self didReceiveLocalAudioTrack:_localAudioTrack];
            
            
            [_peerConnection addTrack:_localVideoTrack streamIds:@[ kARDMediaStreamId ]];
//            [_delegate appClient:self didReceiveLocalVideoTrack:_localVideoTrack];
            // We can set up rendering for the remote track right away since the transceiver already has an
            // RTCRtpReceiver with a track. The track will automatically get unmuted and produce frames
            // once RTP is received.
            
            _remoteVideoTrack = (RTCVideoTrack *)([self videoTransceiver].receiver.track);
            _trackId = _remoteVideoTrack.trackId;
            [_delegate appClient:self didReceiveRemoteVideoTrack:_remoteVideoTrack userId:_userId];
            
            _remoteAudioTrack = (RTCAudioTrack *)([self audioTranceiver].receiver.track);
            
            [_delegate appClient:self didReceiveRemoteAudioTrack:_remoteAudioTrack];
        }

}

-(void)localVoiceOnoff:(bool)enable{
    [_localAudioTrack setIsEnabled:enable];
}



- (RTCVideoTrack *)createLocalVideoTrack {
    if ([_settings currentAudioOnlySettingFromStore]) {
        return nil;
    }
    
    RTCVideoSource *source = [_factory videoSource];
    if (!_localCameraSourceCreated){
        NSLog(@"_localCameraSourceCreated");
        [_delegate appClient:self updateCameraCreated:YES];
#if !TARGET_IPHONE_SIMULATOR
//        RTCCameraVideoCapturer *capturer = [[RTCCameraVideoCapturer alloc] initWithDelegate:source];
        
        
//        capturer.delegate = self;
//        [_delegate appClient:self didCreateLocalCapturer:capturer source:source];
        [_delegate appClient:self createLocalCapturerSource:source];
        
#else
#if defined(__IPHONE_11_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_11_0)
        if (@available(iOS 10, *)) {
            RTCFileVideoCapturer *fileCapturer = [[RTCFileVideoCapturer alloc] initWithDelegate:source];
            [_delegate appClient:self didCreateLocalFileCapturer:fileCapturer];
        }
#endif
#endif
    }
    return [_factory videoTrackWithSource:source trackId:kARDVideoTrackId];
}
//- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
//    NSLog(@"didOutputSampleBuffer");
//}
//
- (void)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(RTCVideoFrame *)frame{
    NSLog(@"didCaptureVideoFrame");
}



#pragma mark - Defaults

- (RTCMediaConstraints *)defaultMediaAudioConstraints {
    NSDictionary *mandatoryConstraints = @{
                                           @"maxHeight" : @"480",
                                           @"maxWdith" : @"640",
                                           @"maxFrameRate" : @"25"
                                           };
    RTCMediaConstraints *constraints =
    [[RTCMediaConstraints alloc] initWithMandatoryConstraints:mandatoryConstraints
                                          optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultAnswerConstraints {
    return [self defaultOfferConstraints];
}

- (RTCMediaConstraints *)defaultOfferConstraints {
    NSMutableDictionary *mandatoryConstraints;
    
    if (clientCount != 0) {
        mandatoryConstraints = @{
                                 @"OfferToReceiveAudio" : @"true",
                                 @"OfferToReceiveVideo" : @"true"
                                 };
    } else {
        mandatoryConstraints = @{
                                 @"OfferToReceiveAudio" : @"false",
                                 @"OfferToReceiveVideo" : @"false"
                                 };
    }
    
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:mandatoryConstraints
     optionalConstraints:nil];
    return constraints;
}

- (RTCMediaConstraints *)defaultPeerConnectionConstraints {
    if (_defaultPeerConnectionConstraints) {
        return _defaultPeerConnectionConstraints;
    }
    NSString *value = _isLoopback ? @"false" : @"true";
    NSDictionary *optionalConstraints = @{
                                          @"DtlsSrtpKeyAgreement" : value ,
                                           @"googIPv6" : @"true"
                                           };
    RTCMediaConstraints* constraints =
    [[RTCMediaConstraints alloc]
     initWithMandatoryConstraints:nil
     optionalConstraints:optionalConstraints];
    return constraints;
}



@end
