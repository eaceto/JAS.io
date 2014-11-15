//
//  JASio.m
//  JAS.io
//
//  Created by Ezequiel Aceto on 11/13/14.
//  https://github.com/eaceto/JAS.io
//

#import "JASio.h"

#import <JavaScriptCore/JavaScriptCore.h>

#define kNSURLRequestDefaultTimeout 120.0

@interface JASio ()

@property (nonatomic, strong) UIWebView *javascriptWebView;
@property (nonatomic, strong) JSContext *javascriptContext;

@property (nonatomic, strong) NSString* hostURL;
@property (nonatomic, strong) NSString* remoteScriptURL;

@property (nonatomic) BOOL isConnecting, isReadyToConnect, isConnected, shouldReconnect;
@property (nonatomic) int reconnectionDelay, reconnectionDelayMax, timeout;

@property (nonatomic, copy) void(^readyToConnectBlock)();
@property (nonatomic, copy) void(^errorBlock)(NSDictionary* error);
@end

@implementation JASio
@synthesize logEnabled;

#pragma mark Object creation
- (id)init {
    self = [super init];
    if (self) {
        _isConnecting = NO;
        _isReadyToConnect = NO;
        _isConnected = NO;
        logEnabled = NO;
        _reconnectionDelay = 1000;
        _reconnectionDelayMax = 5000;
        _timeout = 20000;
        _shouldReconnect = NO;
    }
    return self;
}

#pragma mark -
#pragma mark log helper

- (void)log:(NSString*)tag withParams:(NSDictionary*)params {
    if (logEnabled)
        NSLog(@"<JAS.io> %@ %@%@",tag,params != nil ? @"withParams: ": @"", params != nil ? params : @"");
}
- (void)logEvent:(NSString*)eventName withParams:(NSDictionary*)params {
    [self log:[NSString stringWithFormat:@"onEvent: %@",eventName] withParams:params];
}

+ (void)logWarning:(NSString*)warning {
    NSLog(@"<JAS.io> WARN %@",warning);
}

+ (void)logError:(NSString*)warning {
    NSLog(@"<JAS.io> ERROR %@",warning);
}

#pragma mark -
#pragma mark Load Remote Script

- (void)loadRemoteScriptURL:(NSString*)remoteScriptURL
             readyToConnect:(void(^)())readyBlock
                onLoadError:(void(^)(NSDictionary* error))errorBlock {
    
    _readyToConnectBlock = readyBlock;
    _errorBlock = errorBlock;
    _remoteScriptURL = remoteScriptURL;
    _javascriptWebView = [[UIWebView alloc] init];
    
    [_javascriptWebView setDelegate:(id<UIWebViewDelegate>)self];
    
    _javascriptContext = [self getJavascriptContext];
    [_javascriptContext setExceptionHandler: ^(JSContext *context, JSValue *errorValue) {
        [JASio logError:[NSString stringWithFormat:@"JSError: %@", errorValue]];
        [JASio logError:[NSString stringWithFormat:@"%@", [NSThread callStackSymbols]]];
    }];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:_remoteScriptURL]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                         timeoutInterval:kNSURLRequestDefaultTimeout];

    [_javascriptWebView loadRequest:request];
}

#pragma mark -
#pragma mark Connect and disconnect

/// Connects to host with params
-(BOOL)connectWithHost:(NSString *)host
                  port:(NSInteger)port
                secure:(BOOL)secure
             reconnect:(BOOL)reconnect
     reconnectionDelay:(int)reconnectionDelay
  reconnectionDelayMax:(int)reconnectionDelayMax
               timeout:(int)timeout {

    _reconnectionDelay = reconnectionDelay;
    _reconnectionDelayMax = reconnectionDelayMax;
    _timeout = timeout;
    _shouldReconnect = reconnect;
    
    return [self connectWithHost:host port:port secure:secure];
}

- (BOOL)connectWithHost:(NSString *)host
                   port:(NSInteger)port
                 secure:(BOOL)secure {
    if (_isConnected == YES) return NO;
    
    _isConnecting = YES;
    
    _hostURL = [NSString stringWithFormat:@"%@%@:%li",([host rangeOfString:@"http"].location == NSNotFound ? (secure ? @"https://":@"http://") : @""),
                host,
                (long)port];
    
    [self log:@"connectWithHost" withParams:@{@"url":_hostURL, @"secure":secure ? @"YES":@"NO"}];
    
    _javascriptContext = [self getJavascriptContext];
    
    [_javascriptContext evaluateScript:@"clear();"];
    
    _reconnectionDelayMax = MAX(_reconnectionDelayMax, _reconnectionDelay);
    _timeout = _timeout < 0 ? 20000 : _timeout;
    
    [_javascriptContext evaluateScript:[NSString stringWithFormat:@"reconnectionDelay=%li;",(long)_reconnectionDelay]];
    
    [_javascriptContext evaluateScript:[NSString stringWithFormat:@"reconnectionDelayMax=%li;",(long)_reconnectionDelayMax]];
    
    [_javascriptContext evaluateScript:[NSString stringWithFormat:@"timeout=%li;",(long)_timeout]];
    
    [_javascriptContext evaluateScript:[NSString stringWithFormat:@"reconnection=%@;",_shouldReconnect ? @"true" : @"false"]];
    
    JSValue* ret = [_javascriptContext evaluateScript:[NSString stringWithFormat:@"connect(\"%@\");",_hostURL]];
    if (ret) {
        return [ret toBool];
    }
    return NO;
}

