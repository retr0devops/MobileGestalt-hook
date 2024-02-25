#include <CoreFoundation/CoreFoundation.h>
#include <Foundation/Foundation.h>
#include <substrate.h>
#import <dlfcn.h>
#include "pac_helper.h"

#define _FUNC_ADDR_(A, O) (const void *)((long)(A) + (O))


CFStringRef (*orig_MGCopyAnswer_internal)(CFStringRef property, uint32_t *outTypeCode);
CFStringRef new_MGCopyAnswer_internal(CFStringRef property, uint32_t *outTypeCode) {
    // your code here ...
    return orig_MGCopyAnswer_internal(property, outTypeCode);
}

CFStringRef (*orig_MGGetStringAnswer)(CFStringRef property);
CFStringRef new_MGGetStringAnswer(CFStringRef property) {
    // your code here ...
    return orig_MGGetStringAnswer_internal(property);
}

static void HookGestalt() {
    // MGCopyAnswer
    void * ptrMGCopyAnswer = dlsym(dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_NOW), "MGCopyAnswer");
    if (memcmp(make_sym_readable(ptrMGCopyAnswer), "\x01\x00\x80\xd2\x01\x00\x00\x14", 8) == 0)
    {
        MSHookFunction(make_sym_callable((void *)_FUNC_ADDR_(ptrMGCopyAnswer, 8)), 
                      (void *)new_MGCopyAnswer_internal,
                      (void **)&orig_MGCopyAnswer_internal);
    }
    else if (memcmp(make_sym_readable(ptrMGCopyAnswer), "\x01\x00\x80\xd2", 4) == 0)
    {
        void *bInstPtr = (void *)((uint8_t *)ptrMGCopyAnswer + 4);
        int32_t bInst = *((int32_t *)make_sym_readable(bInstPtr));
        
        if ((bInst & 0xFC000000) != 0x14000000) {
            return;
        }

        int32_t offset = bInst & 0x3FFFFFF;
        if (offset & 0x2000000)
            offset |= 0xFC000000;
        offset <<= 2;
        
        void *mPtrMGCopyAnswer = (void *)_FUNC_ADDR_(bInstPtr, offset);
        
        MSHookFunction(make_sym_callable(mPtrMGCopyAnswer), 
                      (void *)new_MGCopyAnswer_internal,
                      (void **)&orig_MGCopyAnswer_internal);
        
    }
    // MGGetStringAnswer
    MSHookFunction((void *)dlsym(dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD), "MGGetStringAnswer"), (void*)new_MGGetStringAnswer, (void**)&orig_MGGetStringAnswer); 
}

static __attribute__((constructor)) void Constructor() {
    HookGestalt();
    // your code here
}

