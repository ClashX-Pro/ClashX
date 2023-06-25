#import "NSMutableArray+Safe.h"
#import <objc/runtime.h>

@implementation NSMutableArray(Safe)
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if (@available(macOS 14, *)) {
            swizzleInstanceMethod(NSClassFromString(@"__NSArrayM"), @selector(objectAtIndex:), @selector(hookObjectAtIndex:));
            swizzleInstanceMethod(NSClassFromString(@"__NSArrayM"), @selector(replaceObjectAtIndex:withObject:), @selector(hookReplaceObjectAtIndex:withObject:));
        }
    });
}


- (id)hookObjectAtIndex:(NSUInteger)index {
    @synchronized (self) {
        if (index < self.count) {
            return [self hookObjectAtIndex:index];
        }
        return nil;
    }
}

- (void) hookReplaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject {
    @synchronized (self) {
        if (index < self.count && anObject) {
            [self hookReplaceObjectAtIndex:index withObject:anObject];
        } else {
            if (!anObject) {
                return;
            }
            if (index >= self.count) {
                return;
            }
        }
    }
}


void swizzleInstanceMethod(Class cls, SEL origSelector, SEL newSelector)
{
    if (!cls) {
        return;
    }
    /* if current class not exist selector, then get super*/
    Method originalMethod = class_getInstanceMethod(cls, origSelector);
    Method swizzledMethod = class_getInstanceMethod(cls, newSelector);
    
    /* add selector if not exist, implement append with method */
    if (class_addMethod(cls,
                        origSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod)) ) {
        /* replace class instance method, added if selector not exist */
        /* for class cluster , it always add new selector here */
        class_replaceMethod(cls,
                            newSelector,
                            method_getImplementation(originalMethod),
                            method_getTypeEncoding(originalMethod));
        
    } else {
        /* swizzleMethod maybe belong to super */
        class_replaceMethod(cls,
                            newSelector,
                            class_replaceMethod(cls,
                                                origSelector,
                                                method_getImplementation(swizzledMethod),
                                                method_getTypeEncoding(swizzledMethod)),
                            method_getTypeEncoding(originalMethod));
    }
}
@end
