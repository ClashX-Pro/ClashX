//
//  LoginKitWrapper.h
//  ClashX Pro
//
//  Created by yicheng on 2022/3/22.
//  Copyright © 2022 west2online. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LoginKitWrapper : NSObject
+(BOOL) setLogin:(LSSharedFileListRef) inlist path:(NSString *) path;
@end

NS_ASSUME_NONNULL_END
