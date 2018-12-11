//
//  UnityApiController.m
//  Unity-iPhone
//
//  Created by 이다한 on 2018. 11. 12..
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "JFRWebSocket.h"
//#import "UnityApiController.h"
#import <CommonCrypto/CommonHMAC.h>
#import <AVFoundation/AVFoundation.h>

#import "WebRTC/RTCConfiguration.h"

#import "WebRTC/RTCMediaConstraints.h"
#import "WebRTC/RTCMediaStream.h"

#import "WebRTC/RTCPeerConnectionFactory.h"
#import "WebRTC/RTCPeerConnection.h"
#import "WebRTC/RTCSessionDescription.h"

#import "WebRTC/RTCIceCandidate.h"
#import "WebRTC/RTCRtpSender.h"
#import "WebRTC/RTCRtpTransceiver.h"
#import "WebRTC/RTCTracing.h"
//#import "WebRTC/RTCVideoCodecFactory.h"
#import "WebRTC/RTCDefaultVideoEncoderFactory.h"
#import "WebRTC/RTCDefaultVideoDecoderFactory.h"
#import "WebRTC/RTCVideoSource.h"
#import "WebRTC/RTCVideoTrack.h"

#import <WebRTC/RTCI420Buffer.h>
#import <WebRTC/RTCNativeI420Buffer.h>
//#import <WebRTC/RTCNativeI420Buffer+Private.h>

#import <WebRTC/RTCYUVPlanarBuffer.h>
#import <WebRTC/RTCCVPixelBuffer.h>

#import "WebRTC/RTCAudioSession.h"
#import "WebRTC/RTCAudioTrack.h"
#import <WebRTC/RTCAudioSessionConfiguration.h>

#import "RTCAppClient.h"
#import "ARDSettingsModel.h"


#import "WebRTC/RTCEAGLVideoView.h"





@interface ApiController () <JFRWebSocketDelegate, RTCAppClientDelegate, RTCAudioSessionDelegate, RTCVideoTrackDelegate>

@property(nonatomic, strong)JFRWebSocket *socket;
@property (nonatomic, assign) BOOL localCameraSourceCreated;
@end


@implementation UnityApiController

RTCVideoFrame *newFrame;

NSMutableArray <RTCAppClient *> *clients;
int check = 0;
NSString *handleId = @"b4c23499-ddae-506c-8293-9090210f07db";
NSString *operation = @"IAM";
NSString *serverSecret = @"DyYtEufNq";
NSMutableString *ms_channel_id = @"";
NSMutableString *sdpType = @"offer";

NSMutableString *remoteView1rendered = @"false";
static NSString * const kARDMediaStreamId = @"ARDAMS";
static NSString * const kARDAudioTrackId = @"ARDAMSa0";
static NSString * const kARDVideoTrackId = @"ARDAMSv0";
static NSString * const kARDVideoTrackKind = @"video";

ARDSettingsModel *settings;

RTCIceCandidate *generatedAudioIceCandidate;
RTCIceCandidate *generatedVideoIceCandidate;
RTCIceCandidate *recievedAudioIceCandidate;
RTCIceCandidate *recievedVideoIceCandidate;
NSString *feed_id;
NSString *feed_channel_id;
NSMutableArray *feed_ids;
NSMutableArray *feed_infos;
NSMutableString *trx_id;
NSMutableArray *feed_channel_ids;
NSMutableArray *trx_ids;
NSMutableArray *userIds;

int *connectionId = 0;
UIImage *uiImage;

NSString *videoResoultion;
NSNumber *maxBitrate;

RTCVideoTrack *localVideoTrack2;
RTCVideoTrack *remoteVideoTrack1;
RTCVideoTrack *remoteVideoTrack2;
RTCVideoTrack *remoteVideoTrack3;
RTCVideoTrack *remoteVideoTrack4;
RTCVideoTrack *remoteVideoTrack5;
RTCVideoSource *localVideoSource;
NSArray<RTCVideoTrack *> *remoteTrackArray;

RTCAudioTrack *remoteAudioTrack1;
RTCAudioTrack *localAudioTrack;

RTCEAGLVideoView *remoteView1;
RTCEAGLVideoView *remoteView2;
RTCEAGLVideoView *remoteView3;
RTCEAGLVideoView *remoteView4;
RTCEAGLVideoView *remoteView5;

AVAudioSessionPortOverride _portOverride;

RTCAudioSession *audioSession;
RTCAudioSessionConfiguration *configuration;
// 1 = on, 0 = off
int localAudioOnoff = 1;
int remoteAudioOnoff = 1;

#pragma mark - Data source

- (NSArray<NSString *> *)videoResolutionArray {
    return [settings availableVideoResolutions];
}

- (NSArray<RTCVideoCodecInfo *> *)videoCodecArray {
    return [settings availableVideoCodecs];
}


- (instancetype)init {
    return [self initWithDelegate:nil];
}

- (instancetype)initWithDelegate:(id<UnityApiControllerDelegate>)delegate {
    if (self = [super init]) {
        _delegate = delegate;
    }
    
    videoResoultion = @"640x480";
    maxBitrate = [[NSNumber alloc] initWithInt:700];
    return self;
}
- (void)setVideoResolution:(NSString *)setVideoResolution{
    videoResoultion = setVideoResolution;
    NSLog(@"setVideoResolution at init : %@", videoResoultion);
}


- (void)setMaxBitrate:(int) setMaxBitrate{
    if (setMaxBitrate > 1000){
        int adjustBitrate = setMaxBitrate / 1000;
        maxBitrate = [[NSNumber alloc] initWithInt:adjustBitrate];
    } else {
        maxBitrate = [[NSNumber alloc] initWithInt:setMaxBitrate];
    }
}

- (void)controller:(UnityApiController *)controller
        getPcmData:(bool)sttOnoff {
    
    NSLog(@"controller getPcmData %d", sttOnoff);
    
}


