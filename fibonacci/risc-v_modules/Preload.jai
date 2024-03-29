/*
    Minimal code the compiler needs to compile user source code. Volatile!

    This file should only contain things the compiler needs in order
    to successfully compile user-level code. (For example, things for which
    it needs pointers at various stages in the compilation process).

    This file cannot contain any varargs
    procedures, because those would need to use the type of Any, but they might
    compile before Any. We could make dependencies on Any every time there's a
    varargs, but that seems like an unnecessary complication that would
    incur a runtime performance penalty.

                             -- jblow, 15 May 2015.

    Addendum: We can't use type_info() here! Really it is best if there is no imperative code at all.

*/

Operating_System_Tag :: enum u32 {
    NONE      :: 0;
    KRAMPOS   :: 1;  // The Krampus Operating System.
    WINDOWS   :: 2;  // Any flavor of Microsoft Windows.
    LINUX     :: 3;  // Any flavor of Linux, except Android I guess.
    ANDROID   :: 4;
    IOS       :: 5;
    MACOS     :: 6;  // MacOsX, OS/X, macOS, or whatever they are calling it this year.
    NN_SWITCH :: 7;  // The Nintendo Switch.
    PS4       :: 8;
    PS5       :: 9;
    XBOX      :: 10; // Xbox One, Xbox Two, whatever. Like Windows but different.
    WASM      :: 11;
}

OS_IS_UNIX :: OS == .MACOS || OS == .LINUX || OS == .PS5 || OS == .IOS || OS == .ANDROID;

CPU_Tag :: enum u32 {
    UNINITIALIZED :: 0;
    KRAMPU        :: 1;  // The Krampus CPU.
    CUSTOM        :: 2;
    X64           :: 3;
    ARM64         :: 4;
}

Type_Info_Tag :: enum u32 {
    INTEGER              :: 0;
    FLOAT                :: 1;
    BOOL                 :: 2;
    STRING               :: 3;
    POINTER              :: 4;
    PROCEDURE            :: 5;
    VOID                 :: 6;
    STRUCT               :: 7;
    ARRAY                :: 8;
    OVERLOAD_SET         :: 9;
    ANY                  :: 10;
    ENUM                 :: 11;
    POLYMORPHIC_VARIABLE :: 12;
    TYPE                 :: 13;
    CODE                 :: 14;

//    UNARY_DEREFERENCE :: 15;
//    UNARY_LITERAL :: 16;
    VARIANT              :: 18;
}


// The Type_Infos all need to be here because when you say
// type_info(x), we downcast to the most specific Type_Info.
// This is useful. But requires more in the preload. Sigh!

Type_Info :: struct {
    type: Type_Info_Tag;
    runtime_size:    s64;  // WARNING: runtime_size may be unset for structs at compile-time if compilation is not finished. (It will be -1 in this case.) It can also be -1 if the type is polymorphic.
}

Type_Info_Integer :: struct {
    using #as info: Type_Info;
    signed: bool;
}

Type_Info_Float :: struct {
    using #as info: Type_Info;
}

// There is no Type_Info_Bool.

// Type_Info_String is currently useless; we may get rid of it eventually.
Type_Info_String :: struct {
    using #as info: Type_Info;
}

Type_Info_Pointer :: struct {
    using #as info: Type_Info;

    pointer_to: *Type_Info;
}

Type_Info_Procedure :: struct {
    using #as info: Type_Info;

    argument_types: [] *Type_Info;
    return_types:   [] *Type_Info;

    procedure_flags: Flags;

    Flags :: enum_flags u32 {
        IS_ELSEWHERE    :: 0x1;
        IS_COMPILE_TIME_ONLY :: 0x2;
        IS_POLYMORPHIC  :: 0x4;
        HAS_NO_CONTEXT  :: 0x8;
        IS_C_CALL       :: 0x20;
        IS_INTRINSIC    :: 0x80;
        IS_SYMMETRIC    :: 0x100;

        IS_CPP_METHOD   :: 0x1000_0000;
        HAS_CPP_NON_POD_RETURN_TYPE :: 0x2000_0000;
    }
}

// There is no Type_Info_Void.

Struct_Nontextual_Flags :: enum_flags u32 { // These are things not written by the user, but that get generated by the compiler.
    NOT_INSTANTIABLE          :: 0x4;
    ALL_MEMBERS_UNINITIALIZED :: 0x40;
    POLYMORPHIC               :: 0x100;
}

Struct_Textual_Flags :: enum u32 {
    FOREIGN                                :: 0x1;
    UNION                                  :: 0x2;
    NO_PADDING                             :: 0x4;
    TYPE_INFO_NONE                         :: 0x8;
    TYPE_INFO_NO_SIZE_COMPLAINT            :: 0x10;
    TYPE_INFO_PROCEDURES_ARE_VOID_POINTERS :: 0x20;
}

