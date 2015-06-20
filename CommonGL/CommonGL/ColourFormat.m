/*
 *  Copyright (c) 2014 Stefan Johnson
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

#import "Default_Private.h"
#import "ColourFormat.h"
#import "Version.h"
#import <CommonC/Types.h>
#import <CommonObjC/Assertion.h>
#import <CommonC/Extensions.h>


static CC_FORCE_INLINE unsigned int CCColourComponentGetBitSize(CCColourComponent Component) CC_CONSTANT_FUNCTION;
static CCColourComponent CCColourFormatRGBGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision);
static CCColourComponent CCColourFormatYUVGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision);
static CCColourComponent CCColourFormatHSGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision);


//Retrieves channels for the specified plane, and restructures the channel offsets so they're ordered in the plane
void CCColourFormatChannel4InPlanar(CCColourFormat ColourFormat, unsigned int PlanarIndex, CCColourFormat Channels[4])
{
    CCAssertLog((ColourFormat & CCColourFormatOptionMask) == CCColourFormatOptionChannel4, @"Only works on formats that use the channel 4 structure");
    
    static const CCColourFormat Offsets[4] = {
        CCColourFormatChannelOffset0,
        CCColourFormatChannelOffset1,
        CCColourFormatChannelOffset2,
        CCColourFormatChannelOffset3
    };
    
    memset(Channels, 0, sizeof(CCColourFormat) * 4);
    
    for (int Loop = 0, Index = 0; Loop < 4; Loop++)
    {
        CCColourFormat Channel = (ColourFormat >> Offsets[Loop]) & CCColourFormatChannelMask;
        if (((Channel & CCColourFormatChannelPlanarIndexMask) == PlanarIndex) && (Channel & CCColourFormatChannelBitSizeMask))
        {
            Channels[Index++] = Channel;
        }
    }
}

_Bool CCColourFormatGLRepresentation(CCColourFormat ColourFormat, unsigned int PlanarIndex, GLenum *InputType, GLenum *InputFormat, GLenum *InternalFormat)
{
    if (InputType) *InputType = 0;
    if (InputFormat) *InputFormat = 0;
    if (InternalFormat) *InternalFormat = 0;
    
    if ((ColourFormat & CCColourFormatModelMask) == CCColourFormatModelRGB)
    {
        const _Bool sRGB = (ColourFormat & CCColourFormatSpaceMask) == CCColourFormatSpaceRGB_sRGB, Normalized = ColourFormat & CCColourFormatNormalized;
#pragma unused(sRGB)
#pragma unused(Normalized)
        CCColourFormat Channels[4];
        
        CCColourFormatChannel4InPlanar(ColourFormat, PlanarIndex, Channels);
        
        int Channel1Size, Channel2Size, Channel3Size, Channel4Size;
        if ((Channel1Size = (Channels[0] & CCColourFormatChannelBitSizeMask) >> CCColourFormatChannelBitSize))
        {
            /*
             Table as according to GL docs, however spec says something different :/
             Format:
             Version    GL_RED    GL_GREEN     GL_BLUE    GL_ALPHA    GL_RG    GL_RGB    GL_BGR   GL_RGBA    GL_BGRA
             GL 2       x         x            x          x                    x         x        x           x
             GL 3       x                                             x        x         x        x           x
             GL 4       x                                             x        x         x        x           x
             ES 1                                         x                    x                  x
             ES 2                                         x                    x                  x
             ES 3       x                                 x           x        x                  x
             
             Version    GL_COLOR_INDEX    GL_LUMINANCE    GL_LUMINANCE_ALPHA    GL_STENCIL_INDEX     GL_DEPTH_COMPONENT    GL_DEPTH_STENCIL
             GL 2       x                 x               x
             GL 3
             GL 4                                                               x                    x                     x
             ES 1                         x               x
             ES 2                         x               x
             ES 3                         x               x                                          x                     x
             
             Version    GL_RED_INTEGER   GL_RG_INTEGER    GL_RGB_INTEGER   GL_BGR_INTEGER   GL_RGBA_INTEGER   GL_BGRA_INTEGER
             GL 2
             GL 3
             GL 4       x                x                x                x                x                 x
             ES 1
             ES 2
             ES 3       x                x                x                                 x
             
             
             Type:
             Version    GL_BITMAP    GL_UNSIGNED_BYTE    GL_BYTE      GL_UNSIGNED_SHORT    GL_SHORT    GL_UNSIGNED_INT      GL_INT
             GL 2       x            x                   x            x                    x           x                    x
             GL 3                    x                   x            x                    x           x                    x
             GL 4                    x                   x            x                    x           x                    x
             ES 1                    x
             ES 2                    x
             ES 3                    x                   x            x                    x           x                    x
             
             Version    GL_HALF_FLOAT    GL_FLOAT     GL_UNSIGNED_BYTE_3_3_2   GL_UNSIGNED_BYTE_2_3_3_REV
             GL 2                        x            x                        x
             GL 3                        x            x                        x
             GL 4                        x            x                        x
             ES 1
             ES 2
             ES 3       x                x
             
             Version    GL_UNSIGNED_SHORT_5_6_5      GL_UNSIGNED_SHORT_5_6_5_REV     GL_UNSIGNED_SHORT_4_4_4_4    GL_UNSIGNED_SHORT_4_4_4_4_REV
             GL 2       x                            x                               x                            x
             GL 3       x                            x                               x                            x
             GL 4       x                            x                               x                            x
             ES 1       x                                                            x
             ES 2       x                                                            x
             ES 3       x                                                            x
             
             Version    GL_UNSIGNED_SHORT_5_5_5_1    GL_UNSIGNED_SHORT_1_5_5_5_REV    GL_UNSIGNED_INT_8_8_8_8     GL_UNSIGNED_INT_8_8_8_8_REV
             GL 2       x                            x                                x                           x
             GL 3       x                            x                                x                           x
             GL 4       x                            x                                x                           x
             ES 1       x
             ES 2       x
             ES 3       x
             
             Version    GL_UNSIGNED_INT_10_10_10_2    GL_UNSIGNED_INT_2_10_10_10_REV    GL_UNSIGNED_INT_10F_11F_11F_REV
             GL 2       x                             x
             GL 3       x                             x
             GL 4       x                             x
             ES 1
             ES 2
             ES 3                                     x                                 x
             
             Version    GL_UNSIGNED_INT_5_9_9_9_REV     GL_UNSIGNED_INT_24_8     GL_FLOAT_32_UNSIGNED_INT_24_8_REV
             GL 2
             GL 3
             GL 4
             ES 1
             ES 2
             ES 3       x                               x                        x
             */
            
            if (!Channels[1]) //Single Channel
            {
                if ((Channel1Size == 8) || (Channel1Size == 16) || (Channel1Size == 32))
                {
                    
                }
                
                if (InputFormat)
                {
                    switch (Channels[0] & CCColourFormatChannelIndexMask)
                    {
                        CC_GL_VERSION_ACTIVE(1_0, NA, 3_0, NA, case CCColourFormatChannelRed:
                            CC_GL_VERSION_ACTIVE(4_0, NA, 3_0, NA,
                                if (!Normalized) *InputFormat = GL_RED_INTEGER;
                                else
                            );
                            *InputFormat = GL_RED;
                            break;
                        );
                        
                        CC_GL_VERSION_ACTIVE(1_0, 2_1, NA, NA, case CCColourFormatChannelGreen:
                            *InputFormat = GL_GREEN;
                            break;
                        );
                        
                        CC_GL_VERSION_ACTIVE(1_0, 2_1, NA, NA, case CCColourFormatChannelBlue:
                            *InputFormat = GL_BLUE;
                            break;
                        );
                        
                        CC_GL_VERSION_ACTIVE(1_0, 2_1, 1_0, NA, case CCColourFormatChannelAlpha:
                            *InputFormat = GL_ALPHA;
                            break;
                        );
                    }
                }
            }
            
            else
            {
                
            }
            
            switch (Channels[0] & CCColourFormatChannelIndexMask)
            {
                case CCColourFormatChannelRed:
                    if (Channels[1])
                    break;
                    
                case CCColourFormatChannelGreen:
                    break;
                    
                case CCColourFormatChannelBlue:
                    break;
                    
                case CCColourFormatChannelAlpha:
                    break;
            }
        }
    }
    
    return FALSE;
}

