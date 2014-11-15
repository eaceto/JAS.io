JAS.io
======
(just another) Socket.io client - based on Socket.io v1.x client for iOS.

Why it is not just another Socket.io client?
--------------------------------------------

JAS.io does not include the Socket.io client file inside your iOS project. It relies on the client being hosted where you have the Socket.io server providing the following beneficts.

1) You can use SSL without problems. Your iOS client loads a wrapper using HTTPS, that wrapper uses SSL to communicate with the server. Other approches fail to achieve this because they include the client script inside the app.

2) You can upgrade your Socket.io server and/or client version without the need of modifiying your application.


Requirements
------------

1) iOS 7.0 or later, JAS.io uses JavaScript Framework.
2) Socket.io 1.0 or later, on the server side.
3) Access to the server where Socket.io server is installed, in order to drop a file there.

How to install
--------------

1) From "web" copy "jasio-wrapper.html" into the server where the socket.io server is present. You can use nginx (http://nginx.org/) to serve this file.

2) Modify, if necessary, the socket.io script version in "jasio-wrapper.html".

>   <script src="https://cdn.socket.io/socket.io-1.1.0.js"></script>


3) From "ios/JAS.io" copy "JASio.h" and "JASio.m" to your project folder

4) Import JavaScript Framework to your project

How to use
----------

1) Import the header file

>        #import "JASio.h"

2) Create an instance of JAS.io and load the remote script

>        self.jasio = [[JASio alloc] init];
>        // enable or disable JAS.io log. This will help you to find issues
>        [self.jasio setLogEnabled:YES];
>        // load the remote script
>        [self.jasio loadRemoteScriptURL:kRemoteScriptURL readyToConnect:^() {
>           
>        // assign blocks to handle events (connection, disconnect, errors, etc)>                       
>        // ready to execute
>        } onLoadError:^(NSDictionary* error) {
>            NSLog(@"Client did receive an error when loading remote script: %@",error);
>        }];

3) When the script is loaded register blocks for general purposes events (connection, disconnect, errors, etc)

>        __weak JASio* weakJasio = self.jasio;
>            
>        // a block for handling connections.
>        // start sending messages when the client is connected
>        self.jasio.onConnect = ^() {
>            NSLog(@"Client connected");
>        };
>           
>        // a block for handling disconnections
>        self.jasio.onDisconnect = ^() {
>            NSLog(@"Client disconnected");
>                
>            /// here you can fire a reconnection if needed
>            /// if ([weakJasio reconnect]) NSLog(@"reconnected");
>        };
>               
>        // a block for handling errors
>        self.jasio.onError = ^(NSString* tag, NSDictionary* error) {
>            NSLog(@"Client onError %@ - %@",tag,error);
>        };
>                
>        // a block for handling connection errors
>        self.jasio.onConnectError = ^(NSDictionary* error) {
>            NSLog(@"Connection failed with error: %@",error);
>        };
>                
>        // a block for handling timeout
>        self.jasio.onTimeout = ^() {
>            NSLog(@"Connection failed with timeout");
>        };
           
4) Once the onConnect event is received you can register for events and start emitting

>        BOOL eventRegistered = [weakJasio on:@"message" callback:^(NSArray* args) {
>            NSLog(@"Client received message with args: %@",args);
>        }];
>        // check if remote host could register the event
>        if (!eventRegistered) NSLog(@"Not listening for events");

>        // send a hello message
>        BOOL sent = [weakJasio emit:@"message" json:@{@"text":@"Hello JAS.io!"}];
>        if (!sent) NSLog(@"Message not sent");