- (void)socketConnect:(JFRWebSocket*)getSocket mHandleId:(NSString *)mHandleId getSecret:(NSString *)getSecret {
    //start
    
    remoteView1 = [[RTCEAGLVideoView alloc] init];
    remoteView2 = [[RTCEAGLVideoView alloc] init];
    remoteView3 = [[RTCEAGLVideoView alloc] init];
    remoteView4 = [[RTCEAGLVideoView alloc] init];
    remoteView5 = [[RTCEAGLVideoView alloc] init];
    
    handleId = mHandleId;
    serverSecret = getSecret;
    
    feed_channel_ids = [[NSMutableArray alloc] init];
    clients = [[NSMutableArray alloc]init];
    trx_ids = [[NSMutableArray alloc] init];
    userIds = [[NSMutableArray alloc] init];
//    remoteViewArray = [NSArray arrayWithObjects: self.remoteView1, self.remoteView2, self.remoteView3, nil];
    remoteTrackArray = [NSArray arrayWithObjects: remoteVideoTrack1, remoteVideoTrack2, remoteVideoTrack3, nil];
    //
    //    //      GoogleWebRTC 라이브러리 init peerConnectionFactory
    ARDSettingsModel *settingsModel = [[ARDSettingsModel alloc] init];
    settings = settingsModel;
    
    
    audioSession = [RTCAudioSession sharedInstance];
    [audioSession addDelegate:self];
    
    self.socket = getSocket;
    self.socket.delegate = self;
    [self.socket connect];
    
//    [self chekd];
}

- (void)requestJoin:(JFRWebSocket *)getSocket res_type:(NSString *)res_type handle_id:(NSString *)handle_id user_id:(NSString *)user_id resource_secret:(NSString *)resource_secret mode_flag:(NSString *)mode_flag {
    
    remoteView1 = [[RTCEAGLVideoView alloc] init];
    remoteView2 = [[RTCEAGLVideoView alloc] init];
    remoteView3 = [[RTCEAGLVideoView alloc] init];
    remoteView4 = [[RTCEAGLVideoView alloc] init];
    remoteView5 = [[RTCEAGLVideoView alloc] init];
    
    handleId = handle_id;
    serverSecret = resource_secret;
    
    feed_channel_ids = [[NSMutableArray alloc] init];
    clients = [[NSMutableArray alloc]init];
    trx_ids = [[NSMutableArray alloc] init];
    userIds = [[NSMutableArray alloc] init];
    //    remoteViewArray = [NSArray arrayWithObjects: self.remoteView1, self.remoteView2, self.remoteView3, nil];
    remoteTrackArray = [NSArray arrayWithObjects: remoteVideoTrack1, remoteVideoTrack2, remoteVideoTrack3, nil];
    //
    //    //      GoogleWebRTC 라이브러리 init peerConnectionFactory
    ARDSettingsModel *settingsModel = [[ARDSettingsModel alloc] init];
    settings = settingsModel;
    
    
    audioSession = [RTCAudioSession sharedInstance];
    [audioSession addDelegate:self];
    [self configureAudioSession];
    
    self.socket = getSocket;
    self.socket.delegate = self;
    [self.socket connect];
    
}

- (void)audioSession:(RTCAudioSession *)audioSession didSetActive:(BOOL)active{
    NSLog(@"audioSession didSetActive %d", active);
}


- (void) chekd  {
    NSLog(@"what?");
}



-(void)websocketDidConnect:(JFRWebSocket*)socket {
    NSLog(@"websocket is connected");
}
-(void)websocketDidDisconnect:(JFRWebSocket*)socket error:(NSError*)error {
    NSLog(@"websocket is disconnected: %@",[error localizedDescription]);
    NSLog(@"websocket is disconnected: %@",error.description);
    [_delegate controller:self onErrorPeer:@"socket_disconnected" userId:@""];
}

