//
//  ProxyConfigHelper.m
//  com.west2online.ClashX.ProxyConfigHelper
//
//  Created by yichengchen on 2019/8/17.
//  Copyright © 2019 west2online. All rights reserved.
//

#import "ProxyConfigHelper.h"
#import <AppKit/AppKit.h>
#import "ProxyConfigRemoteProcessProtocol.h"
#import "ProxySettingTool.h"

@interface ProxyConfigHelper()
<
NSXPCListenerDelegate,
ProxyConfigRemoteProcessProtocol
>

@property (nonatomic, strong) NSXPCListener *listener;
@property (nonatomic, strong) NSMutableSet<NSXPCConnection *> *connections;
@property (nonatomic, strong) NSTimer *checkTimer;
@property (nonatomic, assign) BOOL shouldQuit;
@property (nonatomic, strong) NSTask *mihomoTask;

@end

@implementation ProxyConfigHelper
- (instancetype)init {
    
    if (self = [super init]) {
        self.connections = [NSMutableSet new];
        self.shouldQuit = NO;
        self.listener = [[NSXPCListener alloc] initWithMachServiceName:@"com.west2online.ClashX.ProxyConfigHelper"];
        self.listener.delegate = self;
    }
    return self;
}

- (void)run {
    [self.listener resume];
    self.checkTimer =
    [NSTimer timerWithTimeInterval:5.f target:self selector:@selector(connectionCheckOnLaunch) userInfo:nil repeats:NO];
    [[NSRunLoop currentRunLoop] addTimer:self.checkTimer forMode:NSDefaultRunLoopMode];
    while (!self.shouldQuit) {
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:2.0]];
    }
}

- (void)connectionCheckOnLaunch {
    if (self.connections.count == 0 && !(self.mihomoTask && self.mihomoTask.isRunning)) {
        self.shouldQuit = YES;
    }
}

- (BOOL)connectionIsVaild: (NSXPCConnection *)connection {
    NSRunningApplication *remoteApp =
    [NSRunningApplication runningApplicationWithProcessIdentifier:connection.processIdentifier];
    return remoteApp != nil;
}

// MARK: - NSXPCListenerDelegate

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection {
//    if (![self connectionIsVaild:newConnection]) {
//        return NO;
//    }
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ProxyConfigRemoteProcessProtocol)];
    newConnection.exportedObject = self;
    __weak NSXPCConnection *weakConnection = newConnection;
    __weak ProxyConfigHelper *weakSelf = self;
    newConnection.invalidationHandler = ^{
        [weakSelf.connections removeObject:weakConnection];
        if (weakSelf.connections.count == 0 && !(weakSelf.mihomoTask && weakSelf.mihomoTask.isRunning)) {
            weakSelf.shouldQuit = YES;
        }
    };
    [self.connections addObject:newConnection];
    [newConnection resume];
    return YES;
}

// MARK: - ProxyConfigRemoteProcessProtocol
- (void)getVersion:(stringReplyBlock)reply {
    NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    if (version == nil) {
        version = @"unknown";
    }
    reply(version);
}

- (void)enableProxyWithPort:(int)port
          socksPort:(int)socksPort
            pac:(NSString *)pac
            filterInterface:(BOOL)filterInterface
                 ignoreList:(NSArray<NSString *>*)ignoreList
            error:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool enableProxyWithport:port socksPort:socksPort pacUrl:pac filterInterface:filterInterface ignoreList:ignoreList];
        reply(nil);
    });
}

- (void)disableProxyWithFilterInterface:(BOOL)filterInterface reply:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool disableProxyWithfilterInterface:filterInterface];
        reply(nil);
    });
}


- (void)restoreProxyWithCurrentPort:(int)port
                          socksPort:(int)socksPort
                               info:(NSDictionary *)dict
                    filterInterface:(BOOL)filterInterface
                              error:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        ProxySettingTool *tool = [ProxySettingTool new];
        [tool restoreProxySetting:dict currentPort:port currentSocksPort:socksPort filterInterface:filterInterface];
        reply(nil);
    });
}

- (void)getCurrentProxySetting:(dictReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSDictionary *info = [ProxySettingTool currentProxySettings];
        reply(info);
    });
}

- (void)startMihomoCoreWithBinaryPath:(NSString *)binaryPath
                           configPath:(NSString *)configPath
                              homeDir:(NSString *)homeDir
                                reply:(stringReplyBlock)reply {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.mihomoTask && self.mihomoTask.isRunning) {
            [self.mihomoTask terminate];
            [self.mihomoTask waitUntilExit];
            self.mihomoTask = nil;
        }

        if (![[NSFileManager defaultManager] fileExistsAtPath:binaryPath]) {
            reply([NSString stringWithFormat:@"Binary not found: %@", binaryPath]);
            return;
        }

        NSTask *task = [[NSTask alloc] init];
        task.executableURL = [NSURL fileURLWithPath:binaryPath];
        task.arguments = @[@"-f", configPath, @"-d", homeDir];

        NSString *logPath = [homeDir stringByAppendingPathComponent:@".mihomo_core.log"];
        [@"" writeToFile:logPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        [[NSFileManager defaultManager] setAttributes:@{NSFilePosixPermissions: @(0644)}
                                         ofItemAtPath:logPath error:nil];

        NSPipe *pipe = [NSPipe pipe];
        task.standardOutput = pipe;
        task.standardError = pipe;

        pipe.fileHandleForReading.readabilityHandler = ^(NSFileHandle *handle) {
            NSData *data = [handle availableData];
            if (data.length > 0) {
                NSString *output = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                NSLog(@"[mihomo_core] %@", output);
                NSFileHandle *logHandle = [NSFileHandle fileHandleForWritingAtPath:logPath];
                [logHandle seekToEndOfFile];
                [logHandle writeData:data];
                [logHandle closeFile];
            }
        };

        NSError *error = nil;
        [task launchAndReturnError:&error];
        if (error) {
            reply([NSString stringWithFormat:@"Launch failed: %@", error.localizedDescription]);
            return;
        }

        self.mihomoTask = task;

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!task.isRunning) {
                NSLog(@"[mihomo_core] Process exited early with status: %d", task.terminationStatus);
            }
        });

        reply(nil);
    });
}

- (void)stopMihomoCoreWithReply:(stringReplyBlock)reply {
    NSTask *task = self.mihomoTask;
    self.mihomoTask = nil;
    if (task && task.isRunning) {
        [task terminate];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [task waitUntilExit];
            reply(nil);
        });
    } else {
        reply(nil);
    }
}

@end
