
Code_Generator :: struct {
    verilog: struct {
        builder: String_Builder;
        indentation_level: int;
        last_write_ended_in_a_newline: bool;
    }
}

#add_context code_generator: Code_Generator;

generate :: (top: *Ast_Declaration) -> string {
    assert(top.initialisation_value.kind == .CHIP);

    init_string_builder(*context.code_generator.verilog.builder);

    write_verilog("\n");
    generate_chip(top);

    code := builder_to_string(*context.code_generator.verilog.builder);

    return code;
}

generate_chip :: (decl: *Ast_Declaration) {
    write_verilog("module %(\n", decl.name);

    chip := cast(*Ast_Chip) decl.initialisation_value;

    for chip.inputs {
        write_verilog("    input %", it.name);

        if it.datatype.bit_width > 1 {
            write_verilog("[%]", it.datatype.bit_width);
        }
        write_verilog(",\n");
    }

    for chip.outputs {
        write_verilog("    output %1%2", ifx it.datatype.primitive == .FLIPFLOP then "reg " else "", it.name);

        if it.datatype.bit_width > 1 {
            write_verilog("[%]", it.datatype.bit_width);
        }

        if it_index != chip.outputs.count-1 write_verilog(",");
        write_verilog("\n");
    }

    write_verilog("  );\n\n");

    context.code_generator.verilog.indentation_level += 1;
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

        if      t.primitive == .FLIPFLOP write_verilog("reg ");
        else if t.primitive == .WIRE     write_verilog("wire ");
        else if t.primitive == .ENUM     return;

        if t.bit_width > 1 {
            write_verilog("[%] ", t.bit_width);
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

      case .COMBINATIONAL_CIRCUIT;
        comb := cast(*Ast_Combinational_Circuit) stmt;
        write_verilog("always @* ");

        if comb.block.statements.count > 1 {
            write_verilog("begin\n");
        }

        context.code_generator.verilog.indentation_level += 1;
        for comb.block.statements {
            generate_statement(it);
        }
        context.code_generator.verilog.indentation_level -= 1;

        if comb.block.statements.count > 1 write_verilog("\nend");
        write_verilog("\n");

      case .ASSIGNMENT;
        ass := cast(*Ast_Assignment) stmt;

        generate_expression(ass.target);
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

        if _if.else_block {
            write_verilog("end else begin\n");

            context.code_generator.verilog.indentation_level += 1;
            for _if.else_block.statements {
                generate_statement(it);
            }
            context.code_generator.verilog.indentation_level -= 1;
        }

        write_verilog("end\n");

      case .SWITCH;
        switch := cast(*Ast_Switch) stmt;

        write_verilog("case (");
        generate_expression(switch.condition);
        write_verilog(")\n");

        context.code_generator.verilog.indentation_level += 1;
        for switch.cases {
            value := evaluate_constant_expression(it.compare);
            write_verilog("%: begin\n", value);

            context.code_generator.verilog.indentation_level += 1;
            for it.block.statements {
                generate_statement(it);
            }
            context.code_generator.verilog.indentation_level -= 1;

            write_verilog("end\n");
        }
        context.code_generator.verilog.indentation_level -= 1;

        write_verilog("endcase");
    }
}

generate_expression :: (expr: *Ast_Node) {
    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        if lit.bit_width != -1 {
            write_verilog("%'b%", lit.bit_width, formatInt(lit.int_value, base = 2));
        } else {
            write_verilog("%", lit.int_value);
        }

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        if op.operation == .LOGIC_NOT write_verilog("!");
        if op.operation == .BIT_NOT   write_verilog("~");

        generate_expression(op.argument);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;

        if op.operation == .OPEN_BRACKET {
            generate_expression(op.left);
            write_verilog("[");
            generate_expression(op.right);
            write_verilog("]");
        } else if op.operation == .OPERATOR_DOT {
            value := evaluate_constant_expression(op); // Todo this should be folded by this point
            write_verilog("%", value);
        } else {
            info := get_operator_info(op.operation);

            write_verilog("(");
            generate_expression(op.left);
            write_verilog(" % ", info.verilog_string);
            generate_expression(op.right);
            write_verilog(")");
        }

      case .IDENTIFIER;
        id := cast(*Ast_Identifier) expr;
        write_verilog(id.name);

      case .BIT_SELECT;
        sel := cast(*Ast_Bit_Select) expr;

        generate_expression(sel.left);
        write_verilog(":");
        generate_expression(sel.right);

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;
        write_verilog("{ ");
        for cat.fields {
            generate_expression(it);
            if it_index != cat.fields.count-1
                write_verilog(", ");
        }
        write_verilog(" }");

      case; assert(false);
    }
}

write_verilog :: (code: string, format: .. Any, do_indent := true) {
    using context.code_generator;

    to_insert := tprint(code, .. format);
    lines := split(to_insert, "\n");

    spaces := "                                                             ";

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