-(void)websocket:(JFRWebSocket*)socket didReceiveMessage:(NSString*)string {
    NSLog(@"got some text: %@",string);
    
    NSError * err;
    NSData * receivedData = [string dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *recievedDict = [NSJSONSerialization JSONObjectWithData:receivedData options:kNilOptions error:&err];
    
    NSString *getOperation = [recievedDict objectForKey:@"operation"];
    if ([getOperation isEqualToString:@"WHO"]){
        
        [self whoOperation];
        
    } else if ([getOperation isEqualToString:@"WELCOME"]){
        
        [self welcomeOperation];
        
        
        
    } else if ([getOperation isEqualToString:@"res_create_ms_channel"]){
        NSNumber *result = [recievedDict objectForKey:@"result"];
        
        NSLog(@"res_create_ms_channel result : %@", result);
        int inResult = (int)result.intValue;
        if (inResult != 200) {
            [_delegate controller:self onErrorPeer:@"res_create_ms_channel" userId:@""];
        } else {
            //init peerConnection
            ms_channel_id = [recievedDict objectForKey:@"ms_channel_id"];
            feed_ids = [recievedDict objectForKey:@"feed_ids"];
            NSArray *feed_infos = [recievedDict objectForKey:@"feed_infos"];
            
            //create feed_channel_ids
            if ([feed_infos count] > 0){
                for (int i=0; i<[feed_infos count]; i++){
                    NSDictionary *feed_info_dict = [feed_infos objectAtIndex:i];
                    feed_channel_id = [feed_info_dict objectForKey:@"feed_channel_id"];
                    if (![feed_channel_ids containsObject:feed_channel_id]) {
                        [feed_channel_ids addObject:feed_channel_id];
                    }
                }
            }
            
            if ([clients count] == 0){
                //publishing
                RTCAppClient *client = [[RTCAppClient alloc] initWithDelegate:self];
                
                [client connectWithId:handleId settings:settings count:[clients count] cameraCreated:self.localCameraSourceCreated setVideoResolution:videoResoultion setMaxBitrate:maxBitrate userid:feed_channel_id];
                [clients addObject:client];
                
            } else {
                //subscribing
                if ([feed_infos count] > 0){
                    for (int i=0; i<[feed_infos count]; i++){
                        NSDictionary *feed_info_dict = [feed_infos objectAtIndex:i];
                        feed_channel_id = [feed_info_dict objectForKey:@"feed_channel_id"];
                        
                        
                        if (![feed_channel_ids containsObject:feed_channel_id]) {
                            [feed_channel_ids addObject:feed_channel_id];
                            NSLog(@"get feed_channel_id %lu : %@", i,[feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]);
                            
                            //subscribing
                            RTCAppClient *client = [[RTCAppClient alloc] initWithDelegate:self];
                            [client connectWithId:handleId settings:settings count:[clients count] cameraCreated:self.localCameraSourceCreated setVideoResolution:videoResoultion setMaxBitrate:maxBitrate userid:feed_channel_id];
                            
                            [clients addObject:client];
                            
                        }
                        
                        
                    }
                } else {
                    //publishing
                    RTCAppClient *client = [[RTCAppClient alloc] initWithDelegate:self];
                    [client connectWithId:handleId settings:settings count:[clients count] cameraCreated:self.localCameraSourceCreated setVideoResolution:videoResoultion setMaxBitrate:maxBitrate userid:feed_channel_id];
                    [clients addObject:client];
                    
                }
            }
        }
        
        
        
        
        
    } else if ([getOperation isEqualToString:@"res_send_sdp"]){
        NSNumber *result = [recievedDict objectForKey:@"result"];
        
        NSLog(@"res_create_ms_channel result : %@", result);
        int inResult = (int)result.intValue;
        if (inResult != 200) {
            [_delegate controller:self onErrorPeer:@"res_send_sdp" userId:@""];
            return;
        }
        //set answer sdp to connection
        NSDictionary *receivedSdp = [recievedDict objectForKey:@"sdp"];
        NSString *stSdp = [receivedSdp objectForKey:@"sdp"];
        sdpType = [receivedSdp objectForKey:@"type"];
        
        
        RTCSessionDescription *answerSdp = [[RTCSessionDescription alloc]initWithType:RTCSdpTypeAnswer sdp:stSdp];
        
        //        NSLog(@"get sdp type :%@, sdp : %@", sdpType, answerSdp);
        NSLog(@"get sdp type :%@", sdpType);
        
        if ([clients count] > 0){
            [[clients objectAtIndex:[clients count]-1] setRemoteDescription:answerSdp];
        }
        
        
        
    } else if ([getOperation isEqualToString:@"send_ice"]){
        
        //get ice from server and add to peer connection
        NSDictionary *receivedCandidate = [recievedDict objectForKey:@"candidate"];
        NSString *stCandidate = [receivedCandidate objectForKey:@"candidate"];
        NSString *sdpMid = [receivedCandidate objectForKey:@"sdpMid"];
        int sdpMLineIndex = [[receivedCandidate objectForKey:@"sdpMLineIndex"] intValue];
        NSArray *array = [stCandidate componentsSeparatedByString:@" "];
        if ([sdpMid isEqualToString:@"audio"] || [sdpMid isEqualToString:@"0"]){
            if ([stCandidate containsString:@"::ffff:"]) {
//
//                // local candidate ::
//                NSString *newSdp= [stCandidate stringByReplacingOccurrencesOfString:@"::" withString:@"0:"];
//                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:newSdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
//                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:stCandidate sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
//                recievedAudioIceCandidate = candidate;
//                NSLog(@"audio get candidate : %@, sdpMid : %@, sdpMLineIndex : %d", candidate.sdp, sdpMid, sdpMLineIndex);
            }else{
                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:stCandidate sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
                recievedAudioIceCandidate = candidate;
//                NSLog(@"audio get candidate : %@, sdpMid : %@, sdpMLineIndex : %d", candidate.sdp, sdpMid, sdpMLineIndex);
            }
            
        } else {
            if ([stCandidate containsString:@"::ffff:"]) {
//                NSString *newSdp= [stCandidate stringByReplacingOccurrencesOfString:@"::" withString:@"0:"];
//                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:newSdp sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
//                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:stCandidate sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
//                recievedVideoIceCandidate = candidate;
//                NSLog(@"video get candidate : %@, sdpMid : %@, sdpMLineIndex : %d", candidate.sdp, sdpMid, sdpMLineIndex);
            }else{
                RTCIceCandidate *candidate = [[RTCIceCandidate alloc] initWithSdp:stCandidate sdpMLineIndex:sdpMLineIndex sdpMid:sdpMid];
                recievedVideoIceCandidate = candidate;
//                NSLog(@"video get candidate : %@, sdpMid : %@, sdpMLineIndex : %d", candidate.sdp, sdpMid, sdpMLineIndex);
            
            }
            
        }
        
    } else if ([getOperation isEqualToString:@"res_set_ms_channel"]){
        NSNumber *result = [recievedDict objectForKey:@"result"];
        int inResult = (int) result.intValue;
        if (inResult != 200) {
            [_delegate controller:self onErrorPeer:@"res_set_ms_channel" userId:@""];
            return;
        }
//        NSLog(@"res_set_ms_channel got");
        NSDictionary *receivedEventOption = [recievedDict objectForKey:@"channel_option"];
//        NSLog(@"receivedEventOption : %@", receivedEventOption);
        NSString *stStream_flag = [receivedEventOption objectForKey:@"stream_flag"];
//        NSLog(@"stStream_flag : %@", stStream_flag);
        int stream_flag = stStream_flag.intValue;
//        NSLog(@"stream_flag : %d", stream_flag);
        ms_channel_id = [recievedDict objectForKey:@"ms_channel_id"];
        for (int i=0; i<[clients count]; i++){
            if([[clients objectAtIndex:i].userId isEqualToString:ms_channel_id]){
                [_delegate controller:self onEventPeer:@"res_set_ms_channel" userId:ms_channel_id stream_flag:stream_flag videoId:i mode_flag:@"0"];
                return;
            }
        }
        
        [_delegate controller:self onEventPeer:@"res_set_ms_channel" userId:@"" stream_flag:stream_flag videoId:0 mode_flag:@"0"];
        
    } else if ([getOperation isEqualToString:@"event"]){
        
        // start subsicribe peer
        NSString *type = [recievedDict objectForKey:@"type"];
        NSString *trx_id = [recievedDict objectForKey:@"trx_id"];
        ms_channel_id = [recievedDict objectForKey:@"ms_channel_id"];
        
        
        
        if ([type isEqualToString:(@"new_feed")]) {
            NSDictionary *receivedEventOption = [recievedDict objectForKey:@"event_option"];
            NSArray *new_feeds = [receivedEventOption objectForKey:@"new_feeds"];
            if ([new_feeds count] > 0){
                NSDictionary *new_feed_dict = [new_feeds objectAtIndex:0];
                feed_channel_id = [new_feed_dict objectForKey:@"feed_channel_id"];
                if (![feed_channel_ids containsObject:feed_channel_id]) {
                    [feed_channel_ids addObject:feed_channel_id];
                    NSLog(@"get feed_channel_id : %@", [feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]);
                    [self subscribeStartOperation:[feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]];
                    
                    [feed_channel_ids removeObjectAtIndex:0];
                    NSLog(@"current feed ids after remove: %@", feed_channel_ids);
                }
            } else {
                
                if ([clients count] > 0) {
                    NSLog(@"init remote create from res_create_ms_channel");
                    //                    RTCPeerConnection *newConnection;
                    //                    [self initRTCPeerConnection: newConnection];
                    
                    RTCAppClient *client = [[RTCAppClient alloc] initWithDelegate:self];
                    [client connectWithId:handleId settings:settings count:[clients count] cameraCreated:self.localCameraSourceCreated setVideoResolution:videoResoultion setMaxBitrate:maxBitrate userid:feed_channel_id];
                    [clients addObject:client];
                }
            }
        } else if ([type isEqualToString:(@"leave")]){
            for (int i=0; i<[clients count]; i++){
                if([[clients objectAtIndex:i].userId isEqualToString:ms_channel_id]){
                    [_delegate controller:self onEventPeer:@"leave" userId:ms_channel_id stream_flag:0 videoId:i mode_flag:@"0"];
                }
            }
        } else if ([type isEqualToString:(@"resource_destroyed")]){
            [_delegate controller:self onEventPeer:@"resource_destroyed" userId:@"" stream_flag:0 videoId:0 mode_flag:@"0"];
       
            
        } else if ([type isEqualToString:(@"publisher")]){
            NSArray *feed_infos = [recievedDict objectForKey:@"feed_infos"];
            if ([feed_infos count] > 0){
                NSDictionary *new_feed_dict = [feed_infos objectAtIndex:0];
                feed_channel_id = [new_feed_dict objectForKey:@"feed_channel_id"];
                
                if (![feed_channel_ids containsObject:feed_channel_id]) {
                    [feed_channel_ids addObject:feed_channel_id];
                    NSLog(@"get type publisher feed_channel_id : %@", [feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]);
                    [self subscribeStartOperation:[feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]];
                    [feed_channel_ids removeObjectAtIndex:0];
                    NSLog(@"current feed ids after remove: %@", feed_channel_ids);
                } else {
                    
                    NSLog(@"get type publisher included feed_channel_id : %@", [feed_channel_ids objectAtIndex:[feed_channel_ids count]-1]);
                }
            }
        } else if ([type isEqualToString:(@"webrtcup")]){
            
            if (![trx_ids containsObject:trx_id]){
                [trx_ids addObject:trx_id];
            }
            
            
            int videoId = (int)[clients count];
            if (videoId > 1){
                [_delegate controller:self onEventPeer:@"new_feed" userId:feed_channel_id stream_flag:0 videoId:videoId mode_flag:@"0"];
            }
            
            
            NSDictionary *event_option = [recievedDict objectForKey:@"event_option"];
            NSString *user_id = [event_option objectForKey:@"user_id"];
            NSLog(@"user_id : %@", user_id);
            //            if ([clients count] < 2){
            if ([feed_channel_ids count] > 0){
                NSLog(@"current feed ids : %@", feed_channel_ids);
                feed_channel_id = [feed_channel_ids objectAtIndex:0];
                NSLog(@"webrtcup get feed_channel_id : %@", [feed_channel_ids objectAtIndex:0]);
                [self subscribeStartOperation:[feed_channel_ids objectAtIndex:0]];
                
                [feed_channel_ids removeObjectAtIndex:0];
                NSLog(@"current feed ids after remove: %@", feed_channel_ids);
            }
            
            //            }
        }
    }
    
    
}





//websocetHandling & signaling

- (void) whoOperation{
    NSString *stDate = self.getCurrentTimeStamp;
    //NSString *stDate = @"20181015131018568";
    
    
    //NSLog(@"got some stDate: %@",stDate);
    NSString *signature = [self getSignature:stDate];
    
    NSDictionary *initAuth = @{@"operation":operation,
                               @"handle_id":handleId,
                               @"timestamp":stDate,
                               @"signature":signature};
    
    //    NSDictionary *initAuth = @{@"operation":operation,
    //                               @"handle_id":handleId,
    //                               @"timestamp":@"test",
    //                               @"signature":@"test"};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"send json: %@",jsonString);
    NSLog(@"send json_signature: %@",signature);
    [self.socket writeString:jsonString];
    
    
}

- (void) welcomeOperation{
    //create random string
    NSString *letters = @"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity: 10];
    for (int i=0; i<10; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random_uniform([letters length])]];
    }
    //    NSDictionary *initAuth = @{@"operation":@"heartbeat",
    //                               @"trx_id":randomString};
    NSLog(@"randomString : %@", randomString);
    //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //    [defaults setValue:randomString forKey:@"trx_id"];
    //    [defaults synchronize];
    
    if (![trx_ids containsObject:randomString]){
        [trx_ids addObject:randomString];
    }
    
    //set timer
    [NSTimer scheduledTimerWithTimeInterval:170
                                     target:self
                                   selector:@selector(timeoutHandler:)
                                   userInfo:self
                                    repeats:YES];
    
    //create ms channel
    NSDictionary *initAuth = @{@"operation":@"create_ms_channel",
                               @"channel_option":@{@"type":@"publisher"},
                               @"trx_id":randomString};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"send json: %@",jsonString);
    [self.socket writeString:jsonString];
}

