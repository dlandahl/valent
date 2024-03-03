
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Bit_Operations";
#import "Hash_Table";

#load "runtime_shared.jai";
#load "typecheck.jai";
#load "parse.jai";
// #load "simulation.jai";
#load "verilog_backend.jai";

#if OS == .WINDOWS {
    #import "Yosys";
    #load "rtlil_backend.jai";
}

Program :: struct {
    ast: *Ast_Block;
    files: Table(string, Tokenized_Source_File);
}

Source_File :: struct {
    name: string;
    code: string;
}

Tokenized_Source_File :: struct {
    using #as file: Source_File;

    tokens: [] Token;
    lines: [] string;
}

compile :: (files: .. Source_File) -> Program, bool {
    p: Program;
    context.typechecker.program = *p;

    top_level := Make_Ast(Ast_Block);
    top_level.block_type = .TOP_LEVEL;

    for files {
        context.parser.token_index = 0;

        tokenized := tokenize(it);

        table_add(*p.files, it.name, tokenized);

        parse(tokenized, top_level);

        if context.parser.error return .{}, false;
    }

    typecheck_block(top_level);

    p.ast = top_level;
    return p, true;
}

generate_verilog :: (program: Program, top: string) -> string, bool {
    for program.ast.statements {
        if it.kind != .DECLARATION continue;

        decl := cast(*Ast_Declaration) it;

        if decl.name == top {
            // build_wire_dag(decl);

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
