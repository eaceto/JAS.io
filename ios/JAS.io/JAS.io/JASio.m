//
//  JASio.m
//  JAS.io
//
//  Created by Kimi on 11/13/14.
//  https://github.com/eaceto/JASio
//

#import "JASio.h"


#import <JavaScriptCore/JavaScriptCore.h>

#ifdef __IPHONE_8_0
#import <WebKit/WebKit.h>
#endif

#define kNSURLRequestDefaultTimeout 120.0

@interface JASio ()

@property (nonatomic, strong) UIWebView *javascriptWebView;
@property (nonatomic, strong) JSContext *javascriptContext;

@property (nonatomic, strong) NSString* hostURL;
@property (nonatomic, strong) NSString* remoteScriptURL;

@property (nonatomic) BOOL isConnecting, isReadyToConnect, isConnected;

@property (nonatomic, copy) void(^readyToConnectBlock)();
@property (nonatomic, copy) void(^errorBlock)(NSDictionary* error);
@end

@implementation JASio
@synthesize logEnabled;

- (id)init {
    self = [super init];
    if (self) {
        _isConnecting = NO;
        _isReadyToConnect = NO;
        _isConnected = NO;
        logEnabled = YES;
        
    }
    return self;
}

- (void)log:(NSString*)tag withParams:(NSDictionary*)params {
    if (logEnabled)
        NSLog(@"<JAS.io> %@ %@%@",tag,params != nil ? @"withParams: ": @"", params != nil ? params : @"");
}
- (void)logEvent:(NSString*)eventName withParams:(NSDictionary*)params {
    [self log:[NSString stringWithFormat:@"onEvent: %@",eventName] withParams:params];
}

- (void)logWarning:(NSString*)warning {
    NSLog(@"<JAS.io> WARN %@",warning);
}


- (void)loadRemoteScriptURL:(NSString*)remoteScriptURL readyToConnect:(void(^)())readyBlock onLoadError:(void(^)(NSDictionary* error))errorBlock {
    _readyToConnectBlock = readyBlock;
    _errorBlock = errorBlock;
    _remoteScriptURL = remoteScriptURL;
    _javascriptWebView = [[UIWebView alloc] init];
    
    [_javascriptWebView setDelegate:(id<UIWebViewDelegate>)self];
    
    _javascriptContext = [self getJavascriptContext];
    [_javascriptContext setExceptionHandler: ^(JSContext *context, JSValue *errorValue) {
        NSLog(@"JSError: %@", errorValue);
        NSLog(@"%@", [NSThread callStackSymbols]);
    }];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    NSURLRequest* request = [NSURLRequest requestWithURL:[NSURL URLWithString:_remoteScriptURL]
                                             cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData
                                         timeoutInterval:kNSURLRequestDefaultTimeout];

    [_javascriptWebView loadRequest:request];
}


- (BOOL)connectWithHost:(NSString *)host port:(NSInteger)port secure:(BOOL)secure {
    if (_isConnected == YES) return NO;
    
    _isConnecting = YES;
    
    _hostURL = [NSString stringWithFormat:@"%@%@:%li",([host rangeOfString:@"http"].location == NSNotFound ? (secure ? @"https://":@"http://") : @""),
                host,
                (long)port];
    
    [self log:@"connectWithHost" withParams:@{@"url":_hostURL, @"secure":secure ? @"YES":@"NO"}];
    
    _javascriptContext = [self getJavascriptContext];

    
    [_javascriptContext evaluateScript:[NSString stringWithFormat:@"connect(\"%@\");",_hostURL]];
    
    return YES;
}

- (void)disconnect {
    [_javascriptWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:self.remoteScriptURL]]];
    [_javascriptWebView reload];
    _javascriptWebView = nil;
}

// Accessors
- (JSContext *)getJavascriptContext {
    return [_javascriptWebView valueForKeyPath: @"documentView.webView.mainFrame.javaScriptContext"];
}

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
        NSLog(@"ret %i",[ret toBool]);
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


#pragma mark WebView Delegate
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
            weakSocket.isConnected = NO;
            
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
        
        if (onSocketConnected == nil) [self logWarning:@"onSocketConnected not attached"];
        if (onSocketDisconnected == nil) [self logWarning:@"onSocketDisconnected not attached"];
        if (onSocketError == nil) [self logWarning:@"onSocketError not attached"];
        if (onSocketTimeout == nil) [self logWarning:@"onSocketTimeout not attached"];
        if (onSocketConnectError == nil) [self logWarning:@"onSocketConnectError not attached"];
        if (onDataSent == nil) [self logWarning:@"onDataSent not attached"];
        
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

@end
