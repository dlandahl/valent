
Code_Generator :: struct {
    verilog: struct {
        builder: String_Builder;
        indentation_level: int;
        last_write_ended_in_a_newline: bool;
    }
}

#add_context code_generator: Code_Generator;

generate_verilog :: (top: *Ast_Declaration) -> string {
    assert(top.initialisation_value.kind == .CHIP);

    init_string_builder(*context.code_generator.verilog.builder);

    generate_chip(top);

    code := builder_to_string(*context.code_generator.verilog.builder);
    print("%\n", code);

    return code;
}

generate_chip :: (decl: *Ast_Declaration) {
    write_verilog("module %(\n", decl.name);

    chip := cast(*Ast_Chip) decl.initialisation_value;

    for chip.inputs {
        write_verilog("    input %,\n", it.name);
    }

    for chip.outputs {
        write_verilog("    output % %\n", ifx it.datatype.primitive == .FLIPFLOP then "reg" else "", it.name);
        if it_index != chip.inputs.count-1 write_verilog(",");
    }

    write_verilog("  );\n");
    context.code_generator.verilog.indentation_level += 1;
    write_verilog("\n");

    for chip.statements {
        generate_statement(it);
    }

    context.code_generator.verilog.indentation_level -= 1;
    write_verilog("endmodule\n");
}

generate_statement :: (stmt: *Ast_Node) {
    if stmt.kind == {
      case .DECLARATION;

        decl := cast(*Ast_Declaration) stmt;

        t := decl.datatype;
        count: int;

        if t.kind == .ARRAY {
            count = t.element_count;
            t = << t.array_type;
        }

        if      t.primitive == .FLIPFLOP write_verilog("reg ");
        else if t.primitive == .WIRE     write_verilog("wire ");

        if count > 0 {
            write_verilog("[%] ", count);
        }

        write_verilog(decl.name);
        write_verilog(";\n\n");

      case .SEQUENTIAL_CIRCUIT;
        seq := cast(*Ast_Sequential_Circuit) stmt;
        write_verilog("always @ (posedge %) begin\n", seq.clock.name);

        context.code_generator.verilog.indentation_level += 1;

        for seq.block.statements {
            generate_statement(it);
        }

        context.code_generator.verilog.indentation_level -= 1;
        write_verilog("\nend\n");

      case .ASSIGNMENT;
        ass := cast(*Ast_Assignment) stmt;
        write_verilog(ass.target.name);
        write_verilog(ifx ass.type == .SEQUENTIAL " <= " else " = ");
        generate_expression(ass.expr);
        write_verilog(";\n");

      case .IF;
        _if := cast(*Ast_If) stmt;

        write_verilog("if (");
        generate_expression(_if.condition);
        write_verilog(") begin\n");

        context.code_generator.verilog.indentation_level += 1;

        for _if.block.statements {
            generate_statement(it);
        }

        context.code_generator.verilog.indentation_level -= 1;
        write_verilog("end\n");

    }
}

generate_expression :: (expr: *Ast_Node) {
    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        write_verilog("%", lit.int_value);

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        if op.operation == .LOGIC_NOT write_verilog("!");
        if op.operation == .BIT_NOT   write_verilog("~");

        generate_expression(op.argument);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        ops := string.["-", "+", "*", "/", "|", "<", ">", "==", "||"];

        generate_expression(op.left);
        write_verilog(" % ", ops[op.operation - ._BEGIN_OPERATORS - 1]);
        generate_expression(op.right);

      case .IDENTIFIER;
        id := cast(*Ast_Identifier) expr;
        write_verilog(id.name);
    }
}

write_verilog :: (code: string, format: .. Any, do_indent := true) {
    using context.code_generator;

    to_insert := tprint(code, .. format);
    lines := split(to_insert, "\n");
    // print("%\n", lines);

    spaces := "                                                                   ";

    if verilog.last_write_ended_in_a_newline {
        spaces.count = verilog.indentation_level * 4;
        print_to_builder(*verilog.builder, spaces);
    }

    for lines {
        print_to_builder(*verilog.builder, it);

        if it_index != 0 {
            print_to_builder(*verilog.builder, "\n");

            if !(it_index == lines.count-1 && lines[lines.count-1].count == 0) {
                spaces.count = verilog.indentation_level * 4;
                print_to_builder(*verilog.builder, spaces);
            }
        }
    }

    verilog.last_write_ended_in_a_newline = false;

    if lines.count {
        last := lines[lines.count-1];
        verilog.last_write_ended_in_a_newline = !last.count;
    }
}