size_t CCColourFormatPackIntoBuffer(CCColour Colour, void *Data)
{
    CCAssertLog((Colour.type & CCColourFormatOptionMask) == CCColourFormatOptionChannel4, @"Only supports colour formats with 4 channel configuration");
    _Static_assert((CCColourFormatChannelBitSizeMask >> CCColourFormatChannelBitSize) <= (sizeof(uint64_t) * 8), "Exceeds limit of packed data");
    
    int ChunkIndex = 0, ChunkSize = 0;
    uint64_t Chunk = 0;
    
    for (int Loop = 0; Loop < 4 && Colour.channel[Loop].type; Loop++)
    {
        const unsigned int Bits = CCColourComponentGetBitSize(Colour.channel[Loop]);
        
        if ((ChunkSize + Bits) > (sizeof(Chunk) * 8))
        {
            const int Remaining = (ChunkSize + Bits) - (sizeof(Chunk) * 8);
            const int Fit = Bits - Remaining;
            
            Chunk |= (Colour.channel[Loop].u64 & CCBitSet(Fit)) << ChunkSize;
            ((typeof(Chunk)*)Data)[ChunkIndex++] = Chunk;
            
            Chunk = (Colour.channel[Loop].u64 >> Fit) & CCBitSet(Remaining);
            ChunkSize = Remaining;
        }
        
        else
        {
            Chunk |= (Colour.channel[Loop].u64 & CCBitSet(Bits)) << ChunkSize;
            ChunkSize += Bits;
        }
    }
    
    const int Count = (ChunkSize + 7) / 8;
    for (int Loop = 0, Loop2 = ChunkIndex * sizeof(Chunk); Loop < Count; Loop++, Loop2++)
    {
        ((uint8_t*)Data)[Loop2] = ((uint8_t*)&Chunk)[Loop];
    }
    
    return (ChunkIndex * sizeof(Chunk)) + Count;
}