- (void) subscribeStartOperation: (NSString *)feed_channel_id {
    //create random string
    
    NSLog(@"subscribeStartOperation trx_id : %@", trx_id);
    
    if (![trx_ids containsObject:trx_id]){
        [trx_ids addObject:trx_id];
    }
    for (int i=0; i<[trx_ids count]; i++){
        NSString * trx_id = trx_ids[i];
        
        NSDictionary *initAuth = @{@"operation":@"heartbeat",
                                   @"trx_id":trx_id};
        
        NSError * err;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"send json: %@",jsonString);
        [self.socket writeString:jsonString];
        
        NSLog(@"heartbeat timeer called");
    }
    
    //set timer
    [NSTimer scheduledTimerWithTimeInterval:170
                                     target:self
                                   selector:@selector(timeoutHandler:)
                                   userInfo:self
                                    repeats:YES];
    
    //create ms channel
    if (feed_channel_id != nil){
        NSLog(@"feed_channel_id : %@", feed_channel_id);
        NSDictionary *initAuth = @{
                                   @"operation":@"create_ms_channel",
                                   @"channel_option":
                                       @{
                                           @"type":@"subscriber",
                                           @"feed_channel_id":feed_channel_id
                                           },
                                   @"trx_id":trx_id};
        NSError * err;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"send json: %@",jsonString);
        [self.socket writeString:jsonString];
    }
    
}


