//
//  MainViewController.m
//  JAS.io
//
//  Created by Ezequiel Aceto on 11/13/14.
//
//

#import "MainViewController.h"
#import "JASio.h"

@interface MainViewController ()
@property (nonatomic, strong) JASio* jasio;
@end

#define kRemoteScriptURL        @"http://your-remote-host-that.has/jasio-wrapper.html"
#define kSocketIOServerURL      @"your-socket-io-server.com"
#define kSocketIOServerPort     3300

@implementation MainViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.jasio = [[JASio alloc] init];

    // enable or disable JAS.io log
    [self.jasio setLogEnabled:YES];
    
    // load the remote script
    [self.jasio loadRemoteScriptURL:kRemoteScriptURL readyToConnect:^() {
        
        if (self.jasio) {
            
            __weak JASio* weakJasio = self.jasio;
            
            // a block for handling connections.
            // start sending messages when the client is connected
            self.jasio.onConnect = ^() {
                NSLog(@"Client connected");
                
                // register for listening to events
                BOOL eventRegistered = [weakJasio on:@"message" callback:^(NSArray* args) {
                    NSLog(@"Client received message with args: %@",args);
                }];
                // check if remote host could register the event
                if (!eventRegistered) NSLog(@"Not listening to events");

                // send a hello message
                BOOL sent = [weakJasio emit:@"message" json:@{@"text":@"Hello JAS.io!"}];
                if (!sent) NSLog(@"Message not sent");
            };
            
            // a block for handling disconnections
            self.jasio.onDisconnect = ^() {
                NSLog(@"Client disconnected");
                
                /// here you can fire a reconnection if needed
                /// if ([weakJasio reconnect]) NSLog(@"reconnected");
            };
            
            // a block for handling errors
            self.jasio.onError = ^(NSString* tag, NSDictionary* error) {
                NSLog(@"Client onError %@ - %@",tag,error);
            };
            
            // a block for handling connection errors
            self.jasio.onConnectError = ^(NSDictionary* error) {
                NSLog(@"Connection failed with error: %@",error);
            };
            
            // a block for handling timeout
            self.jasio.onTimeout = ^() {
                NSLog(@"Connection failed with timeout");
            };
            
            // connect to a Socket.io server
            [self.jasio connectWithHost:kSocketIOServerURL port:kSocketIOServerPort secure:NO];
        }
    } onLoadError:^(NSDictionary* error) {
        NSLog(@"Client did receive an error when loading remote script: %@",error);
    }];
}

@end