size_t CCColourFormatGetComponentChannelIndex(CCColour Colour, CCColourFormat Index)
{
    for (size_t Loop = 0; Loop < 4 && Colour.channel[Loop].type; Loop++)
    {
        if ((Colour.channel[Loop].type & CCColourFormatChannelIndexMask) == Index)
        {
            return Loop;
        }
    }
    
    return SIZE_MAX;
}

CCColourComponent CCColourFormatGetComponent(CCColour Colour, CCColourFormat Index)
{
    const size_t ChannelIndex = CCColourFormatGetComponentChannelIndex(Colour, Index);
    
    return ChannelIndex == SIZE_MAX ? (CCColourComponent){ .type = 0, .u64 = 0 } : Colour.channel[ChannelIndex];
}

CCColourComponent CCColourFormatGetComponentWithPrecision(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision)
{
    static CCColourComponent (* const Getters[CCColourFormatModelMask >> 2])(CCColour, CCColourFormat, CCColourFormat, int) = {
        [CCColourFormatModelRGB >> 2] = CCColourFormatRGBGetComponent,
        [CCColourFormatModelYUV >> 2] = CCColourFormatYUVGetComponent,
        [CCColourFormatModelHS >> 2] = CCColourFormatHSGetComponent
    };
    
    CCColourComponent (* const Getter)(CCColour, CCColourFormat, CCColourFormat, int) = Getters[(Colour.type & CCColourFormatModelMask) >> 2];
    
    return Getter? Getter(Colour, Index, Type, Precision) : (CCColourComponent){ .type = 0, .u64 = 0 };
}

static CC_FORCE_INLINE CC_CONSTANT_FUNCTION unsigned int CCColourComponentGetBitSize(CCColourComponent Component)
{
    return (Component.type & CCColourFormatChannelBitSizeMask) >> CCColourFormatChannelBitSize;
}

#pragma mark - Component Precision Conversions

static uint64_t CCColourFormatComponentPrecisionConversionLinear(uint64_t Value, int OldBitSize, int NewBitSize)
{
    const uint64_t OldSet = CCBitSet(OldBitSize), NewSet = CCBitSet(NewBitSize);
    return (uint64_t)(((double)Value * (double)NewSet + (double)(OldSet >> 1)) / (double)OldSet) - (NewBitSize >= 54 ? 1 : 0);
}

static uint64_t CCColourFormatComponentPrecisionConversionLinearSigned(uint64_t Value, int OldBitSize, int NewBitSize)
{
    const uint64_t OldSet = CCBitSet(OldBitSize), NewSet = CCBitSet(NewBitSize);
    return Value == 0 ? 0 : CCColourFormatComponentPrecisionConversionLinear((Value + (OldSet / 2) + 1) & OldSet, OldBitSize, NewBitSize) - (NewSet / 2) - 1;
}