- (void) sendOfferSdp:(RTCSessionDescription *)sdp{
    NSLog(@"offer sdp : %@", sdp.description);
    //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //    NSString *trx_id = [defaults objectForKey:@"trx_id"];
    trx_id = trx_ids[0];
    NSDictionary *initAuth = @{@"operation":@"send_sdp",
                               @"ms_channel_id":ms_channel_id,
                               @"sdp":@{
                                       @"type":@"offer",
                                       @"sdp":sdp.sdp
                                       },
                               @"trx_id":trx_id};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"sendOfferSdp json: %@",jsonString);
    [self.socket writeString:jsonString];
}

- (void) sendIce:(RTCIceCandidate *)ice{
    NSLog(@"sendIce : %@", ice);
    //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    //    if ([clients count] > 1){
    //        trx_id = [defaults objectForKey:@"trx_id_2"];
    //    } else {
    //    trx_id = [defaults objectForKey:@"trx_id"];
    //    }
    //    if (trx_id == nil){
    //        trx_id = @"sdfsdfsdfsdfsfsfsf";
    //    }
    
    NSDictionary *initAuth = @{@"operation":@"send_ice",
                               @"ms_channel_id":ms_channel_id,
                               @"candidate":@{
                                       @"candidate":ice.sdp,
                                       @"sdpMid":ice.sdpMid,
                                       @"sdpMLineIndex": @(ice.sdpMLineIndex)
                                       },
                               @"trx_id":trx_id};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"sendIce json: %@",jsonString);
    [self.socket writeString:jsonString];
}


- (void) createResource{
    NSDictionary *initAuth = @{@"operation":@"create_resource",
                               @"trx_id":@"bababbasfsdf"};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"send json: %@",jsonString);
    [self.socket writeString:jsonString];
}

- (void) setMsChannel:(NSString *)stream_flag{

    NSDictionary *initAuth = @{@"operation":@"set_ms_channel",
                               @"ms_channel_id":ms_channel_id,
                               @"channel_option":@{
                                       @"stream_flag":stream_flag
                                       },
                               @"trx_id":trx_id};
    NSError * err;
    NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    NSLog(@"setMsChannel json: %@",jsonString);
    [self.socket writeString:jsonString];
}






- (void)appClient:(RTCAppClient *)client updateCameraCreated:(BOOL *)cameraCreated{
    self.localCameraSourceCreated = cameraCreated;
}

-(void)appClient:(RTCAppClient *)client didCreateSessionDescription:(RTCSessionDescription *)sdp error:(NSError *)error{
    NSLog(@"didCreateSessionDescription");
}
-(void)appClient:(RTCAppClient *)client didSetSessionDescriptionWithError:(NSError *)error type:(NSString *)type{
    NSLog(@"set session description");
    if ([type isEqualToString:@"answer"]){
        NSLog(@"set answer session description");
        //send ice
        //            [self sendIce:generatedIceCandidate];
        RTCAppClient *client = [clients objectAtIndex:[clients count]-1];
        
        [client addIceCandiDate:recievedAudioIceCandidate];
        [client addIceCandiDate:recievedVideoIceCandidate];
        
        if([client.generatedVideoIceCandidate isKindOfClass:[NSNull class]] || client.generatedVideoIceCandidate == nil){
            
        } else {
//            [self sendIce:client.generatedVideoIceCandidate];
        }
        
        if([client.generatedAudioIceCandidate isKindOfClass:[NSNull class]] || client.generatedAudioIceCandidate == nil){
            
        } else {
//            [self sendIce:client.generatedAudioIceCandidate];
        }
        
        
    } else {
        NSLog(@"set offer session description");
        RTCPeerConnection *currentPeerConnection = client.peerConnection;
        [self sendOfferSdp: currentPeerConnection.localDescription];
    }
    
}

