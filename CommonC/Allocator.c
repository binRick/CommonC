/*
 *  Copyright (c) 2013, Stefan Johnson
 *  All rights reserved.
 *
 *  Redistribution and use in source and binary forms, with or without modification,
 *  are permitted provided that the following conditions are met:
 *
 *  1. Redistributions of source code must retain the above copyright notice, this list
 *     of conditions and the following disclaimer.
 *  2. Redistributions in binary form must reproduce the above copyright notice, this
 *     list of conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#define CC_QUICK_COMPILE
#include "Allocator.h"
#include "Assertion_Private.h"
#include "CallbackAllocator.h"
#include "DebugAllocator.h"

#pragma mark - Standard Allocator Implementation
static void *StandardAllocator(void *Data, size_t Size)
{
    return malloc(Size);
}

static void *StandardReallocator(void *Data, void *Ptr, size_t Size)
{
    return realloc(Ptr, Size);
}

static void StandardDeallocator(void *Ptr)
{
    free(Ptr);
}


#pragma mark - Custom Allocator Implementation
static void *CustomAllocator(void **Data, size_t Size)
{
    void **Ptr = NULL;
    if ((Data) && (Data[0]))
    {
        Ptr = ((CCAllocatorFunction)Data[0])(NULL, Size + (sizeof(void*) * 3));
        if (Ptr)
        {
            *Ptr++ = Data[0];
            *Ptr++ = Data[1];
            *Ptr++ = Data[2];
        }
    }
    
    return Ptr;
}

static void *CustomReallocator(void **Data, void **Ptr, size_t Size)
{
    Ptr -= 3;
    Ptr = ((CCReallocatorFunction)Ptr[1])(NULL, Ptr, Size + (sizeof(void*) * 3));
    if (Ptr) Ptr += 3;
    
    return Ptr;
}

static void CustomDeallocator(void **Ptr)
{
    Ptr = Ptr - 3;
    ((CCDeallocatorFunction)Ptr[2])(Ptr);
}


#pragma mark - Callback Allocator Implementation
static void *CallbackAllocator(CCCallbackAllocatorFunction Data, size_t Size)
{
    if (Data) Data(CCCallbackAllocatorEventAllocatePre, NULL, &Size);
    
    void **Ptr = malloc(Size + sizeof(CCCallbackAllocatorFunction));
    if (Ptr) *Ptr++ = Data;
    
    if (Data) Data(CCCallbackAllocatorEventAllocatePost, Ptr, &Size);
    
    return Ptr;
}

static void *CallbackReallocator(CCCallbackAllocatorFunction Data, void *Ptr, size_t Size)
{
    Data = ((void**)Ptr)[-1];
    if (Data) Data(CCCallbackAllocatorEventReallocatePre, Ptr, &Size);
    
    Ptr = realloc((void**)Ptr - 1, Size + sizeof(CCCallbackAllocatorFunction));
    if (Ptr) Ptr = (void**)Ptr + 1;
    
    if (Data) Data(CCCallbackAllocatorEventReallocatePost, Ptr, &Size);
    
    return Ptr;
}

static void CallbackDeallocator(void *Ptr)
{
    CCCallbackAllocatorFunction Data = ((void**)Ptr)[-1];
    if (Data) Data(CCCallbackAllocatorEventDeallocatePre, Ptr, NULL);
    
    free((void**)Ptr - 1);
}


#pragma mark - Aligned Allocator Implementation
typedef struct {
    void *head;
    size_t alignment;
} CCAlignedMemoryHeader;

static void *AlignedAllocator(size_t *Alignment, size_t Size)
{
    void *Head = malloc(Size + *Alignment + sizeof(CCAlignedMemoryHeader));
    if (Head)
    {
        void *Ptr = (void*)((uintptr_t)(Head + sizeof(CCAlignedMemoryHeader) + sizeof(CCAllocatorHeader) + *Alignment - 1) & ~(*Alignment - 1)) - sizeof(CCAllocatorHeader);
        ((CCAlignedMemoryHeader*)Ptr)[-1] = (CCAlignedMemoryHeader){ .head = Head, .alignment = *Alignment };
        
        return Ptr;
    }
    
    return NULL;
}

static void *AlignedReallocator(void *Data, void *Ptr, size_t Size)
{
    CCAlignedMemoryHeader *Header = Ptr - sizeof(CCAlignedMemoryHeader);
    size_t Alignment = Header->alignment;
    int Allocator = *(int*)Ptr;
    
    void *Head = realloc(Header->head, Size + Alignment + sizeof(CCAlignedMemoryHeader));
    if (Head)
    {
        Ptr = (void*)((uintptr_t)(Head + sizeof(CCAlignedMemoryHeader) + sizeof(CCAllocatorHeader) + Alignment - 1) & ~(Alignment - 1)) - sizeof(CCAllocatorHeader);
        ((CCAlignedMemoryHeader*)Ptr)[-1] = (CCAlignedMemoryHeader){ .head = Head, .alignment = Alignment };
        *(int*)Ptr = Allocator;
        
        return Ptr;
    }
    
    return NULL;
}

static void AlignedDeallocator(void *Ptr)
{
    free(((CCAlignedMemoryHeader*)Ptr)[-1].head);
}


#pragma mark - BoundsCheck Allocator Implementation
static void *BoundsCheckAllocator(void *Data, size_t Size)
{
    void *Ptr = malloc(Size + 16 + sizeof(size_t));
    if (Ptr)
    {
        for (size_t Loop = 0; Loop < 8; Loop++)
        {
            ((uint8_t*)Ptr + sizeof(size_t))[Loop] = Loop;
            ((uint8_t*)Ptr + sizeof(size_t))[8 + Size + Loop] = Loop;
        }

        *(size_t*)Ptr = Size;
        
        Ptr += 8 + sizeof(size_t);
    }
    
    return Ptr;
}

static void *BoundsCheckReallocator(void *Data, void *Ptr, size_t Size)
{
    Ptr -= 8 + sizeof(size_t);
    
    for (size_t Loop = 0, CurSize = *(size_t*)Ptr; Loop < 8; Loop++)
    {
        CCAssertLog(((uint8_t*)Ptr + sizeof(size_t))[Loop] == Loop, "Data changed before bounds");
        CCAssertLog(((uint8_t*)Ptr + sizeof(size_t))[8 + CurSize + Loop] == Loop, "Data changed after bounds");
    }
    
    Ptr = realloc(Ptr, Size + 16 + sizeof(size_t));
    if (Ptr)
    {
        for (size_t Loop = 0; Loop < 8; Loop++)
        {
            ((uint8_t*)Ptr + sizeof(size_t))[Loop] = Loop;
            ((uint8_t*)Ptr + sizeof(size_t))[8 + Size + Loop] = Loop;
        }

        *(size_t*)Ptr = Size;
        
        Ptr += 8 + sizeof(size_t);
    }
    
    return Ptr;
}

static void BoundsCheckDeallocator(void *Ptr)
{
    Ptr -= 8 + sizeof(size_t);
    
    for (size_t Loop = 0, CurSize = *(size_t*)Ptr; Loop < 8; Loop++)
    {
        CCAssertLog(((uint8_t*)Ptr + sizeof(size_t))[Loop] == Loop, "Data changed before bounds");
        CCAssertLog(((uint8_t*)Ptr + sizeof(size_t))[8 + CurSize + Loop] == Loop, "Data changed after bounds");
    }
    
    free(Ptr);
}


#pragma mark - Debug Allocator Implementation
static void *DebugAllocator(CCDebugAllocatorInfo *Data, size_t Size)
{
    void *Ptr = malloc(Size);
    if (Ptr) CCDebugAllocatorTrack(Ptr, *Data);
    
    return Ptr;
}

static void *DebugReallocator(CCDebugAllocatorInfo *Data, void *Ptr, size_t Size)
{
    void *NewPtr = realloc(Ptr, Size);
    
    if (NewPtr) CCDebugAllocatorTrackReplaced(Ptr, NewPtr, *Data);
    
    return NewPtr;
}

static void DebugDeallocator(void *Ptr)
{
    CCDebugAllocatorUntrack(Ptr);
    free(Ptr);
}


#pragma mark - Static Allocator Implementation
static void *StaticAllocator(void *Data, size_t Size)
{
    return NULL;
}

static void *StaticReallocator(void *Data, void *Ptr, size_t Size)
{
    if (Ptr)
    {
        const size_t *MaxSize = Ptr - sizeof(size_t);
        
        if (Size <= *MaxSize) return Ptr;
    }
    
    return NULL;
}

static void StaticDeallocator(void *Ptr)
{
}


#pragma mark -

#ifndef CC_ALLOCATORS_MAX
#define CC_ALLOCATORS_MAX 20 //If more is needed just recompile.
#endif
_Static_assert(CC_ALLOCATORS_MAX >= 7, "Allocator max too small, must allow for the default allocators.");



static struct {
    //lock
    struct {
        CCAllocatorFunction allocator;
        CCReallocatorFunction reallocator;
        CCDeallocatorFunction deallocator;
    } allocators[CC_ALLOCATORS_MAX];
} Allocators = {
    .allocators = {
        { .allocator = StaticAllocator, .reallocator = StaticReallocator, .deallocator = StaticDeallocator },
        { .allocator = StandardAllocator, .reallocator = StandardReallocator, .deallocator = StandardDeallocator },
        { .allocator = (CCAllocatorFunction)CustomAllocator, .reallocator = (CCReallocatorFunction)CustomReallocator, .deallocator = (CCDeallocatorFunction)CustomDeallocator },
        { .allocator = (CCAllocatorFunction)CallbackAllocator, .reallocator = (CCReallocatorFunction)CallbackReallocator, .deallocator = CallbackDeallocator },
        { .allocator = (CCAllocatorFunction)AlignedAllocator, .reallocator = AlignedReallocator, .deallocator = AlignedDeallocator },
        { .allocator = (CCAllocatorFunction)BoundsCheckAllocator, .reallocator = BoundsCheckReallocator, .deallocator = BoundsCheckDeallocator },
        { .allocator = (CCAllocatorFunction)DebugAllocator, .reallocator = (CCReallocatorFunction)DebugReallocator, .deallocator = DebugDeallocator }
    }
};


void CCAllocatorAdd(int Index, CCAllocatorFunction Allocator, CCReallocatorFunction Reallocator, CCDeallocatorFunction Deallocator)
{
    CCAssertLog((Index > 3) && (Index < CC_ALLOCATORS_MAX), "Index (%d) cannot be negative, or replace any standard allocators, or exceed the maximum number of allocators (%d).", Index, CC_ALLOCATORS_MAX);
    
    //Allocators.lock <- lock
    if ((Allocators.allocators[Index].allocator) || (Allocators.allocators[Index].reallocator) || (Allocators.allocators[Index].deallocator)) CC_LOG_WARNING("Replacing allocator (%p:%p:%p) at index (%d) with (%p:%p:%p).", Allocators.allocators[Index].allocator, Allocators.allocators[Index].reallocator, Allocators.allocators[Index].deallocator, Index, Allocator, Reallocator, Deallocator);
    Allocators.allocators[Index].allocator = Allocator;
    Allocators.allocators[Index].reallocator = Reallocator;
    Allocators.allocators[Index].deallocator = Deallocator;
    //release lock
}

void *CCMemoryAllocate(CCAllocatorType Type, size_t Size)
{
    const int Index = Type.allocator;
    if (Index < 0) return NULL;
    
    CCAssertLog(Index < CC_ALLOCATORS_MAX, "Index (%d) exceeds the number of allocators available (%d).", Index, CC_ALLOCATORS_MAX);
    const CCAllocatorFunction Allocator = Allocators.allocators[Index].allocator;
    
    CCAllocatorHeader *Ptr = NULL;
    if (Allocator)
    {
        const size_t NewSize = Size + sizeof(CCAllocatorHeader);
        if (NewSize > Size)
        {
            Ptr = Allocator(Type.data, NewSize);
            if (Ptr)
            {
                (*Ptr++) = (CCAllocatorHeader){
                    .allocator = Index,
                    .refCount = 1,
                    .destructor = NULL
                };
            }
        }
        
        else CC_LOG_DEBUG("Internal error: Integer overflow. Try reducing allocation size (%zu). #Attention #Error", Size);
    }
    
    return Ptr;
}

void *CCMemoryReallocate(CCAllocatorType Type, void *Ptr, size_t Size)
{
    if (!Ptr) return CCMemoryAllocate(Type, Size);
    
    const int Index = ((CCAllocatorHeader*)Ptr)[-1].allocator;
    if (Index < 0) return NULL;
    
    CCAssertLog(Index < CC_ALLOCATORS_MAX, "Memory has been modified outside of its bounds.");
    const CCReallocatorFunction Reallocator = Allocators.allocators[Index].reallocator;
    
    const size_t NewSize = Size + sizeof(CCAllocatorHeader);
    if (NewSize > Size)
    {
        Ptr = Reallocator? Reallocator(Type.data, (CCAllocatorHeader*)Ptr - 1, NewSize) : NULL;
        if (Ptr) Ptr = (CCAllocatorHeader*)Ptr + 1;
    }
    
    else
    {
        CC_LOG_DEBUG("Internal error: Integer overflow. Try reducing allocation size (%zu). #Attention #Error", Size);
        Ptr = NULL;
    }
    
    return Ptr;
}

void *CCMemoryRetain(void *Ptr)
{
    CCAssertLog(Ptr, "Ptr must not be null");
    
    CCAllocatorHeader *Header = (CCAllocatorHeader*)Ptr - 1;
    
    const int Index = Header->allocator;
    if (Index < 0) return Ptr;
    
#if CC_ALLOCATOR_USING_STDATOMIC
    atomic_fetch_add_explicit(&Header->refCount, 1, memory_order_relaxed);
#elif CC_ALLOCATOR_USING_OSATOMIC
    OSAtomicIncrement32(&Header->refCount);
#else
    Header->refCount++;
#endif
    
    return Ptr;
}

int32_t CCMemoryRefCount(void *Ptr)
{
    CCAssertLog(Ptr, "Ptr must not be null");
    
    CCAllocatorHeader *Header = (CCAllocatorHeader*)Ptr - 1;
    
    const int Index = Header->allocator;
    if (Index < 0) return INT32_MAX;
    
#if CC_ALLOCATOR_USING_STDATOMIC
    return atomic_load_explicit(&Header->refCount, memory_order_relaxed);
#elif CC_ALLOCATOR_USING_OSATOMIC
    return &Header->refCount;
#else
    return Header->refCount;
#endif
}

void CCMemoryDeallocate(void *Ptr)
{
    CCAssertLog(Ptr, "Ptr must not be null");
    
    CCAllocatorHeader *Header = (CCAllocatorHeader*)Ptr - 1;
    
    const int Index = Header->allocator;
    if (Index < 0) return;
    
#if CC_ALLOCATOR_USING_STDATOMIC
    const int32_t Count = atomic_fetch_sub_explicit(&Header->refCount, 1, memory_order_release) - 1;
#elif CC_ALLOCATOR_USING_OSATOMIC
    const int32_t Count = OSAtomicDecrement32(&Header->refCount);
#else
    const int32_t Count = --Header->refCount;
#endif
    
    CCAssertLog(Index < CC_ALLOCATORS_MAX, "Memory has been modified outside of its bounds.");
    CCAssertLog(Count >= 0, "Allocation has been over released.");
    
    if (Count == 0)
    {
#if CC_ALLOCATOR_USING_STDATOMIC
        atomic_thread_fence(memory_order_acquire);
#elif CC_ALLOCATOR_USING_OSATOMIC
        OSMemoryBarrier();
#endif
        
        if (Header->destructor) Header->destructor(Ptr);
        
        const CCDeallocatorFunction Deallocator = Allocators.allocators[Index].deallocator;
        
        if (Deallocator) Deallocator(Header);
    }
}

CCMemoryDestructorCallback CCMemorySetDestructor(void *Ptr, CCMemoryDestructorCallback Destructor)
{
    CCAssertLog(Ptr, "Ptr must not be null");
    
    CCAllocatorHeader *Header = (CCAllocatorHeader*)Ptr - 1;
    
    CCMemoryDestructorCallback PrevDestructor = Header->destructor;
    Header->destructor = Destructor;
    
    return PrevDestructor;
}