static CCColourComponent CCColourFormatLinearPrecisionConversion(CCColourComponent Component, CCColourFormat OldType, CCColourFormat NewType, int NewPrecision)
{
    if ((OldType == NewType) && (Component.type == NewPrecision)) return Component;
    
    if ((OldType & CCColourFormatTypeMask) == CCColourFormatTypeUnsignedInteger)
    {
        if (((NewType & CCColourFormatTypeMask) == CCColourFormatTypeSignedInteger) || ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeUnsignedInteger))
        {
            Component.u64 = CCColourFormatComponentPrecisionConversionLinear(Component.u64 & (CCBitSet(CCColourComponentGetBitSize(Component))), CCColourComponentGetBitSize(Component), NewPrecision);
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
        
        else if ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeFloat)
        {
            CCAssertLog(NewPrecision == 32, "Only supports 32-bit floats");
            
            Component.f32 = (float)(Component.u64 & (CCBitSet(CCColourComponentGetBitSize(Component))));
            
            if ((NewType & CCColourFormatNormalized))
            {
                Component.f32 /= CCBitSet(CCColourComponentGetBitSize(Component));
            }
            
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
    }
    
    else if ((OldType & CCColourFormatTypeMask) == CCColourFormatTypeSignedInteger)
    {
        if (((NewType & CCColourFormatTypeMask) == CCColourFormatTypeSignedInteger) || ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeUnsignedInteger))
        {
            Component.u64 = CCColourFormatComponentPrecisionConversionLinearSigned(Component.u64 & (CCBitSet(CCColourComponentGetBitSize(Component))), CCColourComponentGetBitSize(Component), NewPrecision);
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
        
        else if ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeFloat)
        {
            CCAssertLog(NewPrecision == 32, "Only supports 32-bit floats");
            
            Component.f32 = (float)((Component.u64 + (CCBitSet(CCColourComponentGetBitSize(Component)) / 2) + 1) & CCBitSet(CCColourComponentGetBitSize(Component)));
            Component.f32 -= (CCBitSet(CCColourComponentGetBitSize(Component)) / 2) + 1;
            
            if ((NewType & CCColourFormatNormalized))
            {
                Component.f32 = fmaxf(Component.f32 / (CCBitSet(CCColourComponentGetBitSize(Component)) / 2), -1.0f);
            }
            
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
    }
    
    else if ((OldType & CCColourFormatTypeMask) == CCColourFormatTypeFloat)
    {
        if ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeFloat)
        {
            CCAssertLog(NewPrecision == 32, "Only supports 32-bit floats");
            
            return Component;
        }
        
        else if ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeUnsignedInteger)
        {
            const uint64_t NewValueMax = CCBitSet(NewPrecision);
            if ((OldType & CCColourFormatNormalized))
            {
                Component.f32 *= NewValueMax;
            }
            
            Component.u64 = Component.f32 < 0.0f ? 0 : (uint64_t)Component.f32;
            if (Component.u64 > NewValueMax) Component.u64 = NewValueMax;
            
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
        
        else if ((NewType & CCColourFormatTypeMask) == CCColourFormatTypeSignedInteger)
        {
            const uint64_t NewValueMax = CCBitSet(NewPrecision);
            if ((OldType & CCColourFormatNormalized))
            {
                Component.f32 *= (NewValueMax / 2) + (Component.f32 < 0 ? 1 : 0);
            }
            
            Component.u64 = (uint64_t)Component.f32 & NewValueMax;
            Component.type = (NewPrecision << CCColourFormatChannelBitSize) | (Component.type & CCColourFormatChannelIndexMask);
            
            return Component;
        }
    }
    
    return (CCColourComponent){ .type = 0, .u64 = 0 };
}

static CCColourComponent CCColourFormatRGBPrecisionConversion(CCColourComponent Component, CCColourFormat OldType, CCColourFormat NewType, int NewPrecision)
{
    CCAssertLog((OldType & CCColourFormatModelMask) == CCColourFormatModelRGB, "Must be a colour space within the RGB model");
    
    if ((OldType == NewType) && (Component.type == NewPrecision)) return Component;
    
    CCAssertLog((OldType & CCColourFormatSpaceMask) == CCColourFormatSpaceRGB_RGB, "Only supports linear RGB currently");
    CCAssertLog((NewType & CCColourFormatSpaceMask) == CCColourFormatSpaceRGB_RGB, "Only supports linear RGB currently");
    
    return CCColourFormatLinearPrecisionConversion(Component, OldType, NewType, NewPrecision);
}

