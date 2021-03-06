#include "pyobjc.h"

#if PY_MAJOR_VERSION == 2
    /*
     * For python 2.x the PyStringObject* type is optionally proxied as a NSString object,
     * the same type in Python 3.x is PyBytesObject* and it is proxied as a NSData object.
     *
     * The contents of this file are therefore only needed for Python 2.x.
     */

@implementation OC_PythonString

+ (instancetype)stringWithPythonObject:(PyObject*)v
{
    OC_PythonString* res;

    res = [[OC_PythonString alloc] initWithPythonObject:v];
    [res autorelease];
    return res;
}

- (id)initWithPythonObject:(PyObject*)v
{
    self = [super init];
    if (unlikely(self == nil)) return nil;

    SET_FIELD_INCREF(value, v);
    return self;
}

-(PyObject*)__pyobjc_PythonObject__
{
    Py_INCREF(value);
    return value;
}

-(PyObject*)__pyobjc_PythonTransient__:(int*)cookie
{
    *cookie = 0;
    Py_INCREF(value);
    return value;
}

-(BOOL)supportsWeakPointers {
    return YES;
}

-(oneway void)release
{
    /* See comment in OC_PythonUnicode */
    if (unlikely(!Py_IsInitialized())) {
        [super release];
        return;
    }

    PyObjC_BEGIN_WITH_GIL
        [super release];
    PyObjC_END_WITH_GIL
}



-(void)dealloc
{
    if (unlikely(!Py_IsInitialized())) {
        [super dealloc];
        return;
    }

    PyObjC_BEGIN_WITH_GIL
        PyObjC_UnregisterObjCProxy(value, self);
        [realObject release];
        Py_XDECREF(value);
    PyObjC_END_WITH_GIL

    [super dealloc];
}

-(id)__realObject__
{
    static int supportsNoCopy = -1;
    if (supportsNoCopy == -1) {
        supportsNoCopy = (int)[NSString instancesRespondToSelector:@selector(initWithBytesNoCopy:length:encoding:freeWhenDone:)];
    }
    if (!realObject) {
#if defined(__LP64__) || MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_3
        /* This sucks big-time: +defaultCStringEncoding is not necessarily
         * related to the system encoding. The code below tries to
         * compensate...
         */
        NSStringEncoding encoding = [NSString defaultCStringEncoding];
        const char* pycoding = PyUnicode_GetDefaultEncoding();
        if (strcmp(pycoding, "ascii") == 0) {
            encoding = NSASCIIStringEncoding;
        } else if (strcmp(pycoding, "utf-8") == 0) {
            encoding = NSUTF8StringEncoding;
        } else if (strcmp(pycoding, "latin1") == 0) {
            encoding = NSISOLatin1StringEncoding;
        } else if (strcmp(pycoding, "macroman") == 0) {
            encoding = NSMacOSRomanStringEncoding;
        } else {
            /* A very non-standard system encoding, use
             * whatever Cocoa believes to be the encoding.
             */
        }


        realObject = [[NSString alloc]
            initWithBytesNoCopy:PyString_AS_STRING(value)
            length:(NSUInteger)PyString_GET_SIZE(value)
            encoding:encoding
            freeWhenDone:NO];

#else
        if (supportsNoCopy) {
            // Mac OS X 10.3+
            realObject = [[NSString alloc]
                initWithBytesNoCopy:PyString_AS_STRING(value)
                length:(NSUInteger)PyString_GET_SIZE(value)
                encoding:[NSString defaultCStringEncoding]
                freeWhenDone:NO];
        } else {
            // Mac OS X 10.2
            realObject = [[NSString alloc]
                initWithBytes:PyString_AS_STRING(value)
                length:(NSUInteger)PyString_GET_SIZE(value)
                encoding:[NSString defaultCStringEncoding]];
        }
#endif
    }
    return realObject;
}

-(NSUInteger)length
{
    return [((NSString *)[self __realObject__]) length];
}

-(unichar)characterAtIndex:(NSUInteger)anIndex
{
    return [((NSString *)[self __realObject__]) characterAtIndex:anIndex];
}

-(void)getCharacters:(unichar *)buffer range:(NSRange)aRange
{
    [((NSString *)[self __realObject__]) getCharacters:buffer range:aRange];
}


