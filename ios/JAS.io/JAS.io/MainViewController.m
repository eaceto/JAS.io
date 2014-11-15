//
//  MainViewController.m
//  JAS.io
//
//  Created by Kimi on 11/13/14.
//
//

#import "MainViewController.h"
#import "JASio.h"

@interface MainViewController ()
@property (nonatomic, strong) JASio* jasio;
@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.jasio = [[JASio alloc] init];
    [self.jasio loadRemoteScriptURL:@"http://178.62.57.164/JASio/jasio-wrapper.html" readyToConnect:^() {
        if (self.jasio) {
            
            __weak JASio* weakJasio = self.jasio;
            self.jasio.onConnect = ^() {
                NSLog(@"Client connected");
                
                // register for listening to events
                BOOL eventRegistered = [weakJasio on:@"post" callback:^(NSArray* args) {
                    NSLog(@"Client received post with args: %@",args);
                }];
                if (!eventRegistered) NSLog(@"Not listening to events");

                BOOL sent = [weakJasio emit:@"message" json:@{@"action":@"post",@"postid":[NSNumber numberWithInt:12345],@"networks":@[@"twitter"]}];
                if (!sent) NSLog(@"Message not sent");
            };
            
            self.jasio.onDisconnect = ^() {
                NSLog(@"Client disconnected");
            };
            
            self.jasio.onError = ^(NSString* tag, NSDictionary* error) {
                NSLog(@"Client onError %@ - %@",tag,error);
            };
            
            self.jasio.onConnectError = ^(NSDictionary* error) {
                NSLog(@"Connection failed with error: %@",error);
            };
            
            self.jasio.onTimeout = ^() {
                NSLog(@"Connection failed with timeout");
            };
            
            [self.jasio connectWithHost:@"178.62.57.164" port:3301 secure:NO];
        }
    } onLoadError:^(NSDictionary* error) {
        NSLog(@"Client did receive an error: %@",error);
    }];

    NSLog(@"Socket is : %@",self.jasio);
    
    
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