static CCColourComponent CCColourFormatYUVPrecisionConversion(CCColourComponent Component, CCColourFormat OldType, CCColourFormat NewType, int NewPrecision)
{
    CCAssertLog((OldType & CCColourFormatModelMask) == CCColourFormatModelYUV, "Must be a colour space within the YUV model");
    
    if ((OldType == NewType) && (Component.type == NewPrecision)) return Component;
    
    CCAssertLog((OldType & CCColourFormatSpaceMask) == CCColourFormatSpaceYUV_YpCbCr, "Only supports YpCbCr currently");
    
    return CCColourFormatLinearPrecisionConversion(Component, OldType, NewType, NewPrecision);
}

static CCColourComponent CCColourFormatHSPrecisionConversion(CCColourComponent Component, CCColourFormat OldType, CCColourFormat NewType, int NewPrecision)
{
    CCAssertLog((OldType & CCColourFormatModelMask) == CCColourFormatModelHS, "Must be a colour space within the HS model");
    
    if ((OldType == NewType) && (Component.type == NewPrecision)) return Component;
    
    return CCColourFormatLinearPrecisionConversion(Component, OldType, NewType, NewPrecision);
}

#pragma mark - Component Getters

static CCColourComponent CCColourFormatRGBGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision)
{
    CCColourComponent Component = CCColourFormatGetComponent(Colour, Index);
    if (Component.type)
    {
        Component = CCColourFormatRGBPrecisionConversion(Component, Colour.type, Type, Precision);
    }
    
    else if (Index == CCColourFormatChannelAlpha)
    {
        //default to opaque alpha
        Component = CCColourFormatRGBPrecisionConversion((CCColourComponent){ .type = CCColourFormatChannelAlpha  | (32 << CCColourFormatChannelBitSize), .f32 = 1.0f }, CCColourFormatTypeFloat | CCColourFormatNormalized, Type, Precision);
    }
    
    return Component;
}

static CCColourComponent CCColourFormatYUVGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision)
{
    CCColourComponent Component = CCColourFormatGetComponent(Colour, Index);
    if (Component.type)
    {
        Component = CCColourFormatYUVPrecisionConversion(Component, Colour.type, Type, Precision);
    }
    
    else if (Index == CCColourFormatChannelAlpha)
    {
        //default to opaque alpha
        Component = CCColourFormatRGBPrecisionConversion((CCColourComponent){ .type = CCColourFormatChannelAlpha  | (32 << CCColourFormatChannelBitSize), .f32 = 1.0f }, CCColourFormatTypeFloat | CCColourFormatNormalized, Type, Precision);
    }
    
    return Component;
}

static CCColourComponent CCColourFormatHSGetComponent(CCColour Colour, CCColourFormat Index, CCColourFormat Type, int Precision)
{
    CCColourComponent Component = CCColourFormatGetComponent(Colour, Index);
    if (Component.type)
    {
        Component = CCColourFormatHSPrecisionConversion(Component, Colour.type, Type, Precision);
    }
    
    else if (Index == CCColourFormatChannelAlpha)
    {
        //default to opaque alpha
        Component = CCColourFormatRGBPrecisionConversion((CCColourComponent){ .type = CCColourFormatChannelAlpha  | (32 << CCColourFormatChannelBitSize), .f32 = 1.0f }, CCColourFormatTypeFloat | CCColourFormatNormalized, Type, Precision);
    }
    
    return Component;
}

#pragma mark - Colour Conversions

