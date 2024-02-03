
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Bit_Operations";

#if OS == .WINDOWS {
    #import "Yosys";
    #load "rtlil_backend.jai";
}

#load "runtime_shared.jai";
#load "typecheck.jai";
#load "parse.jai";

#load "verilog_backend.jai";

Program :: struct {
    ast: *Ast_Block;
}

compile :: (code: string) -> Program, bool {
    p: Program;

    tokens := tokenize(code);
    ast := parse(tokens);

    if context.parser.error return .{}, false;

    typecheck_block(ast);

    p.ast = ast;
    return p, true;
}

generate_verilog :: (program: Program, top: string) -> string, bool {
    for program.ast.statements {
        if it.kind != .DECLARATION continue;

        decl := cast(*Ast_Declaration) it;

        if decl.name == top {
            result := generate_verilog(decl);
            return result, true;
        }
    }

    return "", false;
}

#if OS == .WINDOWS {
    create_rtlil_design :: (program: Program, top: string) -> bool {
        for program.ast.statements {
            if it.kind != .DECLARATION continue;

            decl := cast(*Ast_Declaration) it;

            if decl.name == top {
                result := generate_rtlil(decl);
                return true;
            }
        }

        return false;
    }

    run_yosys_command :: (command: *u8) {
        yosys_run_pass(command);
    }
}