- (id)initWithCharactersNoCopy:(unichar *)characters
            length:(NSUInteger)length
          freeWhenDone:(BOOL)flag
{
    PyObjC_BEGIN_WITH_GIL
        int byteorder = 0;
        PyObject* v;
        /* Decode as a UTF-16 string in native byteorder */
        v = PyUnicode_DecodeUTF16(
            (const char*)characters,
            length * 2,
            NULL,
            &byteorder);
        if (v == NULL) {
            PyObjC_GIL_FORWARD_EXC();
        }

        value = PyUnicode_AsEncodedString(v, NULL, NULL);
        Py_DECREF(v);
        if (value == NULL) {
            PyObjC_GIL_FORWARD_EXC();
        }

        PyString_InternInPlace(&value);

    PyObjC_END_WITH_GIL;
    if (flag) {
        free(characters);
    }
    return self;
}

-(id)initWithBytes:(const void*)bytes length:(NSUInteger)length encoding:(NSStringEncoding)encoding
{
    NSString* tmpval = [[NSString alloc] initWithBytes:bytes length:length encoding:encoding];

    PyObjC_BEGIN_WITH_GIL
        value = PyString_FromString([tmpval UTF8String]);
        if (value == NULL) {
            PyObjC_GIL_FORWARD_EXC();
        }
        PyString_InternInPlace(&value);

    PyObjC_END_WITH_GIL

    [tmpval release];
    return self;
}




/*
 * Helper method for initWithCoder, needed to deal with
 * recursive objects (e.g. o.value = o)
 */
-(void)pyobjcSetValue:(NSObject*)other
{
    PyObjC_BEGIN_WITH_GIL
        PyObject* v = PyObjC_IdToPython(other);

        SET_FIELD(value, v);
    PyObjC_END_WITH_GIL
}

- (id)initWithCoder:(NSCoder*)coder
{
    int v;

    if ([coder allowsKeyedCoding]) {
        v = [coder decodeInt32ForKey:@"pytype"];
    } else {
        [coder decodeValueOfObjCType:@encode(int) at:&v];
    }
    if (v == 1) {
        [super initWithCoder:coder];
    } else if (v == 2) {

        if (PyObjC_Decoder != NULL) {
            PyObjC_BEGIN_WITH_GIL
                PyObject* cdr = PyObjC_IdToPython(coder);
                PyObject* setValue;
                PyObject* selfAsPython;
                PyObject* v2;

                if (cdr == NULL) {
                    PyObjC_GIL_FORWARD_EXC();
                }

                selfAsPython = PyObjCObject_New(self, 0, YES);
                setValue = PyObject_GetAttrString(selfAsPython, "pyobjcSetValue_");

                v2 = PyObject_CallFunction(PyObjC_Decoder, "OO", cdr, setValue);
                Py_DECREF(cdr);
                Py_DECREF(setValue);
                Py_DECREF(selfAsPython);

                if (v2 == NULL) {
                    PyObjC_GIL_FORWARD_EXC();
                }

                SET_FIELD(value, v2);

                self = PyObjC_FindOrRegisterObjCProxy(value, self);

            PyObjC_END_WITH_GIL

            return self;

        } else {
            [NSException raise:NSInvalidArgumentException
                        format:@"decoding Python objects is not supported"];
            return nil;

        }

    } else {
        [NSException raise:NSInvalidArgumentException
                    format:@"encoding Python string objects is not supported"];
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder*)coder
{
    if (PyString_CheckExact(value)) {
        if ([coder allowsKeyedCoding]) {
            [coder encodeInt32:1 forKey:@"pytype"];
        }
        [super encodeWithCoder:coder];
    } else {
        if ([coder allowsKeyedCoding]) {
            [coder encodeInt32:2 forKey:@"pytype"];
        } else {
            int v = 2;
            [coder encodeValueOfObjCType:@encode(int) at:&v];
        }

        PyObjC_encodeWithCoder(value, coder);
    }
}

-(NSObject*)replacementObjectForArchiver:(NSArchiver*)archiver
{
    (void)(archiver);
    return self;
}

-(NSObject*)replacementObjectForKeyedArchiver:(NSKeyedArchiver*)archiver
{
    (void)(archiver);
    return self;
}

-(NSObject*)replacementObjectForCoder:(NSCoder*)archiver
{
    (void)(archiver);
    return self;
}

-(NSObject*)replacementObjectForPortCoder:(NSPortCoder*)archiver
{
    (void)(archiver);
    return self;
}

-(Class)classForKeyedArchiver
{
    return [OC_PythonString class];
}

-(Class)classForCoder
{
    if (PyString_CheckExact(value)) {
        return [NSString class];

    } else {
        return [OC_PythonString class];
    }
}

/* Ensure that we can be unarchived as a generic string by pure ObjC
 * code.
 */
+(NSArray*)classFallbacksForKeyedArchiver
{
    return [NSArray arrayWithObject:@"NSString"];
}

@end /* implementation OC_PythonString */

#endif /* !Py3k */
