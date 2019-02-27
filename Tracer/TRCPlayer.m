//
//  TRCPlayer.m
//  Tracer
//
//  Created by Ben Guo on 2/22/19.
//  Copyright © 2019 tracer. All rights reserved.
//

#import <objc/runtime.h>

#import "TRCPlayer.h"

#import "TRCArgument+Private.h"
#import "TRCTrace.h"
#import "TRCCall.h"
#import "TRCDispatchFunctions.h"
#import "TRCNotNil.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRCPlayer ()

@end

@implementation TRCPlayer

// example: creating a mock subclass
//    NSString *className = trace[@"class"];
//    Class mockClass = objc_allocateClassPair(NSClassFromString(className), "TraceClassMock", 0);
//    objc_registerClassPair(mockClass);
//    self.mock = [[mockClass alloc] init];

+ (void)playTrace:(TRCTrace *)trace
         onTarget:(id)target
       completion:(TRCErrorCompletionBlock)completion {

    // TODO: validate target against trace

    NSTimeInterval longestDelay = 0;
    for (TRCCall *call in trace.calls) {

        SEL aSelector = NSSelectorFromString(call.method);
        NSMethodSignature *signature = [target methodSignatureForSelector:aSelector];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:target];
        [invocation setSelector:aSelector];

        NSTimeInterval delay = ((double)call.millis)/1000.0;
        longestDelay = MAX(longestDelay, delay);

        for (NSUInteger i = 0; i < [call.arguments count]; i++) {
            TRCArgument *arg = call.arguments[i];
            // indices 0 and 1 indicate the hidden arguments self and _cmd
            NSUInteger index = i + 2;
            if (arg.type == TRCArgumentTypePrimitive) {
                NSValue *value = (NSValue *)TRCNotNil(arg.objectValue);
                // Note: primitive types are played back as type double
                double primitive;
                [value getValue:&primitive];
                [invocation setArgument:&primitive atIndex:index];
            }
            else {
                __block id boxedValue = TRCNotNil(arg.objectValue);
                // delay fixes playback of Dict
//                trcDispatchToMainAfter(0.1, ^{
                    [invocation setArgument:&boxedValue atIndex:index];
//                });
                arg.objectValue = boxedValue;
            }
        }

        trcDispatchToMainAfter(delay, ^{
            [invocation invoke];
        });
    }
    trcDispatchToMainAfter(longestDelay + 1, ^{
        completion(nil);
    });

}

@end

NS_ASSUME_NONNULL_END
