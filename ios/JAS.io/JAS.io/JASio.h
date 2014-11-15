//
//  JASio.h
//  JAS.io
//
//  Created by Kimi on 11/13/14.
//  https://github.com/eaceto/JASio
//
//

#import <Foundation/Foundation.h>

@interface JASio : NSObject
{
    BOOL logEnabled;
}

@property (nonatomic, assign) BOOL logEnabled;

// Constructor
/// Loads the remote script that hosts the socket.io client
/// readyBlock called as soon as the script is loaded. So JASio is ready to connect to the socket server.
- (void)loadRemoteScriptURL:(NSString*)remoteScriptURL readyToConnect:(void(^)())readyBlock onLoadError:(void(^)(NSDictionary* error))errorBlock;

// Connect and Disconnect
/// Connects to host with params
-(BOOL)connectWithHost:(NSString *)host port:(NSInteger)port secure:(BOOL)secure ;

/// Disconnects from host
-(void)disconnect;

/*** Send and receive messages ***/

// Sends a JSON using a custom event
- (BOOL)emit:(NSString *)event json:(NSDictionary *)json;

// Receive messages
/// register a callback function for a custom message.
- (BOOL)on:(NSString *)event callback:(void (^)(NSArray *args))function;

/*** Socket.io generic events handlers ***/

// handles socket.io connect event
/// Called when the connection is established
@property (nonatomic, copy) void (^onConnect)();

// handles socket.io disconnect event
/// Called when the client is disconnected
@property (nonatomic, copy) void (^onDisconnect)();

// handles socket.io connect_error event
/// Called when there is an error trying to connect
@property (nonatomic, copy) void (^onConnectError)(NSDictionary *errorInfo);

// handles socket.io onError event
/// Called when an error ocurrs
@property (nonatomic, copy) void (^onError)(NSString* tag, NSDictionary *errorInfo);

// handles socket.io timeout event
/// Called when there is a timeout error
@property (nonatomic, copy) void (^onTimeout)();

// handles socket.io emit callback
/// Called when the client performs a successful emil
@property (nonatomic, copy) void (^onEmitCallback)(NSString* event, NSArray* args);

@end
