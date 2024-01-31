
Valent :: #import "Valent";

#import "Compiler";
#import "Basic";
#import "File";
#import "String";
#import "Command_Line";

Arguments :: struct {
    source: string;  @"?Specify the path of a Valent source code file"
    top: string;     @"?The name of the top module"
    backend: string; @"?Choose \"verilog\" or \"yosys\", or leave unset to only run typechecking"
    output_format: string; @"?When using the yosys backend, you can specify \"verilog\", \"blif\" (default), edif, or \"rtlil\""
}

main :: () {
    success, args, is_set := parse_arguments(Arguments, Argument_Flags.FREE_ARGUMENTS_ALLOWED|.ALIGN_HELP);

    if !success return;

    if !is_set.source {
        log_error("Please provide a source code file using -source");
        return;
    }

    if is_set.backend ^ is_set.top {
        log_error("To generate code you must specify both a top module using -top and a backend using -backend");
        return;
    }

    code, found := read_entire_file(args.source);

    if !found {
        log_error("Could not find source file '%'", args.source);
        return;
    }

    program, compile_success := Valent.compile(code);

    if !compile_success return;

    if to_lower_copy_new(args.backend) == {
      case "verilog";
        verilog, found_top := Valent.generate_verilog(program, args.top);
        if !found_top {
            log_error("Could not find top module '%'\n", args.top);
            return;
        }

      case "yosys";
        found_top := Valent.create_rtlil_design(program, args.top);
        if !found_top {
            log_error("Could not find top module '%'\n", args.top);
            return;
        }

        Valent.run_yosys_command("proc; opt");
        if args.output_format == {
            case ""; #through;
            case "blif"; Valent.run_yosys_command("write_blif");
            case "edif"; Valent.run_yosys_command("write_edif");
            case "verilog"; Valent.run_yosys_command("write_verilog");
            case "rtlil"; Valent.run_yosys_command("dump");
            case;
            log_error("Specified output format is not valid: '%'", args.output_format);
            return;
        }

      case ""; // We already typechecked
      case; log_error("'%' is not a valid backend", args.backend);
    }
}