- (void)appClient:(RTCAppClient *)client didChangeConnectionState:(RTCIceConnectionState)state {
    
}

- (void)appClient:(RTCAppClient *)client didChangeState:(RTCAppClientState)state {
    switch (state) {
        case kRTCAppClientStateConnected:
            NSLog(@"kRTCAppClientStateConnected");
            break;
            
        default:
            break;
    }
    
    
}

//- (void)appClient:(RTCAppClient *)client didCreateLocalCapturer:(RTCCameraVideoCapturer *)localCapturer source:(RTCVideoSource *)source {
//        NSLog(@"didCreateLocalCapturer");
//
//    [_delegate controller:self didCreateLocalCapturer:localCapturer source:source];
//}

- (void)appClient:(RTCAppClient *)client createLocalCapturerSource:(RTCVideoSource *)source {
    [_delegate controller:self createLocalCapturerSource:source];
}



-(void)capturer:(RTCVideoCapturer *)capturer didCaptureVideoFrame:(nonnull RTCVideoFrame *)frame{
    NSLog(@"didCaptureVideoFrame in api called");
    //local view
    // -> unity에서 가져올때는 pixel buffer 에서 frame 만들었다고 가정
    //    NSLog(@"didCaptureVideoFrame local view ");
//    AVCaptureDevicePosition position = AVCaptureDevicePositionFront;
//    RTCCVPixelBuffer *buffer = (RTCCVPixelBuffer*)frame.buffer;
//    CVPixelBufferRef *pixelBuffer = buffer.pixelBuffer;
//    //
//    RTCCVPixelBuffer *buffer2 = [[RTCCVPixelBuffer alloc] initWithPixelBuffer:pixelBuffer adaptedWidth:frame.width adaptedHeight:frame.height cropWidth:320 cropHeight:480 cropX:frame.width/2 cropY:frame.height/2];
//
//    RTCVideoFrame *newFrame = [[RTCVideoFrame alloc]initWithBuffer:buffer2 rotation:0 timeStampNs:frame.timeStampNs];
    
    
//    [localVideoSource capturer:capturer didCaptureVideoFrame:frame];
}




- (void)appClient:(RTCAppClient *)client didError:(NSError *)error {
    
}

- (void)appClient:(RTCAppClient *)client didGetStats:(NSArray *)stats {
    //    NSLog(@"didGetStats %@", stats.description);
    //    _videoCallView.statsView.stats = stats;
    //    [_videoCallView setNeedsLayout];
    
}
//
//- (void)appClient:(RTCAppClient *)client didReceiveLocalVideoTrack:(RTCVideoTrack *)localVideoTrack {
//    //    localVideoTrack.delegate = self;
//        localVideoTrack2 = localVideoTrack;
//        NSLog(@"didReceiveLocalVideoTrack %@", localVideoTrack.debugDescription);
//}

- (void)appClient:(RTCAppClient *)client didReceiveLocalAudioTrack:(RTCAudioTrack *)localATrack{
    
    localAudioTrack = localATrack;
}

- (void)appClient:(RTCAppClient *)client didReceiveRemoteAudioTrack:(RTCAudioTrack *)remoteAudioTrack{
    NSLog(@"didReceiveRemoteAudioTrack %@", remoteAudioTrack.debugDescription);
    remoteAudioTrack1 = remoteAudioTrack;
//    [remoteAudioTrack setIsEnabled:false];
}


- (void)appClient:(RTCAppClient *)client didReceiveRemoteVideoTrack:(RTCVideoTrack *)remoteVideoTrack userId:(NSString *)userId{
    NSLog(@"didReceiveRemoteVideoTrack %@", remoteVideoTrack.debugDescription);
    NSLog(@"clients count %lu, userId : %@", [clients count], userId);
    remoteVideoTrack.delegate = self;
    
    int clientsIndex = (int)[clients count] - 1;
    
    switch ([clients count]) {
        case 1:
            
            NSLog(@"switch called %lu", [clients count]);
            if (remoteVideoTrack1 == remoteVideoTrack) {
                return;
            }
            [remoteVideoTrack1 removeRenderer:remoteView1];
            remoteVideoTrack1 = nil;
            [remoteView1 renderFrame:nil];
            remoteVideoTrack1 = remoteVideoTrack;
            
            // 렌더링만 하고 view에 담지는 않습니다. -. didGetFrame에서 frame 받아온 후 받음
            [remoteVideoTrack1 addRenderer:remoteView1];
            break;
            
        case 2:
            if (remoteVideoTrack2 == remoteVideoTrack) {
                return;
            }
            NSLog(@"switch called %lu", [clients count]);
            [remoteVideoTrack2 removeRenderer:remoteView2];
            remoteVideoTrack2 = nil;
            [remoteView2 renderFrame:nil];
            remoteVideoTrack2 = remoteVideoTrack;
            [remoteVideoTrack2 addRenderer:remoteView2];
            break;
            
        case 3:
            if (remoteVideoTrack3 == remoteVideoTrack) {
                return;
            }
            NSLog(@"switch called %lu", [clients count]);
            [remoteVideoTrack3 removeRenderer:remoteView3];
            remoteVideoTrack3 = nil;
            [remoteView3 renderFrame:nil];
            remoteVideoTrack3 = remoteVideoTrack;
            [remoteVideoTrack3 addRenderer:remoteView3];
            break;
            
        case 4:
            if (remoteVideoTrack4 == remoteVideoTrack) {
                return;
            }
            NSLog(@"switch called %lu", [clients count]);
            [remoteVideoTrack4 removeRenderer:remoteView4];
            remoteVideoTrack4 = nil;
            [remoteView4 renderFrame:nil];
            remoteVideoTrack4 = remoteVideoTrack;
            [remoteVideoTrack4 addRenderer:remoteView4];
            break;
            
            
        case 5:
            if (remoteVideoTrack5 == remoteVideoTrack) {
                return;
            }
            NSLog(@"switch called %lu", [clients count]);
            [remoteVideoTrack5 removeRenderer:remoteView5];
            remoteVideoTrack5 = nil;
            [remoteView5 renderFrame:nil];
            remoteVideoTrack5 = remoteVideoTrack;
            [remoteVideoTrack5 addRenderer:remoteView5];
            break;
            
        default:
            break;
            
    }
    
}