static CCColour CCColourFormatHSConvertToRGB(CCColour Colour, CCColourFormat ColourSpace)
{
#define CC_COLOUR_CREATE_RGB_32F(r, g, b) (CCColour){ \
    .type = (CCColourFormatSpaceRGB_RGB | CCColourFormatTypeFloat \
        | ((CCColourFormatChannelRed    | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset0) \
        | ((CCColourFormatChannelGreen  | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset1) \
        | ((CCColourFormatChannelBlue   | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset2) \
        | (AlphaComponent << CCColourFormatChannelOffset3)) | CCColourFormatNormalized, \
    .channel = { \
        [0] = { .type = CCColourFormatChannelRed   | (32 << CCColourFormatChannelBitSize), .f32 = r }, \
        [1] = { .type = CCColourFormatChannelGreen | (32 << CCColourFormatChannelBitSize), .f32 = g }, \
        [2] = { .type = CCColourFormatChannelBlue  | (32 << CCColourFormatChannelBitSize), .f32 = b }, \
        [3] = { .type = CCColourFormatChannelAlpha | (32 << CCColourFormatChannelBitSize), .f32 = a.f32 } \
    } \
}

    CCAssertLog((Colour.type & CCColourFormatSpaceMask) == CCColourFormatSpaceHS_HSB, @"Must belong to the HSB space");
    
    CCColourComponent h = CCColourFormatHSGetComponent(Colour, CCColourFormatChannelHue, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent s = CCColourFormatHSGetComponent(Colour, CCColourFormatChannelSaturation, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent v = CCColourFormatHSGetComponent(Colour, CCColourFormatChannelValue, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent a = CCColourFormatHSGetComponent(Colour, CCColourFormatChannelAlpha, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    
    float C = 0.0f, m = 0.0f;
    switch (Colour.type & CCColourFormatSpaceMask)
    {
        case CCColourFormatSpaceHS_HSL:
            C = (1.0f - fabsf((2.0f * v.f32) - 1.0f)) * s.f32;
            m = v.f32 - (0.5f * C);
            break;
            
        case CCColourFormatSpaceHS_HSV:
            C = v.f32 * s.f32;
            m = v.f32 - C;
            break;
            
        case CCColourFormatSpaceHS_HSI:
            //TODO: add HSI
            break;
            
        case CCColourFormatSpaceHS_HSluma:
            //TODO: add luma
            break;
            
        default:
            return (CCColour){ .type = 0 };
    }
    
    const float H = h.f32 * 6.0f;
    const float X = H == 0.0f ? 0.0f : C * (1.0f - fabsf(fmodf(H, 2.0f) - 1.0f));
    
    const CCColourFormat AlphaComponent = CCColourFormatGetComponentChannelIndex(Colour, CCColourFormatChannelAlpha) == SIZE_MAX ? 0 : (CCColourFormatChannelAlpha     | (32 << CCColourFormatChannelBitSize));
    
    switch ((int)floorf(H))
    {
        case 0: return CC_COLOUR_CREATE_RGB_32F(C + m, X + m, 0.0f + m);
        case 1: return CC_COLOUR_CREATE_RGB_32F(X + m, C + m, 0.0f + m);
        case 2: return CC_COLOUR_CREATE_RGB_32F(0.0f + m, C + m, X + m);
        case 3: return CC_COLOUR_CREATE_RGB_32F(0.0f + m, X + m, C + m);
        case 4: return CC_COLOUR_CREATE_RGB_32F(X + m, 0.0f + m, C + m);
        case 5: return CC_COLOUR_CREATE_RGB_32F(C + m, 0.0f + m, X + m);
    }
    
    return (CCColour){ .type = 0 };
}

static CCColour CCColourFormatRGBConvertToHS(CCColour Colour, CCColourFormat ColourSpace)
{
    CCAssertLog((Colour.type & CCColourFormatSpaceMask) == CCColourFormatSpaceRGB_RGB, @"Must belong to the RGB space");
    
    CCColourComponent r = CCColourFormatRGBGetComponent(Colour, CCColourFormatChannelRed, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent g = CCColourFormatRGBGetComponent(Colour, CCColourFormatChannelGreen, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent b = CCColourFormatRGBGetComponent(Colour, CCColourFormatChannelBlue, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    CCColourComponent a = CCColourFormatRGBGetComponent(Colour, CCColourFormatChannelAlpha, CCColourFormatTypeFloat | CCColourFormatNormalized, 32);
    
    const float M = fmaxf(fmaxf(r.f32, g.f32), b.f32);
    const float m = fminf(fminf(r.f32, g.f32), b.f32);
    const float C = M - m;
    
    float H;
    if (C == 0.0f) H = 0.0f; //undefined
    else if (M == r.f32) H = fmodf((g.f32 - b.f32) / C, 6.0f);
    else if (M == g.f32) H = ((b.f32 - r.f32) / C) + 2.0f;
    else if (M == b.f32) H = ((r.f32 - g.f32) / C) + 4.0f;
    
    H /= 6.0f;
    
    float S = 0.0f, V = 0.0f;
    switch (ColourSpace & CCColourFormatSpaceMask)
    {
        case CCColourFormatSpaceHS_HSL:
            V = 0.5f * (M + m);
            S = ((V == 0.0f) || (V == 1.0f)) ? 0.0f : C / (1.0f - fabsf(2.0f * V - 1.0f));
            break;
            
        case CCColourFormatSpaceHS_HSV:
            V = M;
            S = V == 0.0f ? 0.0f : C / V; //though wiki says: V / C
            break;
            
        case CCColourFormatSpaceHS_HSI:
            V = (r.f32 + g.f32 + b.f32) / 3.0f;
            S = V == 0.0f ? 0.0f : 1.0f - (m / V);
            break;
            
        case CCColourFormatSpaceHS_HSluma:
            //TODO: add luma
            break;
            
        default:
            return (CCColour){ .type = 0 };
    }
    
    
    const CCColourFormat AlphaComponent = CCColourFormatGetComponentChannelIndex(Colour, CCColourFormatChannelAlpha) == SIZE_MAX ? 0 : (CCColourFormatChannelAlpha     | (32 << CCColourFormatChannelBitSize));
    
    return (CCColour){
        .type = (ColourSpace & CCColourFormatSpaceMask) | CCColourFormatTypeFloat | CCColourFormatNormalized
                | ((CCColourFormatChannelHue        | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset0)
                | ((CCColourFormatChannelSaturation | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset1)
                | ((CCColourFormatChannelIndex2     | (32 << CCColourFormatChannelBitSize)) << CCColourFormatChannelOffset2)
                | (AlphaComponent << CCColourFormatChannelOffset3),
        .channel = {
            [0] = { .type = CCColourFormatChannelHue        | (32 << CCColourFormatChannelBitSize), .f32 = H < 0.0f ? H + 1.0f : H },
            [1] = { .type = CCColourFormatChannelSaturation | (32 << CCColourFormatChannelBitSize), .f32 = S },
            [2] = { .type = CCColourFormatChannelValue      | (32 << CCColourFormatChannelBitSize), .f32 = V },
            [3] = { .type = CCColourFormatChannelAlpha      | (32 << CCColourFormatChannelBitSize), .f32 = a.f32 }
        }
    };
}

CCColour CCColourFormatConversion(CCColour Colour, CCColourFormat NewFormat)
{
    if (Colour.type == NewFormat) return Colour;
    
    static CCColour (* const Converters[CCColourFormatModelMask >> 2][CCColourFormatModelMask >> 2])(CCColour, CCColourFormat) = {
        [CCColourFormatModelRGB >> 2] = {
            [CCColourFormatModelHS >> 2] = CCColourFormatRGBConvertToHS
        },
        [CCColourFormatModelHS >> 2] = {
            [CCColourFormatModelRGB >> 2] = CCColourFormatHSConvertToRGB
        }
    };
    
    CCColour (* const Converter)(CCColour, CCColourFormat) = Converters[(Colour.type & CCColourFormatModelMask) >> 2][(NewFormat & CCColourFormatModelMask) >>  2];
    if (Converter) Colour = Converter(Colour, NewFormat);
    else if ((Colour.type & CCColourFormatModelMask) != (NewFormat & CCColourFormatModelMask)) return (CCColour){ .type = 0 };
    
    
    static const CCColourFormat Offsets[4] = {
        CCColourFormatChannelOffset0,
        CCColourFormatChannelOffset1,
        CCColourFormatChannelOffset2,
        CCColourFormatChannelOffset3
    };
    
    CCColour OldColour = Colour;
    for (int Loop = 0, Index = 0; Loop < 4; Loop++)
    {
        const CCColourFormat ChannelFormat = (NewFormat >> Offsets[Loop]) & CCColourFormatChannelMask;
        const CCColourFormat ChannelType = ChannelFormat & CCColourFormatChannelIndexMask;
        const int Precision = (ChannelFormat & CCColourFormatChannelBitSizeMask) >> CCColourFormatChannelBitSize;
        if (Precision)
        {
            Colour.channel[Index++] = CCColourFormatGetComponentWithPrecision(OldColour, ChannelType, NewFormat, Precision);
        }
    }
    
    Colour.type = NewFormat;
    
    return Colour;
}
