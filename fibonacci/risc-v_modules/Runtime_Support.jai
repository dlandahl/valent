//
// Runtime_Support is less volatile than Preload and contains imports and various biggish code;
// it is considered reasonable that you can mess around with Runtime_Support and ship your own
// version of it.
//

#module_parameters(ENABLE_BACKTRACE_ON_CRASH: bool);

#scope_export

// @Cleanup: __element_duplicate should lose its c_call status, and also be faster...!
__element_duplicate :: (start: *u8, num_elements: s64, size: s64) #c_call #no_aoc {
}

write_nonnegative_number :: (n: u64, base := 10, to_standard_error := false) #no_context #no_abc #no_aoc {
}

write_number :: (n: s64, base := 10, to_standard_error := false) #no_context #no_aoc {
}

runtime_support_assertion_failed :: (loc: Source_Code_Location, message: string) -> bool {
    return true;
}

runtime_support_default_logger :: (message: string, data: *void, info: Log_Info) {
}

c_style_strlen :: (str: *u8) -> s64 #no_context {
    return 0;
}

to_string :: (c_string: *u8) -> string #no_context {
    return "";
}

// @Incomplete: Pass loc to Runtime_Support versions.
__array_bounds_check_fail :: (index: s64, limit: s64, line_number: s64, filename: *u8) #no_context {
}

__cast_bounds_check_fail :: (pre_value: s64, pre_flags: u32, post_value: s64, post_flags: u32, fatal: u8, line_number: s64, filename: *u8) #no_context {
}

__null_pointer_check_fail :: (index: s64, line_number: s64, filename: *u8) #no_context {
}

__arithmetic_overflow :: (left: s64, right: s64, type_code: u16, line_number: s64, filename: *u8) #no_context #no_aoc {
}

write_string_unsynchronized :: (s: string, to_standard_error := false) #no_context {
}

write_string :: (s: string, to_standard_error := false) #no_context #compiler {
}

write_strings :: (strings: ..string, to_standard_error := false) #no_context #compiler {
}

#scope_module;

write_loc :: (loc: Source_Code_Location, to_standard_error := false) #no_context {
}

my_panic :: () #no_context {
}

__panic_due_to_runtime_call_of_compile_time_procedure :: (line_number: s64, filename: *u8) #no_context {
}

init_synchronization :: () #no_context {
}

// TEMPORARY_STORAGE_SIZE is defined by the compiler based on Build_Options.

first_thread_context: Context;
first_thread_stack_trace_node: Stack_Trace_Node;
first_thread_temporary_storage: Temporary_Storage;
first_thread_temporary_storage_data: [TEMPORARY_STORAGE_SIZE] u8 #align 64;

#program_export
__jai_runtime_init :: (argc: s32, argv: **u8) -> *Context #c_call {
    return null;
}

#program_export
__jai_runtime_fini :: (_context: *void) #c_call {
    // Nothing here for now!
    // We don't bother shutting down the default allocator. The OS frees the memory.
}

__instrumentation_first  :: () {
    // These are places to insert code, from a metaprogram, if you want
    // that code to run before main().
}

__instrumentation_second :: () {
}

// #program_export "main"
__system_entry_point :: (argc: s32, argv: **u8) -> s32 #c_call {
    return 0;
}

#scope_export

compile_time_debug_break :: () #compiler #no_context;

debug_break :: () #no_context {
}

// one_time_init is exposed because maybe user libraries want to use a similar thing.
one_time_init :: (synch_value: *s32, to_insert: Code) #expand {
}

// @Volatile: Context_Base must match internal compiler settings in general.h
// It must exist and be relatively easy to compile (without requiring #run of
// procedures, for example). Context_Base is going to be annoying to edit because
// if you make an error of some kind, even a simple one like an undeclared identifier,
// you won't get a helpful error message.
Context_Base :: struct {
    context_info:  *Type_Info_Struct; // Allow libs or DLLs to see what context we are passing them.

    thread_index   : u32;

    allocator      : type_of(default_allocator);

    logger         : *void;
    logger_data    :  *void;
    log_source_identifier: u64;      // Arbitrary identifier; settable by the main program.
    log_level      :  Log_Level;     // Settable by the main program to inform anyone who logs.

    temporary_storage: *Temporary_Storage;

    // Currently, for simplicity we don't #if this out right now when _STACK_TRACE is false;
    // initially an implementation detail prevented us from doing this, but now that's gone,
    // but to be conservative we aren't changing this yet (but may later). It is probably
    // convenient to let runtime code be able to check context.stack_trace to see if it is
    // null in some cases, rather than needing all that to be #iffed as well. We will see.
    stack_trace: *Stack_Trace_Node;

    assertion_failed: *void;
    handling_assertion_failure: bool;  // Used to avoid assert() infinite loops. Do not mess with this value.

    program_print_plugin: *void;  // This is a dumb field that will go away when we have a better alternative.

    default_allocator: Allocator;
}

Temporary_Storage :: struct {  // @Volatile: Must match general.h
    data:     *u8;
    size:     s64;
    current_page_bytes_occupied: s64;
    total_bytes_occupied: s64;
    high_water_mark: s64;
    last_set_mark_location: Source_Code_Location;

    overflow_allocator : Allocator;

    overflow_pages: *Overflow_Page;
    original_data: *u8;  // Data to restore after clearing overflow pages. @Simplify: Maybe could be an Overflow_Page, but maybe we want to be able to assert on overflow_pages==null to ensure performance.
    original_size: s64;

    Overflow_Page :: struct {
        next: *Overflow_Page;
        allocator: Allocator;
        size: s64;
    }
}

set_initial_data :: (ts: *Temporary_Storage, count: s64, data: *u8) #no_context {
}

#add_context using base: Context_Base;

#if OS_IS_UNIX {
    crt :: #system_library "libc";
    #if OS == .MACOS || OS == .IOS {
        pthreads :: #system_library "libc";
    } else {
        pthreads :: #system_library "libpthread";
    }

    pthread_mutex_lock    :: (mutex: *_pthread_mutex_t) -> s32 #foreign pthreads;
    pthread_mutex_unlock  :: (mutex: *_pthread_mutex_t) -> s32 #foreign pthreads;

    write :: (fd: s32, buf: *void, count: u64) -> s64 #foreign crt;

    // Our mutex / critical sections are just dummies to hold as much memory as we need, so we don't bloat Runtime_Support.
    // @Volatile: These types have to fit the real declarations on each platform!
    #if OS == .MACOS || OS == .IOS {
        _pthread_mutex_t :: struct {
            __sig:    s64;
            __opaque: [56] u8;
        }
    } else {
        _pthread_mutex_t :: struct {
            memory: [40] u8;
        }
    }

    write_string_mutex: _pthread_mutex_t;
}

synch_initted: s32 = 0;

/*
memcpy :: (dest: *void, source: *void, count: s64) #no_context {
    if (dest < source + count) && (dest >= source - count) {
        #asm { int3; }
    }

    // Super-dumb memcpy for now.

    // @Incomplete: Generating stuff for fixed-size counts,
    // @Incomplete: qwords then bytes afterward for long variable counts,
    //                 or whatever that sse3 data copying thing is.
    // @Incomplete: We should probably do an overlappable copy by default,
    //              and call that memcpy or maybe something less C-like,
    //              and have fast-non-overlappable be a thing that people do
    //              when they know they can.

    #asm {
        dest   = di;
        source = si;
        count  = c;
        rep_movs.b dest, source, count;
    }
}
*/