Struct_Status_Flags :: enum_flags u32 {
    INCOMPLETE :: 0x1;
    LOCAL      :: 0x4;
}

Type_Info_Struct :: struct {
    using #as info: Type_Info;

    name: string;

    specified_parameters: [] Type_Info_Struct_Member;
    members:              [] Type_Info_Struct_Member;

    status_flags:     Struct_Status_Flags;
    nontextual_flags: Struct_Nontextual_Flags;
    textual_flags:    Struct_Textual_Flags;

    polymorph_source_struct: *Type_Info_Struct;

    initializer: (*void);

    constant_storage: [] u8;
    notes: [] string;
}

Type_Info_Struct_Member :: struct {
    name: string;
    type: *Type_Info;
    offset_in_bytes: s64;

    flags: Flags;

    notes: [] string;

    offset_into_constant_storage: s64 = -1;  // -1 if this is not in constant storage; >=0 otherwise.

    Flags :: enum_flags u32 {
        CONSTANT                              :: 0x1;
        IMPORTED                              :: 0x2;
        USING                                 :: 0x4;
        PROCEDURE_WITH_VOID_POINTER_TYPE_INFO :: 0x8;
        AS                                    :: 0x10;
    }
}

Type_Info_Array :: struct {
    using #as info: Type_Info;

    element_type: *Type_Info;

    array_type:            Array_Type;
    // (hole)

    array_count:           s64;        // -1 unless this array is is of a known compile-time size, i.e. array_type is FIXED.

    Array_Type :: enum u16 {
        FIXED     :: 0;
        VIEW      :: 1;
        RESIZABLE :: 2;
    }
}

// There is no Type_Info_Any.

Enum_Status_Flags :: enum_flags u16 {
    INCOMPLETE :: 0x1;
}

Enum_Type_Flags :: enum_flags u16 {
    FLAGS     :: 0x1;  // This means it's declared as an enum_flags, not an enum. Confusing because we are in an enum that itself is called Flags, that has nothing to do with this.
    COMPLETE  :: 0x2;  // Enum is marked as #complete.
    SPECIFIED :: 0x4;  // Enum is marked as #specified.
}

Type_Info_Enum :: struct {
    using #as info: Type_Info;

    name: string;
    internal_type: *Type_Info_Integer;

    names:         [] string;
    values:        [] s64;

    status_flags:    Enum_Status_Flags;
    enum_type_flags: Enum_Type_Flags;
}

Type_Info_Variant_Flags :: enum_flags u32 {
    DISTINCT :: 0x1;
    ISA      :: 0x2;
}

Type_Info_Variant :: struct {
    using #as info: Type_Info;

    name:          string;
    variant_of:    *Type_Info;
    variant_flags: Type_Info_Variant_Flags;
}

// There is no Type_Info_Polymorphic_Variable.
// There is no Type_Info_Type.

Any_Struct :: struct {  // This is what an Any looks like.
    type: *Type_Info;
    value_pointer: *void;
}

__reg :: #type,distinct u16;

Workspace :: s64;

Allocator_Proc :: #type (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void;
Allocator :: struct {
    proc: Allocator_Proc;
    data: *void;
}

Allocator_Mode :: enum {  // @Volatile: If you change these, the bytecode has to change!
    ALLOCATE  :: 0;
    RESIZE    :: 1;
    FREE      :: 2;
    STARTUP   :: 3;  // The allocator has never been used and is being started up for the first time. The return value will be allocator_data for the first heap.
    SHUTDOWN  :: 4;  // The allocator is being shut down and should clean up everything. After this no allocator call is legal until a new STARTUP.
    THREAD_START  :: 5;
    THREAD_STOP   :: 6;
    CREATE_HEAP   :: 7;
    DESTROY_HEAP  :: 8;
    IS_THIS_YOURS :: 9;
    CAPS          :: 10;
}

Allocator_Caps :: enum_flags u32 {
    MULTIPLE_THREADS :: 0x1;
    CREATE_HEAP      :: 0x2;
    FREE             :: 0x4;
    ACTUALLY_RESIZE  :: 0x8;
    IS_THIS_YOURS    :: 0x10;

    HINT_I_AM_A_FAST_BUMP_ALLOCATOR       :: 0x0100_0000;
    HINT_I_AM_A_GENERAL_HEAP_ALLOCATOR    :: 0x0200_0000;
    HINT_I_AM_PER_FRAME_TEMPORARY_STORAGE :: 0x0400_0000;
    HINT_I_AM_A_DEBUG_ALLOCATOR           :: 0x0800_0000;
}

Logger    :: #type (message: string, data: *void, info: Log_Info);

