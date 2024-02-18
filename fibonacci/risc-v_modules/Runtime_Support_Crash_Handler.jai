// To Do:
// siginfo_t si_addr stuff
// redo all the changes that got destroyed somehow...!

// Since this code gets loaded for almost all programs, it's a bit more spare on
// formatting, comments and things that would make it slightly bigger in general.

// This started life as modules/Debug but was slimmed down for these purposes.

// To-do:
// @Incomplete: should be on the stack for threadsafety.
// Clean up all the sigaction_t stuff in POSIX.
// @Fixme: The crash handle does not work correctly on macOS atm.

#if OS == .WINDOWS {
    windows_context: CONTEXT  #align 32;  // @Incomplete: should be on the stack for threadsafety.
    symbols_initialized := false;
    CurrentProcess := cast(*void) -1;  // GetCurrentProcess on Windows just returns -1.

    DbgHelp  :: #system_library "DbgHelp";
    kernel32 :: #system_library "kernel32";

    // kernel32 etc are already imported by Runtime_Support; maybe we can economize.

    CONTEXT :: struct {
        total_size: [1232] u8 = ---;

        #place total_size;
        before_rax: [152] u8 = ---;
        Rsp: u64;
        Rbp: u64;
        other: [10] u64;

        Rip: u64;
    }

    ADDRESS64 :: struct {
        Offset: u64;
        Segment: u16;
        Mode: s32;
    }

    STACKFRAME64 :: struct {
        total_size: [264] u8;

        #place total_size;
        AddrPC:     ADDRESS64;
        AddrReturn: ADDRESS64;
        AddrFrame:  ADDRESS64;
        AddrStack:  ADDRESS64;
    }

    EXCEPTION_RECORD :: struct {
        ExceptionCode: u32;
        ExceptionFlags: u32;
        ExceptionRecord: *EXCEPTION_RECORD;
        ExceptionAddress: *void;
        NumberParameters: u32;
        ExceptionInformation: [15]u64;
    }

    EXCEPTION_POINTERS :: struct {
        ExceptionRecord: *EXCEPTION_RECORD;
        ContextRecord:   *CONTEXT;
    }


    // Be careful with signal handlers: http://www.nynaeve.net/?p=128

    init :: () {
        SetUnhandledExceptionFilter :: (lpTopLevelExceptionFilter: *void) -> *void #foreign kernel32;
        SetUnhandledExceptionFilter(xx handle_exception);

        // Maybe we don't want to call a bunch of functions after
        // a crash occurs, because maybe things are messed up.
        // So we call these things upfront.
        SymInitialize :: (hProcess: *void, UserSearchPath: *u8, fInvadeProcess: s32) -> s32 #foreign DbgHelp;
        SymSetOptions :: (SymOptions: u32) -> u32 #foreign DbgHelp;

        // SYMOPT_DEFERRED_LOADS make us not take a ton of time unless we actually log traces.
        SymSetOptions(0x216); // SYMOPT.DEFERRED_LOADS|.FAIL_CRITICAL_ERRORS|.LOAD_LINES|.UNDNAME;

        if !SymInitialize(CurrentProcess, null, xx true) {
            // Don't log anything; don't want to weigh this code down. We just silently won't handle exceptions.
            return;
        }

        symbols_initialized = true;
    }

    backtrace :: (ctx: *CONTEXT, skips: s32) #no_context {
        // Init the stack frame for this function
        stackFrame: STACKFRAME64;

        IMAGE_FILE_MACHINE :: enum u32 {
            I386  :: 0x014c;
            IA64  :: 0x0200;
            AMD64 :: 0x8664;
        }

        // @@ Assuming x64
        dwMachineType := IMAGE_FILE_MACHINE.AMD64;
        stackFrame.AddrPC   .Offset = ctx.Rip;
        stackFrame.AddrFrame.Offset = ctx.Rbp;
        stackFrame.AddrStack.Offset = ctx.Rsp;

        AddrModeFlat :: 3;

        stackFrame.AddrPC   .Mode = AddrModeFlat;
        stackFrame.AddrFrame.Mode = AddrModeFlat;
        stackFrame.AddrStack.Mode = AddrModeFlat;
        //stackFrame.AddrReturn.Offset = ctx.Rip;

        ReadProcessMemoryProc64 :: #type (hProcess: *void, lpBaseAddress: u64, lpBuffer: *void, nSize: u32, lpNumberOfBytesRead: *u32) -> s32 #c_call;
        FunctionTableAccessProc64 :: #type (hProcess: *void, AddrBase:u64) -> *void #c_call;
        GetModuleBaseProc64 :: #type (hProcess: *void, dwAddr:u64) -> u64 #c_call;
        TranslateAddressProc64 :: #type (hProcess: *void, hThread: *void, lpaddr: *ADDRESS64) -> u64 #c_call;

        // Annoying dbghelp stuff:
        StackWalk64 :: (MachineType: IMAGE_FILE_MACHINE, hProcess: *void, hThread: *void, StackFrame:*STACKFRAME64, ContextRecord: *void,
                        ReadMemoryRoutine: ReadProcessMemoryProc64, FunctionTableAccessRoutine: FunctionTableAccessProc64,
                        GetModuleBaseRoutine: GetModuleBaseProc64, TranslateAddress: TranslateAddressProc64) -> s32 #foreign DbgHelp;

        SymGetSymFromAddr64 :: (hProcess: *void, Address: u64, Displacement: *u64, Symbol: *void) -> s32 #foreign DbgHelp;
        SymFunctionTableAccess64 :: (hProcess: *void, AddrBase:u64) -> *void #foreign DbgHelp;
        SymGetModuleBase64 :: (hProcess: *void, dwAddr:u64) -> u64 #foreign DbgHelp;

        // Walk up the stack.
        GetCurrentThread :: () -> *void #foreign kernel32;
        hThread := GetCurrentThread();

        LIMIT :: 2047;  // If you exceed this many calls, you ain't going to get more trace.
        i := 0;
        while i < LIMIT {
            // walking once first makes us skip self
            if !StackWalk64(dwMachineType, CurrentProcess, hThread, *stackFrame, ctx, null, SymFunctionTableAccess64, SymGetModuleBase64, null) {
                break;
            }

            // For robustness, we should ensure that rsp continually increases?

            /*if (stackFrame.AddrPC.Offset == stackFrame.AddrReturn.Offset || stackFrame.AddrPC.Offset == 0) {
                break;
            }*/

            if (i > 0) && (i <= skips) {
                // Skip a bunch of stuff internal to the OS that is annoying.
                if i == 1  werr("... (skipping OS-internal procedures)\n");
                i += 1;
                continue;
            }

            MAX_NAME_LEN :: 512;
            MY_IMAGEHLP_SYMBOL64 :: struct {  // An extension of Windows' IMAGEHLP_SYMBOL64 to have MAX_NAME_LEN on the end.
                SizeOfStruct: u32;
                Address: u64;
                Size: u32;
                Flags: u32;
                MaxNameLength: u32;
                Name: [MAX_NAME_LEN] u8;
            }

            IMAGEHLP_LINE64 :: struct {
                SizeOfStruct: u32;
                Key: *void;
                LineNumber: u32;
                FileName: *u8;
                Address: u64;
            }

            // Get the function name.
            symbol: MY_IMAGEHLP_SYMBOL64;
            symbol.SizeOfStruct = 32;  // This is size_of(IMAGEHLP_SYMBOL64).
            symbol.MaxNameLength = MAX_NAME_LEN;

            func := "unknown";
            ip := stackFrame.AddrPC.Offset;
            symbol_displacement: u64;  // What are these for exactly? Can we just pass null instead?
            if SymGetSymFromAddr64(CurrentProcess, ip, *symbol_displacement, *symbol) {     // @@ Use SymFromAddr instead?
                func = to_string(symbol.Name.data);
            }


            // Get file and line number.
            theLine: IMAGEHLP_LINE64;
            theLine.SizeOfStruct = size_of(IMAGEHLP_LINE64);

            file := "unknown";
            line: int;
            SymGetLineFromAddr64 :: (hProcess: *void, dwAddr: u64, pdwDisplacement: *u32, Line: *IMAGEHLP_LINE64) -> s32 #foreign DbgHelp;
            line_displacement: u32;
            if SymGetLineFromAddr64(CurrentProcess, ip, *line_displacement, *theLine) {
                file = to_string(theLine.FileName);
                line = theLine.LineNumber;
            }

            werr(func);

            NAME_WIDTH :: 32;

            padding := NAME_WIDTH - func.count;
            for 1..padding werr(" ");

            // @Speed: Can optimize the outputting of spaces.
            werrs("  ", file, ":");
            write_nonnegative_number(cast,no_check(u64) line, to_standard_error = true);
            werr("\n");

            if func == "main" {  // @Incomplete: We really want to compare against the entry point, which may not be "main".
                break;
            }

            i += 1;
        }
    }

    // This is a macro because there are things that are on the stack that we use in the calling function (i.e. the section name)
    is_ptr_in_program_section :: (ptr: *void) -> in_program_section: bool, read_only: bool, section_name: string #expand
    {
        IMAGE_FILE_HEADER :: struct
        {
            Machine: u16;
            NumberOfSections: u16;
            TimeDateStamp: u32;
            PointerToSymbolTable: u32;
            NumberOfSymbols: u32;
            SizeOfOptionalHeader: u16;
            Characteristics: u16;
        }

        IMAGE_SECTION_HEADER :: struct
        {
            Name: [8]u8;
            Misc: union {
                PhysicalAddress: u32;
                VirtualSize: u32;
            };
            VirtualAddress: u32;
            SizeOfRawData: u32;
            PointerToRawData: u32;
            PointerToRelocations: u32;
            PointerToLinenumbers: u32;
            NumberOfRelocations: u16;
            NumberOfLinenumbers: u16;
            Characteristics: u32;
        }

        IMAGE_NT_HEADERS :: struct
        {
            Signature: u32;
            FileHeader: IMAGE_FILE_HEADER;
            // We only use this struct as a pointer, so we
            // can omit this member we don't use
            OptionalHeader: void;
        }

        IMAGE_FIRST_SECTION :: (header: *IMAGE_NT_HEADERS) -> *IMAGE_SECTION_HEADER #expand {
            result := cast (*void) *header.OptionalHeader + header.FileHeader.SizeOfOptionalHeader;

            return cast (*IMAGE_SECTION_HEADER) result;
        }

        GetModuleHandleW :: (lpModuleName: *u16) -> *void #foreign kernel32;
        ImageNtHeader :: (Base: *void) -> *IMAGE_NT_HEADERS #foreign DbgHelp;

        module := GetModuleHandleW (null);
        header := ImageNtHeader (module);

        sections: []IMAGE_SECTION_HEADER = ---;
        sections.count = header.FileHeader.NumberOfSections;
        sections.data = IMAGE_FIRST_SECTION (header);

        for sections {
            // GetModuleHandle returns the base address of where the module is loaded
            loaded_addr := module + it.VirtualAddress;
            if ptr > loaded_addr && ptr < loaded_addr + it.SizeOfRawData {
                return in_program_section = true,
                    read_only = (it.Characteristics & 0x40000000) && !(it.Characteristics & 0x80000000),
                    section_name = to_string (it.Name.data);
            }
        }

        return false, false, "";
    }

    handle_exception :: (using pExceptionInfo: *EXCEPTION_POINTERS) -> s32 #c_call {
        EXCEPTION_ACCESS_VIOLATION :: 3221225477;
        EXCEPTION_ARRAY_BOUNDS_EXCEEDED :: 3221225612;
        EXCEPTION_BREAKPOINT :: 2147483651;
        EXCEPTION_DATATYPE_MISALIGNMENT :: 2147483650;
        EXCEPTION_FLT_INVALID_OPERATION :: 3221225616;
        EXCEPTION_ILLEGAL_INSTRUCTION :: 3221225501;
        EXCEPTION_IN_PAGE_ERROR :: 3221225478;
        EXCEPTION_INT_DIVIDE_BY_ZERO :: 3221225620;
        EXCEPTION_PRIV_INSTRUCTION :: 3221225622;
        EXCEPTION_STACK_OVERFLOW :: 3221225725;
        // There are more exceptions that either cannot occur in our case or are simply not errors

        if ExceptionRecord.ExceptionCode == {
        // I'm trying to limit the amount of code we have here, so let's combine page fault and access violation
        case EXCEPTION_ACCESS_VIOLATION; #through;
        case EXCEPTION_IN_PAGE_ERROR;
            exception := ifx ExceptionRecord.ExceptionCode == EXCEPTION_ACCESS_VIOLATION then "an access violation" else "a page fault";
            action := ExceptionRecord.ExceptionInformation[0];
            ptr := ExceptionRecord.ExceptionInformation[1];

            if (!ptr) {
                werrs("The program crashed because it tried to ", ifx action "write to" else "read from", " a null pointer.\n");
//                werrs("The program crashed because it tried to ", ifx action == 0 {"read from";} else {"write to";}, " a null pointer.\n");
            } else {
                if (action == 0) || (action == 1) {
                    werrs("The program crashed because of ", exception, ifx action == 0 " reading location 0x" else " writing location 0x");
                } else {
                    werrs("The program crashed because of ", exception, ifx action == 8 " (user-mode data execution prevention)", " at location 0x");
                }

                write_nonnegative_number(ptr, base=16, to_standard_error = true);
                werr(".\n");

                in_program_section, read_only, section_name := is_ptr_in_program_section (cast (*void) ptr);

                if in_program_section {
                    werr("This address is in the ");
                    if read_only werr("read only ");
                    werrs("section ", section_name, " of the program.\n");

                    if read_only {
                        werr("A common mistake is to write to a constant string or array, which is put by the compiler in a read only section of the program.\n");
                    }
                }
            }

        case EXCEPTION_ARRAY_BOUNDS_EXCEEDED;
            werr("The program crashed because of a non user level array bounds check failure.\n");
        case EXCEPTION_BREAKPOINT;
            werr("A breakpoint was hit, but no debugger is attached.\n");
        case EXCEPTION_DATATYPE_MISALIGNMENT;
            // I don't think this can really happen on modern hardware, but let's handle it anyway
            werr("The program crashed because of a datatype misalignment.\n");
        case EXCEPTION_FLT_INVALID_OPERATION;
            werr("The program crashed because of a floating point exception.\n");
        case EXCEPTION_ILLEGAL_INSTRUCTION;
            werr("The program crashed because the thread tried to execute an invalid instruction.\n");
        case EXCEPTION_INT_DIVIDE_BY_ZERO;
            werr("The program crashed because of an integer division by zero error.\n");
        case EXCEPTION_PRIV_INSTRUCTION;
            werr("The program crashed because it tried to execute an unauthorized instruction.\n");
        case EXCEPTION_STACK_OVERFLOW;
            werr("The program crashed because of a stack overflow.\n");
        case;
            werr("The program crashed.\n");
        }

        // This condition is here to avoid printing both the user-level stack trace and OS provided stack trace
        // (i.e. assertion failures will print the stack trace, and trigger a breakpoint which we handle here)
        if !__runtime_support_disable_stack_trace {
            RtlCaptureContext :: (ContextRecord: *CONTEXT) #foreign kernel32;
            RtlCaptureContext(*windows_context);

            // In some cases of stack overflow (i.e. infinite recursion), printing the stack trace crashes the program
            if ExceptionRecord.ExceptionCode == EXCEPTION_STACK_OVERFLOW
                werr("\nPrinting the stack trace (this may fail when a stack overflow occurred):\n");
            else
                werr("\nPrinting the stack trace:\n");
            backtrace(*windows_context, 6);
        }

        // This should terminate the process and set the error exit code.
        TerminateProcess :: (hProcess: *void, uExitCode: u32) -> s32 #foreign kernel32;
        TerminateProcess(CurrentProcess, 1);  // We are not being picky about exit codes currently.

        EXCEPTION_EXECUTE_HANDLER :: 1;
        return EXCEPTION_EXECUTE_HANDLER;   // Terminate the program, in case TerminateProcess did not succeed.
    } @NoProfile
} else #if OS == .LINUX || OS == .MACOS {
    libc :: #system_library "libc";

    #if OS == .LINUX {
        SA_RESTART_ONSTACK_SIGINFO   :: 0x18000004;
        SIGBUS   ::  7;
        sigset_t :: struct { __val: [16] u64; }

        ucontext_t :: struct { // Not the correct size.
            uc_flags: u64;
            uc_link: *ucontext_t;
            ss_sp:   *void;  // stack_t
            ss_flags: s32;
            ss_size:  size_t;
            gregs: [23] s64;
        }
    } else #if OS == .MACOS {

        SA_RESTART_ONSTACK_SIGINFO   :: 0x0043;

        SIGBUS   :: 10; // Bus error.

        sigset_t :: u32;
        stack_t :: struct {
            ss_sp:   *void; // signal stack base
            ss_size:  u64;  // signal stack length
            ss_flags: s32;  // SA_DISABLE and/or SA_ONSTACK
        }

        // @ToDo: Auto-generate stubbed versions of these structs that contain only the fields necessary for the crash handler, but at the right offsets.
        x64_exception_state64_t_STUB :: [16] u8;
        x64_thread_state64_t_STUB :: struct {
            gregs: [21] s64;
        }
        x64_float_state64_t_STUB :: [524] u8;

        mcontext_t :: struct {
            __es: x64_exception_state64_t_STUB;
            __ss: x64_thread_state64_t_STUB;
            __fs: x64_float_state64_t_STUB;
            padding: [4] u8; // Make up for the fact that our stub for __fs has different aligment rules than the original.
        }

        ucontext_t :: struct {
            uc_onstack: s32;
            uc_sigmask: sigset_t;     // Signal mask used by this context.
            uc_stack: stack_t;        // Stack used by this context.
            uc_link: *ucontext_t;     // Pointer to resuming context.
            uc_mcsize: u64;           // Size of the machine context passed in.
            uc_mcontext: *mcontext_t; // Pointer to machine specific context.
        }
    }

    size_t   :: u64;

    libexecinfo :: libc;

    sigval_t :: union {
        sival_int: s32;
        sival_ptr: *void;
    }

    SIGQUIT   ::  3; // Quit.
    SIGILL    ::  4; // Illegal instruction (not reset when caught).
    SIGTRAP   ::  5; // Trace/breakpoint trap (not reset when caught).
    SIGABRT   ::  6; // Abnormal termination (abort()).
    SIGFPE    ::  8; // Erroneous arithmetic operation: floating point exception.
    SIGSEGV   :: 11; // Segmentation violation / invalid access to storage.
    clock_t   :: s64;
    sigaction_t :: struct {
        sa_sigaction: (sig: s32, info: *siginfo_t, p: *void) #c_call;
        sa_mask:  sigset_t; // Signal mask to apply.
        sa_flags: s32;     // See signal options below.

        #if OS == .LINUX then sa_restorer: () #c_call;
    }

    siginfo_t :: struct { // This is not the correct size, but we don't instantiate it, so it's fine.
        si_signo: s32;
        si_errno: s32;
        si_code: s32;
        __pad0: s32;
        si_addr: *void;
    }

    init :: () {
        // Install our signal handler.
        sa: sigaction_t;
        sa.sa_sigaction = handle_signal;

        sigemptyset :: (set: *sigset_t) -> s32 #foreign libc;
        sigemptyset (*sa.sa_mask);

        sa.sa_flags = SA_RESTART_ONSTACK_SIGINFO;

        sigaction :: (signum: s32, act: *sigaction_t, oldact: *void) -> s32 #foreign libc;
        sigaction(SIGSEGV, *sa, null);
        sigaction(SIGTRAP, *sa, null);
        sigaction(SIGFPE,  *sa, null);
        sigaction(SIGBUS,  *sa, null);
        sigaction(SIGILL,  *sa, null);
    }

    handle_signal :: (sig: s32, info: *siginfo_t, secret: *void) #c_call {
        if !__runtime_support_disable_stack_trace {
            caller_address :: (secret: *void) -> *void #no_context {
                // These only supports CPU_X86_64. See nvtt/src/nvcore/cpp for more platforms.
                #if OS == .MACOS {
                    ucp := cast(*ucontext_t)secret;
                    return xx ucp.uc_mcontext.__ss.gregs[16];
                } else #if OS == .LINUX {
                    ucp := cast(*ucontext_t)secret;
                    return xx ucp.gregs[16]; // RIP register.
                } else {
                    #assert false, "Unsupported platform for Runtime_Support_Crash_Handler, so it cannot be enabled.";
                }
            }

            if sig == SIGSEGV {
                // (Daniel) - August 4, 2023
                // Daniel: Documentation for SEGV_ACCERR
                // https://elixir.bootlin.com/linux/v5.15.8/source/include/uapi/asm-generic/siginfo.h#L231
                // https://www.man7.org/linux/man-pages/man2/sigaction.2.html

                // Linux & macOS:
                SEGV_MAPERR: s32 : 1; // attempt to access an address that doesn't map to anything
                SEGV_ACCERR: s32 : 2; // tried to access an address that you don't have permission to access

                // Linux only:
                SEGV_BNDERR: s32 : 3; // failed address bound checks
                SEGV_PKUERR: s32 : 4; // failed protection key checks

                if info.si_code == SEGV_MAPERR {
                    if info.si_addr == null {
                        werr("Program Exception: SEGV_MAPERR\nNull Pointer Exception. Attempt to dereference a null pointer.\n");
                    } else {
                        werr("Program Exception: SEGV_MAPERR\nThe program crashed because it tried to write to or read from an invalid memory location.\n");
                    }
                } else if info.si_code == SEGV_ACCERR {
                    // (Daniel) - August 4, 2023
                    // this catches "write to read only memory", but what about "read" from a memory location you do not have permission to read?
                    // ...or maybe it's handled in SEGV_MAPERR?
                    werr("Program Exception: SEGV_ACCERR\nThe program crashed because it tried to write to read only memory.\n");
                } else if info.si_code == SEGV_BNDERR {
                    werr("Program Exception: SEGV_BNDERR\nThe program crashed because there was a failed address bound check.\n");
                } else if info.si_code == SEGV_PKUERR {
                    werr("Program Exception: SEGV_PKUERR\nThe program crashed because there was a failed protection key check.\n");
                }

                pnt := caller_address(secret);
                werr("Segmentation fault. The faulty address is 0x");
                write_nonnegative_number(xx,no_check info.si_addr, base=16, to_standard_error = true);
                if pnt {
                    werr(", from 0x");
                    write_nonnegative_number(xx,no_check pnt, base=16, to_standard_error = true);
                }

                werr(".\n");

            } else if sig == SIGTRAP {
                werr("Breakpoint hit. Stack trace:\n");
            } else if sig == SIGFPE {
                #if OS == .MACOS {
                    FPE_FLTDIV: s32 : 1; // floating point divide by zero
                    FPE_FLTOVF: s32 : 2; // floating point overflow
                    FPE_FLTUND: s32 : 3; // floating point underflow
                    FPE_FLTRES: s32 : 4; // floating point inexact result
                    FPE_FLTINV: s32 : 5; // floating point invalid operation
                    FPE_FLTSUB: s32 : 6; // subscript out of range
                    FPE_INTDIV: s32 : 7; // integer divide by zero
                    FPE_INTOVF: s32 : 8; // integer overflow
                } else #if OS == .LINUX {
                    FPE_INTDIV: s32 : 1; // integer divide by zero
                    FPE_INTOVF: s32 : 2; // integer overflow
                    FPE_FLTDIV: s32 : 3; // floating point divide by zero
                    FPE_FLTOVF: s32 : 4; // floating point overflow
                    FPE_FLTUND: s32 : 5; // floating point underflow
                    FPE_FLTRES: s32 : 6; // floating point inexact result
                    FPE_FLTINV: s32 : 7; // floating point invalid operation
                    FPE_FLTSUB: s32 : 8; // subscript out of range
                }
                if info.si_code == {
                    case FPE_INTDIV;
                        werr("SIGFPE: The program crashed because of an integer division by zero error.\n");
                    case FPE_INTOVF;
                        werr("SIGFPE: The program crashed because of an integer arithmetic overflow error.\n");
                    case FPE_FLTDIV;
                        werr("SIGFPE: The program crashed because of a floating point division by zero error.\n");
                    case FPE_FLTOVF;
                        werr("SIGFPE: The program crashed because of a floating point overflow error.\n");
                    case FPE_FLTUND;
                        werr("SIGFPE: The program crashed because of a floating point underflow error.\n");
                    case FPE_FLTRES;
                        werr("SIGFPE: The program crashed because of an inexact floating point result error.\n");
                    case FPE_FLTINV;
                        werr("SIGFPE: The program crashed because of an invalid floating point result error.\n");
                    case FPE_FLTSUB;
                        werr("SIGFPE: The program crashed because of a subscript out of range error.\n");
                }
            } else if sig == SIGILL {
                #if OS == .MACOS {
                    ILL_ILLOPC: s32 : 1; // illegal opcode.
                    ILL_ILLTRP: s32 : 2; // illegal trap
                    ILL_PRVOPC: s32 : 3; // privileged opcode
                    ILL_ILLOPN: s32 : 4; // illegal operand
                    ILL_ILLADR: s32 : 5; // illegal addressing mode
                    ILL_PRVREG: s32 : 6; // privileged register
                    ILL_COPROC: s32 : 7; // coprocessor error
                    ILL_BADSTK: s32 : 8; // internal stack error
                } else #if OS == .LINUX {
                    ILL_ILLOPC: s32 : 1; //Illegal opcode.
                    ILL_ILLOPN: s32 : 2; // illegal operand
                    ILL_ILLADR: s32 : 3; // illegal addressing mode
                    ILL_ILLTRP: s32 : 4; // illegal trap
                    ILL_PRVOPC: s32 : 5; // privileged opcode
                    ILL_PRVREG: s32 : 6; // privileged register
                    ILL_COPROC: s32 : 7; // coprocessor error
                    ILL_BADSTK: s32 : 8; // internal stack error
                }

                if info.si_code == {
                    case ILL_ILLOPC;
                        werr("SIGILL: The program crashed because the thread tried to execute an illegal opcode.\n");
                    case ILL_ILLOPN;
                        werr("SIGILL: The program crashed because the thread tried to execute an invalid instruction.\n");
                    case ILL_ILLADR;
                        werr("SIGILL: The program crashed because of an illegal addressing mode.\n");
                    case ILL_ILLTRP;
                        werr("SIGILL: The program crashed because of an illegal trap.\n");
                    case ILL_PRVOPC;
                        werr("SIGILL: The program crashed because it tried to execute an unauthorized instruction.\n");
                    case ILL_PRVREG;
                        werr("SIGILL: The program crashed because it tried to use an unauthorized register.\n");
                    case ILL_COPROC;
                        werr("SIGILL: The program crashed because of a coprocessor error.\n");
                    case ILL_BADSTK;
                        werr("SIGILL: The program crashed because of an internal stack error.\n");
                }
            } else if info.si_code == SIGBUS {
                #if OS == .MACOS {
                    BUS_ADRALN: s32 : 1; // Invalid address alignment
                    BUS_ADRERR: s32 : 2; // Nonexistend physical address
                    BUS_OBJERR: s32 : 3; // Object-specific HW error
                } else #if OS == .LINUX {
                    BUS_ADRALN: s32 : 0; // Invalid address alignment
                    BUS_ADRERR: s32 : 1; // Nonexistend physical address
                    BUS_OBJERR: s32 : 2; // Object-specific HW error
                    BUS_MCEERR_AR: s32 : 3;
                    BUS_MCEERR_AO: s32 : 4;
                }
                if info.si_code == {
                    case BUS_ADRALN;
                        werr("SIGBUS: The program crashed because of an invalid address alignment.\n");
                    case BUS_ADRERR;
                        werr("SIGBUS: The program crashed because of a nonexistent physical address.\n");
                    case BUS_OBJERR;
                        werr("SIGBUS: The program crashed because of an object-specific hardware error.\n");
                }
                #if OS == .LINUX {
                    if info.si_code == {
                        case BUS_MCEERR_AR;
                            werr("SIGBUS: The program crashed because of a hardware memory error consumed on a machine check.\n");
                        case BUS_MCEERR_AO;
                            werr("SIGBUS: The program crashed because of a hardware memory error detected in process.\n");
                    }
                }
            } else {
                werr("Got signal ");
                write_nonnegative_number(xx,no_check sig, to_standard_error = true);
                werr(". Stack trace:\n");
            }

            // @Stability: Both backtrace() and backtrace_symbols() are not "async-signal-safe",
            // so calling them from a signal handler is unsafe and the behavior undefined. (Because they are malloc-ing, which is not allowed in a signal handler.)
            // We’re still doing it and hope for the best, since there seems to be no sensible alternative. :SignalHandlerBacktrace
            //  -rluba, 2022-11-02
            backtrace :: (array: **void, size: s32) -> s32 #foreign libexecinfo;
            backtrace_symbols :: (array: **void, size: s32) -> **u8 #foreign libexecinfo;

            LIMIT :: 2047;  // If you exceed this many calls, you ain't going to get more trace.
            trace: [LIMIT] *void;
            num_pointers_written := backtrace(trace.data, LIMIT);

            #if OS == .MACOS {
                TRACES_TO_SKIP :: 0; // Backtraces on macOS are still only semi-working, so we’re not skipping anything for now to avoid mudding the water.
            } else {
                TRACES_TO_SKIP :: 2; // Skip our crash handler and the glibc function that invokes it
            }

            if num_pointers_written > TRACES_TO_SKIP {
                symbols := backtrace_symbols(trace.data + TRACES_TO_SKIP, num_pointers_written - TRACES_TO_SKIP);
                // @Incomplete @Leak defer if symbols c_free(symbols);

                for 0..num_pointers_written - TRACES_TO_SKIP - 1 {
                    s := to_string(symbols[it]);
                    werrs(s, "\n");
                }
            }
        }

        // Terminate the process and set the error exit code.
        // We use _exit() instead of exit() because the latter is not safe to use from a signal handler and can cause the exit code to be incorrect!
        // (I observed exit code being 0 from time to time after calling exit() from C++, at least on macOS.)
        //  -rluba, 2023-02-08
        _exit :: (status: s32) #foreign libc;
        _exit(1);
    } @NoProfile
}


#scope_file

werr :: inline (s : string) #no_context { write_string (s, to_standard_error=true); };
werrs :: inline (s : ..string) #no_context { write_strings (..s, to_standard_error=true); };