- (void)rtcVideoTrack:(RTCVideoTrack *)track didGetFrame:(RTCVideoFrame *)frame {
    
    
//    NSString *trackId = track.trackId;
//    NSLog(@"didGetFrame trackId : %@", trackId);
    if ([frame.buffer isKindOfClass:[RTCCVPixelBuffer class]]) {
        RTCCVPixelBuffer *buffer = (RTCCVPixelBuffer*)frame.buffer;
        CVPixelBufferRef pixelBuffer = buffer.pixelBuffer;
        for (int i=0; i<[clients count]; i++){
            if ([track.trackId isEqualToString:[clients objectAtIndex:i].remoteVideoTrack.trackId]) {
                [_delegate controller:self getRemotePixelBuffer:pixelBuffer trackId:track.trackId userId:[clients objectAtIndex:i].userId];
//                NSLog(@"didGetFrame userId : %@", [clients objectAtIndex:i].userId);
            }
            
        }
        
//        아래 코드 적용해보기
    }
    
}


- (void) peerConnectionDisConnect {
    [[clients objectAtIndex:0] disconnect];
    [[clients objectAtIndex:[clients count]-1] disconnect];
    
}

- (void)requestLeave:(NSString *)handle_id user_id:(NSString *)user_id {
    NSLog(@"requestLeave client count : %lu", [clients count]);
    if ([clients count] > 0){
//        int lastIndex =(int)[clients count] - 1;
        [[clients objectAtIndex:0] disconnect];
        
    }
    [self.socket disconnect];

//    for (int i=0; i<[clients count]; i++){
//        [[clients objectAtIndex:i] disconnect];
//        [clients removeObjectAtIndex:i];
//    }
}

- (void)appClient:(RTCAppClient *)client clientClosed:(NSString *)userId{
//    int lastIndex =(int)[clients count] - 1;
    if ([clients count] > 0){
        [clients removeObjectAtIndex:0];
        NSLog(@"requestLeave client count after remove : %lu", [clients count]);
    }
    
//    [self requestLeave:@"" user_id:@""];
}







- (NSData *)dataFromHexString:(NSString *)sHex {
    const char *chars = [sHex UTF8String];
    int i = 0;
    NSUInteger len = sHex.length;
    
    NSMutableData *data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}

- (NSData *)hmacForHexKey:(NSString *)hexkey andStringData:(NSString *)data
{
    NSData *keyData = [self dataFromHexString:hexkey];
    const char *cKey  = [keyData bytes];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, keyData.length, cData, strlen(cData), cHMAC);
    
    return [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
    
}
- (NSData *)hmacForKey:(NSString *)key andStringData:(NSString *)data
{
    const char *cKey  = [key cStringUsingEncoding:NSUTF8StringEncoding];
    const char *cData = [data cStringUsingEncoding:NSUTF8StringEncoding];
    
    unsigned char cHMAC[CC_SHA256_DIGEST_LENGTH];
    
    CCHmac(kCCHmacAlgSHA256, cKey, strlen(cKey), cData, strlen(cData), cHMAC);
    
    return [[NSData alloc] initWithBytes:cHMAC length:sizeof(cHMAC)];
}


- (NSString *) getCurrentTimeStamp
{
    //NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
    
    
    //    NSTimeZone *timeZone = [NSTimeZone timeZoneWithName:@"KST"];
    //    [objDateformat setTimeZone:timeZone];
    //    [objDateformat setTimeStyle:NSDateFormatterShortStyle];
    //    [objDateformat setDateFormat:@"YYYYMMddhhmmssSSSS"];
    //    [objDateformat setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"ko_KR"]];
    //    //    [objDateformat setLocale:NSLocale(NSLocaleIdentifier:@"ko_kr")];
    //    NSString *strTime = [objDateformat stringFromDate:[NSDate date]];
    //
    //
    //
    
    NSDate *today = [NSDate date];
    
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"YYYYMMddhhmmssSS"];
    [dateFormat setLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"ko_KR"]];
    
    //    2018101513104989
    //    20181015010513524
    //    2018101513101418
    //    20180426150414991
    //2018101501080886
    NSString *strTime = [dateFormat stringFromDate:today];
    
    NSLog(@"The Timestamp is = %@",strTime);
    
    return strTime;
    //return @"20180426150414991";
}

- (NSString *)getSignature:(NSString *)timeStamp {
    
    
    
    
    
    //NSString *stDate = @"20180426150414991";
    //2018101513102283
    NSString *stDate = timeStamp;
    
    
    
    
    NSString * parameters = [NSString stringWithFormat:@"%@:%@",handleId,stDate];
    
    
    //    20180426150414991';
    //    const server_id='TEST_SERVER_ID';
    //    const server_secret='TEST_SERVER_SECRET';
    
    
    
    NSData *hmac1 = [self hmacForKey:serverSecret andStringData:parameters];
    const unsigned char *buffer = (const unsigned char *)[hmac1 bytes];
    NSMutableString *HMAC = [NSMutableString stringWithCapacity:hmac1.length * 2];
    for (int i = 0; i < hmac1.length; ++i){
        [HMAC appendFormat:@"%02x", buffer[i]];
    }
    NSLog(@"HMAC   : %@, timeStamp : %@", HMAC, timeStamp);
    //    NSString *base64Hash1 =  [hmac1 base64EncodedStringWithOptions:0];
    //    NSLog(@"hmacForKey   : %@", base64Hash1);
    
    //    NSData *hmac2 = [self hmacForHexKey:serverScret andStringData:parameters];
    //    NSString *base64Hash2 = [hmac2 base64EncodedStringWithOptions:0];
    //    NSLog(@"hmacForHexKey: %@", base64Hash2);
    //
    //
    //    NSLog(@"parameter : %@",parameters);
    //
    //    NSData *saltData = [serverScret dataUsingEncoding:NSUTF8StringEncoding];
    //    NSData *paramData = [parameters dataUsingEncoding:NSUTF8StringEncoding];
    //    NSMutableData* hash = [NSMutableData dataWithLength:CC_SHA256_DIGEST_LENGTH ];
    //    CCHmac(kCCHmacAlgSHA256, saltData.bytes, saltData.length, paramData.bytes, paramData.length, hash.mutableBytes);
    //
    //    NSString *base64Hash = [hmac2 base64Encoding];
    //
    return HMAC;
    
}