Log_Info :: struct {
    source_identifier:   u64;            // Identifier of the module or program sending this log message. This is entirely optional. 0 means it's unset. If you set it, maybe you pick a unique ID or a hash to use for the module.
    location:     Source_Code_Location;  // The code that logged the message.
    common_flags: Log_Flags;             // Standard flags, with a commonly-understood meaning, that the logging entity may set or ignore.
    user_flags:   u32;                   // Any application-specific or module-specific flags you want to use.
    section:      *Log_Section;
}

Log_Level :: enum u8 {
    NORMAL       :: 0;
    VERBOSE      :: 1;
    VERY_VERBOSE :: 2;
}

Log_Flags :: enum_flags u32 {
    NONE              :: 0x0;
    ERROR             :: 0x1;
    WARNING           :: 0x2;
    CONTENT           :: 0x4;   // This notification is more likely relevant to content people than programmers.
    TO_FILE_ONLY      :: 0x8;   // Log this information to non-visible targets like log files, but don't display interactively.
    VERBOSE_ONLY      :: 0x10;  // This message is VERBOSE logging output. (e.g. it can be hidden by the user in an interactive log viewer that allows the user to select log levels).
    VERY_VERBOSE_ONLY :: 0x20;  // This message is VERY_VERBOSE logging output. (e.g. it can be hidden by the user in an interactive log viewer that allows the user to select log levels).
    TOPIC_ONLY        :: 0x40;  // This message should show up in topic panel only, not on other panels
}

Log_Section :: struct {
    name:       string;
}

Stack_Trace_Procedure_Info :: struct {
    name:      string;
    location:  Source_Code_Location;

    procedure_address: *void;

    // @Incomplete: We may wish to provide the procedure type here?
    // procedure_type:    *Type_Info_Procedure;
}

Stack_Trace_Node :: struct {  // @Volatile: Must match the layout built into the compiler.
    next:        *Stack_Trace_Node;
    info:        *Stack_Trace_Procedure_Info;
    hash:        u64;
    call_depth:  u32;
    line_number: u32;
}

__command_line_arguments: [] *u8;
__runtime_support_disable_stack_trace := false;  // If set to true, the exception handlers in Runtime_Support_* will not do anything; use this if you are doing a controlled exit that already reports what's going on, such as an assertion failure. You can then call abort() or whatever and not get a redundant stack trace.

Source_Code_Location :: struct {
    fully_pathed_filename:  string;
    line_number:            s64;
    character_number:       s64;
}

Source_Code_Range :: struct {
    fully_pathed_filename:  string;
    line_number_start:      s64;
    line_number_end:        s64;
    character_number_start: s64;
    character_number_end:   s64;
}

get_current_workspace :: () -> Workspace #compiler {
    // If calling this at runtime, we just return 0.
    // You might think we want to assert, but stuff
    // like thread_create calls this and doesn't think
    // about whether it's compile-time or not, and maybe
    // that is more convenient.

    return cast(Workspace) 0;
}

memcpy :: (dest: *void, source: *void, count: s64) #intrinsic;
memcmp :: (a: *void, b: *void, count: s64) -> s16  #intrinsic;  // @Incomplete: Do we want to tell people how many bytes in the first difference is?  // @Incomplete: The C spec for this routine sucks; we should probably return the actual byte difference. But the bytecode_runner version uses the C library version which just returns <=>0. I don't really want to inherit this ill-defined version. Unless we think it really doesn't matter. I dunno.
memset :: (dest: *void, value: u8, count: s64)     #intrinsic;

lock_cmpxchg :: (pointer: *$T, old: T, new: T) -> T #intrinsic; // @Incomplete: Only for types up to 8 bytes atm.

// For_Flags is used in for_expansions.
For_Flags :: enum_flags u8 {
    POINTER :: 0x1;
    REVERSE :: 0x2;
}

// Rather than declaring these structs here, we could have the compiler
// do its own hardcoded thing internally so it doesn't require these declarations.
// I dunno man!

Procedure_With_Data :: struct {
    proc      : *void;
    data      : *void;
}

Newstring    :: struct {
    count     : s64;  // Signed so that if we do for 0..count-1 it works...
    data      : *u8;
}

Array_View_64 :: struct {
    count     : s64;  // Signed so that if we do for 0..count-1 it works...
    data      : *u8;
}

// Resizable_Array is used by the compiler internally.
// Print in modules/Basic also uses this definition,
// because hey, while it's here, why not.
Resizable_Array :: struct {
    count      : s64;  // Signed so that if we do for 0..count-1 it works...
    data       : *void;
    allocated  : s64;

    allocator  : Allocator;  // This contains two pointers, .proc and .data, for a total of 16 bytes.
}

Name_Mapper :: #type ([] string);

