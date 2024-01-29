
#import "Basic";
#import "String";
#import "File";
#import "File_Utilities";
#import "Bit_Operations";

#import "Yosys";

#load "runtime_shared.jai";
#load "typecheck.jai";
#load "parse.jai";

#load "verilog_backend.jai";
#load "rtlil_backend.jai";

Program :: struct {
    ast: *Ast_Block;
}

compile :: (code: string) -> Program {
    p: Program;

    tokens := tokenize(code);
    ast := parse(tokens);

    if context.parser.error return .{};

    typecheck_block(ast);

    p.ast = ast;
    return p;
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
