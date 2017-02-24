//
//  Mqtt.m
//  RCTMqtt
//
//  Created by Tuan PM on 2/13/16.
//  Copyright © 2016 Tuan PM. All rights reserved.
//

#import "Mqtt.h"
#import <React/RCTEventEmitter.h>

@interface Mqtt ()

@property (strong, nonatomic) MQTTSessionManager *manager;
@property (nonatomic, strong) NSDictionary *defaultOptions;
@property (nonatomic, retain) NSMutableDictionary *options;
@property (nonatomic, strong) NSString *clientRef;
@property (nonatomic, strong) RCTEventEmitter * emitter;

@end

@implementation Mqtt


- (id)init {
    if ((self = [super init])) {
        self.defaultOptions = @{
                                @"host": @"localhost",
                                @"port": @1883,
                                @"protcol": @"tcp", //ws
                                @"tls": @NO,
                                @"keepalive": @120, //second
                                @"clientId" : @"react-native-mqtt",
                                @"protocolLevel": @4,
                                @"clean": @YES,
                                @"auth": @NO,
                                @"user": @"",
                                @"pass": @"",
                                @"will": @NO,
                                @"willMsg": [NSNull null],
                                @"willtopic": @"",
                                @"willQos": @0,
                                @"willRetainFlag": @NO,
                                @"selfSignedCertificates": @NO,
                                @"clientCertificate": @"",
                                @"caCertificate": @"",
                                @"clientSecret": @"",
                                };
        
    }
    
    return self;
}

- (instancetype) initWithEmitter:(RCTEventEmitter *) emitter
                         options:(NSDictionary *) options
                       clientRef:(NSString *) clientRef {
    self = [self init];
    self.emitter = emitter;
    self.clientRef = clientRef;
    self.options = [NSMutableDictionary dictionaryWithDictionary:self.defaultOptions]; // Set default options
    for (NSString *key in options.keyEnumerator) { // Replace default options
        [self.options setValue:options[key] forKey:key];
    }
    self.manager = [[MQTTSessionManager alloc] initWithPersistence:NO maxWindowSize:MQTT_MAX_WINDOW_SIZE maxMessages:MQTT_MAX_MESSAGES maxSize:MQTT_MAX_SIZE];
    self.manager.delegate = self;
    
    return self;
}

- (void) connect {
    MQTTSSLSecurityPolicy *securityPolicy = nil;
    NSArray *certificates = nil;

    if(self.options[@"tls"]) {
        securityPolicy = [MQTTSSLSecurityPolicy policyWithPinningMode:MQTTSSLPinningModeNone];
        securityPolicy.allowInvalidCertificates = YES;


        if([self.options[@"selfSignedCertificates"] boolValue]) {
            NSArray *paths =  NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
            NSString *documentsDirectory = [paths objectAtIndex:0];
            NSString *ca = [documentsDirectory stringByAppendingPathComponent:self.options[@"caCertificate"]];
            securityPolicy.pinnedCertificates = @[[NSData dataWithContentsOfFile:ca]];
            NSString *clientCertificate = [documentsDirectory stringByAppendingPathComponent:self.options[@"clientCertificate"]];
            certificates = [MQTTCFSocketTransport clientCertsFromP12:clientCertificate passphrase:self.options[@"clientSecret"]];
        }
    }
    
    NSData *willMsg = nil;
    if(self.options[@"willMsg"] != [NSNull null]) {
        willMsg = [self.options[@"willMsg"] dataUsingEncoding:NSUTF8StringEncoding];
    }

    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self.manager connectTo:[self.options valueForKey:@"host"]
                           port:[self.options[@"port"] intValue]
                            tls:[self.options[@"tls"] boolValue]
                      keepalive:[self.options[@"keepalive"] intValue]
                          clean:[self.options[@"clean"] intValue]
                           auth:[self.options[@"auth"] boolValue]
                           user:[self.options valueForKey:@"user"]
                           pass:[self.options valueForKey:@"pass"]
                           will:[self.options[@"will"] boolValue]
                      willTopic:[self.options valueForKey:@"willTopic"]
                        willMsg:willMsg
                        willQos:(MQTTQosLevel)[self.options[@"willQos"] intValue]
                 willRetainFlag:[self.options[@"willRetainFlag"] boolValue]
                   withClientId:[self.options valueForKey:@"clientId"]
                 securityPolicy:securityPolicy
                   certificates:certificates
         ];
    }];
}

- (void)sessionManager:(MQTTSessionManager *)sessonManager didChangeState:(MQTTSessionManagerState)newState {
    switch (newState) {
            
        case MQTTSessionManagerStateClosed:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"closed",
                                              @"clientRef": self.clientRef,
                                              @"message": @"closed"
                                              }];
            break;
        case MQTTSessionManagerStateClosing:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"closing",
                                              @"clientRef": self.clientRef,
                                              @"message": @"closing"
                                              }];
            break;
        case MQTTSessionManagerStateConnected:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"connect",
                                              @"clientRef": self.clientRef,
                                              @"message": @"connected"
                                              }];
            break;
        case MQTTSessionManagerStateConnecting:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"connecting",
                                              @"clientRef": self.clientRef,
                                              @"message": @"connecting"
                                              }];
            break;
        case MQTTSessionManagerStateError:
            [self.emitter sendEventWithName:@"mqtt_events"
                                       body:@{@"event": @"error",
                                              @"clientRef": self.clientRef,
                                              @"message": @"error"
                                              }];
            break;
        case MQTTSessionManagerStateStarting:
        default:
            break;
    }
}

- (void) disconnect {
    [self.manager disconnect];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1.0]];
}

- (void) subscribe:(NSString *)topic qos:(NSNumber *)qos {
    NSMutableDictionary *subscriptions = [self.manager.subscriptions mutableCopy];
    [subscriptions setObject:qos forKey: topic];
    [self.manager setSubscriptions:subscriptions];
}

- (void) unsubscribe:(NSString *)topic {
    NSMutableDictionary *subscriptions = [self.manager.subscriptions mutableCopy];
    [subscriptions removeObjectForKey: topic];
    [self.manager setSubscriptions:subscriptions];
}

- (void) publish:(NSString *) topic data:(NSData *)data qos:(NSNumber *)qos retain:(BOOL) retain {
    [self.manager sendData:data topic:topic qos:[qos intValue] retain:retain];
}

- (void)handleMessage:(NSData *)data onTopic:(NSString *)topic retained:(BOOL)retained {
    NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    [self.emitter sendEventWithName:@"mqtt_events"
                               body:@{
                                      @"event": @"message",
                                      @"clientRef": self.clientRef,
                                      @"message": @{
                                              @"topic": topic,
                                              @"data": dataString,
                                              @"retain": [NSNumber numberWithBool:retained]
                                              }
                                      }];
    
}


- (void)dealloc
{
    [self disconnect];
}

@end