- (void)disconnect {
    _isConnected = NO;
    _isConnecting = NO;
    _isReadyToConnect = NO;
}

-(BOOL)reconnect {
    _javascriptContext = [self getJavascriptContext];
    
    JSValue* ret = [_javascriptContext evaluateScript:[NSString stringWithFormat:@"connect(\"%@\");",_hostURL]];
    if (ret) {
        return [ret toBool];
    }
    return NO;
}

#pragma mark -

// Accessors
- (JSContext *)getJavascriptContext {
    return [_javascriptWebView valueForKeyPath: @"documentView.webView.mainFrame.javaScriptContext"];
}

#pragma Send and Receive

- (BOOL)on:(NSString *)event callback:(void (^)(NSArray *args))function {
    _javascriptContext = [self getJavascriptContext];
    
    NSString* receiver = [NSString stringWithFormat: @"receiver_%@", event];
    _javascriptContext[receiver] = ^() {
        NSMutableArray *arguments = [NSMutableArray array];
        for (JSValue *object in [JSContext currentArguments]) {
            if ([object toObject]) {
                [arguments addObject: [object toObject]];
            }
        }
            
        function(arguments);
    };
    
    _javascriptContext = [self getJavascriptContext];
    
    JSValue* ret = [_javascriptContext evaluateScript:[NSString stringWithFormat:@"registerReceiver('%@',%@);",event,receiver]];
    if (ret) {
        return [ret toBool];
    }
    
    return NO;
}

- (BOOL)emit:(NSString *)event json:(NSDictionary *)json {
    if (self.isConnected) {
        _javascriptContext = [self getJavascriptContext];
        
        JSValue* emitMessage = _javascriptContext[@"emitEventData"];
        NSArray* args = @[event,json];
        JSValue* ret = [emitMessage callWithArguments:args];
        
        if (ret) return [ret toBool];
    }
    return NO;
}

#pragma mark -
#pragma mark <INTERNAL> WebView Delegate
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    return YES;
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    [self logEvent:@"webViewDidStartLoad" withParams:nil];
}
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if (_isReadyToConnect == NO) {
        _isReadyToConnect = YES;
        [self logEvent:@"webViewDidFinishLoad" withParams:nil];
        
        _javascriptContext = [self getJavascriptContext];
        
        // Event handler
        __weak typeof(self) weakSocket = self;
        _javascriptContext[@"onSocketConnected"] = ^() {
            weakSocket.isConnected = YES;
            weakSocket.isConnecting = NO;
            [weakSocket logEvent:@"onSocketConnected" withParams:nil];
            if (weakSocket.onConnect)
                weakSocket.onConnect();
        };
        
        _javascriptContext[@"onSocketDisconnected"] = ^() {
            [weakSocket disconnect];
            [weakSocket logEvent:@"onSocketDisconnected" withParams:nil];
            if (weakSocket.onDisconnect)
                weakSocket.onDisconnect();
        };
        
        _javascriptContext[@"onSocketError"] = ^(NSString* tag, NSDictionary* error) {
            [weakSocket logEvent:@"onSocketError" withParams:nil];
            if (weakSocket.onError) {
                weakSocket.onError(tag, error);
            }
        };
        
        _javascriptContext[@"onSocketTimeout"] = ^(NSString* tag, NSDictionary* error) {
            [weakSocket logEvent:@"onSocketTimeout" withParams:nil];
            if (weakSocket.onTimeout) {
                weakSocket.onTimeout();
            }
        };
        
        _javascriptContext[@"onSocketConnectError"] = ^(NSDictionary* error) {
            [weakSocket logEvent:@"onSocketConnectError" withParams:nil];
            if (weakSocket.onConnectError) {
                weakSocket.onConnectError(error);
            }
        };
        
        _javascriptContext[@"onDataSent"] = ^(NSString* event, NSArray* args) {
            [weakSocket logEvent:@"onDataSent" withParams:@{@"event":event,@"args":args}];
            if (weakSocket.onEmitCallback) {
                weakSocket.onEmitCallback(event, args);
            }
        };
        
        JSValue *onSocketConnected = _javascriptContext[@"onSocketConnected"];
        JSValue *onSocketDisconnected = _javascriptContext[@"onSocketDisconnected"];
        JSValue *onSocketError = _javascriptContext[@"onSocketError"];
        JSValue *onSocketTimeout = _javascriptContext[@"onSocketTimeout"];
        JSValue *onSocketConnectError = _javascriptContext[@"onSocketConnectError"];
        JSValue *onDataSent = _javascriptContext[@"onDataSent"];
        
        if (onSocketConnected == nil) [JASio logWarning:@"onSocketConnected not attached"];
        if (onSocketDisconnected == nil) [JASio logWarning:@"onSocketDisconnected not attached"];
        if (onSocketError == nil) [JASio logWarning:@"onSocketError not attached"];
        if (onSocketTimeout == nil) [JASio logWarning:@"onSocketTimeout not attached"];
        if (onSocketConnectError == nil) [JASio logWarning:@"onSocketConnectError not attached"];
        if (onDataSent == nil) [JASio logWarning:@"onDataSent not attached"];
        
        if (_readyToConnectBlock) {
            _readyToConnectBlock(self);
        }
    }
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [self logEvent:@"webView:didFailLoadWithError" withParams:nil];
    if (_errorBlock) {
        _errorBlock(@{@"error":error != nil? [error description] : @"N/A",@"URL":[[webView request]URL]});
    }
}

#pragma mark -

@end