-(void)websocket:(JFRWebSocket*)socket didReceiveData:(NSData*)data {
    NSLog(@"got some binary data: %d",data.length);
    
    
}


-(void)timeoutHandler:(NSTimer*) timer
{
    
    //    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    //    NSString * trx_id = [defaults objectForKey: @"trx_id"];
    
    for (int i=0; i<[trx_ids count]; i++){
        NSString * trx_id = trx_ids[i];
        
        NSDictionary *initAuth = @{@"operation":@"heartbeat",
                                   @"trx_id":trx_id};
        
        NSError * err;
        NSData * jsonData = [NSJSONSerialization dataWithJSONObject:initAuth options:0 error:&err];
        NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSLog(@"send json: %@",jsonString);
        [self.socket writeString:jsonString];
        
        NSLog(@"heartbeat timeer called");
    }
    
}




- (void)audioSession:(RTCAudioSession *)audioSession didDetectPlayoutGlitch:(int64_t)totalNumberOfGlitches {
//    RTCLog(@"Audio session detected glitch, total: %lld", totalNumberOfGlitches);
}

-(void)requestVideoOnOff:(NSString *)user_id
                  enable:(BOOL)enable
             stream_flag:(int)stream_flag{
    
    for (int i=0; i<[clients count]; i++){
        if ([[clients objectAtIndex:i].userId isEqualToString:user_id]) {
            NSLog(@"requestVideoOnOff : %d", enable);
            [[clients objectAtIndex:i].remoteVideoTrack setIsEnabled:enable];
            
        }
    }
    
}

- (void)configureAudioSession {
    configuration =
    [[RTCAudioSessionConfiguration alloc] init];
    configuration.category = AVAudioSessionCategoryAmbient;
    configuration.categoryOptions = AVAudioSessionCategoryOptionDuckOthers;
    configuration.mode = AVAudioSessionModeDefault;
    
    
//    RTCAudioSession *session = [RTCAudioSession sharedInstance];
    [audioSession lockForConfiguration];
    BOOL hasSucceeded = NO;
    NSError *error = nil;
    if (audioSession.isActive) {
        hasSucceeded = [audioSession setConfiguration:configuration error:&error];
    } else {
        hasSucceeded = [audioSession setConfiguration:configuration
                                          active:YES
                                           error:&error];
    }
    if (!hasSucceeded) {
        NSLog(@"Error setting configuration: %@", error.localizedDescription);
    }
    [audioSession unlockForConfiguration];
}


-(void)requestVoiceOnOff:(NSString *)user_id
                  enable:(BOOL)enable
             stream_flag:(int)stream_flag{
    
    NSLog(@"requestVoiceOnOff : %d, user_id : %@", enable, user_id);
    if ([user_id isEqualToString:@""]){
        NSLog(@"localVoiceOff");
        NSString* stStreamFalg = [NSString stringWithFormat:@"%d",stream_flag];
        [self setMsChannel:stStreamFalg];
        NSLog(@"requestVoiceOnOff : %d", enable);
        NSError *error;
        
        [[clients objectAtIndex:0] localVoiceOnoff:enable];
        
//        [audioSession setActive:NO  error:&error];
//        [audioSession setConfiguration:configuration active:NO error:&error];
//        [audioSession setIsAudioEnabled:false];
//        [[AVAudioSession sharedInstance] setInputGain:0.0f error:&error];
//        [audioSession lockForConfiguration];
//        if([audioSession setActive:false error:&error]){
//            NSLog(@"NSLog setActive false succeed");
//            [localAudioTrack setIsEnabled:false];
//        } else {
//            NSLog(@"NSLog setActive false failed");
//        }
//        [audioSession unlockForConfiguration];
//        [audioSession setInputGain:0.0f error:&error];
        
//        for (int i=0; i<[clients count]; i++){
//            if ([[clients objectAtIndex:i].userId isEqualToString:user_id]) {
//                NSLog(@"requestVoiceOnOff : %d", enable);
////                [[clients objectAtIndex:i].localAudioTrack setIsEnabled:enable];
////                [[clients objectAtIndex:i].localAudioTrack i];
//            }
//        }
        
    } else {
        for (int i=0; i<[clients count]; i++){
            if ([[clients objectAtIndex:i].userId isEqualToString:user_id]) {
                NSLog(@"requestVoiceOnOff : %d", enable);
                [[clients objectAtIndex:i].remoteAudioTrack setIsEnabled:enable];
                
            } else {
                //local audio
//                if (localAudioOnoff == 1){
//                    localAudioOnoff = 0;
//                    [localAudioTrack setIsEnabled:false];
//                    NSLog(@"localAudioTrack audio off");
//                } else {
//                    localAudioOnoff = 1;
//                    [localAudioTrack setIsEnabled:true];
//                    NSLog(@"localAudioTrack audio on");
//                }
            }
        }
        
        
    }
    
}




@end
