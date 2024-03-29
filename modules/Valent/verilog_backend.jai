
#scope_module

#add_context verilog: struct {
    builder: String_Builder;
    indentation_level: int;
    last_write_ended_in_a_newline: bool;
}

generate_verilog :: (top: *Ast_Declaration) -> string {
    assert(top.expression.kind == .MODULE);

    init_string_builder(*context.verilog.builder);

    write_verilog("\n");
    generate_module(top);

    code := builder_to_string(*context.verilog.builder);

    print("%\n", code);
    return code;
}

#scope_file

generate_module :: (decl: *Ast_Declaration) {
    write_verilog("module %(\n", decl.name);

    module := cast(*Ast_Module) decl.expression;

    for module.inputs {
        write_verilog("    input ");

        if it.datatype.bit_width > 1 {
            write_verilog("[%:0] ", it.datatype.bit_width-1);
        }
        write_verilog("%", it.name);
        if it_index != module.inputs.count-1 || module.outputs.count write_verilog(",");
        write_verilog("\n");
    }

    for module.outputs {
        write_verilog("    output reg ");

        if it.datatype.bit_width > 1 {
            write_verilog("[%:0] ", it.datatype.bit_width-1);
        }

        write_verilog("%", it.name);
        if it_index != module.outputs.count-1 write_verilog(",");
        write_verilog("\n");
    }

    write_verilog("  );\n");

    context.verilog.indentation_level += 1;
    write_verilog("integer i;\n\n");

    for module.statements {
        if it.kind != .DECLARATION continue;

        decl := cast(*Ast_Declaration) it;
        if decl.expression.datatype.primitive == .MODULE continue;

        generate_statement(it);
    }

    for module.statements {
        if it.kind != .DECLARATION continue;

        decl := cast(*Ast_Declaration) it;
        if decl.expression.datatype.primitive == .MODULE {
            instance := cast(*Ast_Ident_With_Parameters) decl.expression;

            source := cast(*Ast_Declaration) instance.ident.declaration;

            module := cast(*Ast_Module) source.expression;

            write_bus_width :: (bus: *Ast_Declaration) {
                if bus.datatype.bit_width > 1 write_verilog("[%:0] ", bus.datatype.bit_width-1);
            }

            for module.inputs {
                if it_index >= instance.parameters.count {
                    write_verilog("reg ");
                    write_bus_width(it);
                    write_verilog("%__%;\n", decl.name, it.name);
                }
            }

            for module.outputs {
                if module.inputs.count + it_index >= instance.parameters.count {
                    write_verilog("wire ");
                    write_bus_width(it);
                    write_verilog("%__%;\n", decl.name, it.name);
                }
            }

            write_verilog("% %(", instance.ident.name, decl.name);

            for instance.parameters {
                ident := cast(*Ast_Identifier) it;
                write_verilog(ident.name);
                if it_index != module.inputs.count-1 || module.outputs.count {
                    write_verilog(", ");
                }
            }

            for module.inputs {
                if it_index < instance.parameters.count continue;

                write_verilog("%__%", decl.name, it.name);
                if it_index != module.inputs.count-1 || module.outputs.count {
                    write_verilog(", ");
                }
            }

            for module.outputs {
                if it_index < module.inputs.count + instance.parameters.count continue;

                write_verilog("%__%", decl.name, it.name);
                if it_index != module.outputs.count-1 write_verilog(", ");
            }

            write_verilog(");\n\n");
        }
    }
    context.verilog.indentation_level -= 1;

    generate_block(module, true);

    write_verilog("endmodule\n");
}

generate_block :: (block: *Ast_Block, skip_decls: bool = false) {
    context.verilog.indentation_level += 1;

    last_was_block: bool;
    for block.statements {
        if it.kind == .DECLARATION && skip_decls continue;

        if it_index != 0 {
            if it.kind == .IF || it.kind == .SWITCH write_verilog("\n");
        }

        generate_statement(it);

        if it_index != block.statements.count-1 {
            if it.kind == .IF || it.kind == .SWITCH write_verilog("\n");
        }
    }
    context.verilog.indentation_level -= 1;
}

generate_statement :: (stmt: *Ast_Node) {
    if stmt.kind == {
      case .DECLARATION;
        decl := cast(*Ast_Declaration) stmt;

        t := decl.datatype;

        if      t.primitive == .FLIPFLOP write_verilog("reg ");
        else if t.primitive == .MEMORY   write_verilog("reg ");
        else if t.primitive == .WIRE     write_verilog("reg ");
        else if t.primitive == .ENUM     return;
        else if t.primitive == .CONSTANT return;
        else if t.primitive == .REGISTER return;

        if t.bit_width > 1 {
            write_verilog("[%:0] ", t.bit_width-1);
        }

        write_verilog(decl.name);

        if t.primitive == .MEMORY {
            write_verilog(" [0:%];\n", t.memory_depth-1);
            write_verilog("initial for (i=0; i<%; i=i+1) %[i]", t.memory_depth, decl.name);
        }
        write_verilog(" = 0;\n\n");

      case .SEQUENTIAL_CIRCUIT;
        seq := cast(*Ast_Sequential_Circuit) stmt;
        write_verilog("always @(posedge %) begin\n", seq.clock.name);

        generate_block(seq.block);

        write_verilog("\nend\n");

      case .COMBINATIONAL_CIRCUIT;
        comb := cast(*Ast_Combinational_Circuit) stmt;
        write_verilog("always @* ");

        if comb.block.statements.count > 1 {
            write_verilog("begin\n");
        }

        generate_block(comb.block);

        if comb.block.statements.count > 1 {
            write_verilog("\nend");
        }
        write_verilog("\n");

      case .ASSIGNMENT;
        ass := cast(*Ast_Assignment) stmt;

        // if ass.type == .COMBINATIONAL {
        //     write_verilog("assign ");
        // }

        generate_expression(ass.target);
        write_verilog(ifx ass.type == .SEQUENTIAL " <= " else " = ");
        generate_expression(ass.expr);
        write_verilog(";\n");

      case .IF;
        _if := cast(*Ast_If) stmt;

        write_verilog("if (");
        generate_expression(_if.condition);
        write_verilog(") begin\n");

        generate_block(_if.block);

        if _if.else_block {
            write_verilog("end else begin\n");

            generate_block(_if.else_block);
        }

        write_verilog("end\n");

      case .SWITCH;
        switch := cast(*Ast_Switch) stmt;

        write_verilog("case (");
        generate_expression(switch.condition);
        write_verilog(")\n");

        context.verilog.indentation_level += 1;
        for switch.cases {
            value := evaluate_constant_expression(it.compare);
            write_verilog("%: ", value);
            
            if it.block.statements.count > 1 write_verilog("begin\n");
            generate_block(it.block);
            if it.block.statements.count > 1 write_verilog("end\n");
        }

        if switch.default {
            write_verilog("default: ");
            if switch.default.statements.count > 1 write_verilog("begin\n");
            generate_block(switch.default);
            if switch.default.statements.count > 1 write_verilog("end\n");
        }

        context.verilog.indentation_level -= 1;

        write_verilog("endcase\n");

      case; assert(false);
    }
}

generate_expression :: (expr: *Ast_Node, bit_select_active := false) -> int {

    bit_select_base_offset: int = -1;

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
            offset := generate_expression(op.left, true);
            write_verilog("[");

            y := offset != -1;

            if op.right.kind == .BIT_SELECT {
                sel := cast(*Ast_Bit_Select) op.right;

                if y write_verilog("(");
                generate_expression(sel.left);
                if y write_verilog(" + %)", offset);

                if sel.select_type == {
                    case .RANGE; write_verilog(":");
                    case .POSITIVE_FIXED_WIDTH; write_verilog(" +: ");
                    case .NEGATIVE_FIXED_WIDTH; write_verilog(" -: ");
                }

                if y write_verilog("(");
                generate_expression(sel.right);
                if y write_verilog(" + %)", offset);
            } else {
                if y write_verilog("(");
                generate_expression(op.right);
                if y write_verilog(" + %)", offset);
            }

            write_verilog("]");

        } else if op.operation == .OPERATOR_DOT {
            if op.left.datatype.primitive == .ENUM {
                value := evaluate_constant_expression(op);
                write_verilog("%", value);
            } else if op.left.datatype.register_def {
                reg := op.left.datatype.register_def;
                ident := cast(*Ast_Identifier) op.right;

                field_start_bit: int;
                field: *Register_Def.Field;

                for *reg.fields {
                    if it.name == ident.name {
                        field = it;
                        break;
                    }

                    field_start_bit += it.width;
                }

                assert(field != null);
                generate_expression(op.left);

                if !bit_select_active {
                    write_verilog("[%:%]", field_start_bit + field.width - 1, field_start_bit);
                } else {
                    // If bit-select is active, that means that the parent expression in the AST is already doing this [x:y] index. Chaining them is not allowed in Verilog, so instead of generating the code here, we send information upwards that the first bit-select can use to make the correct expression.
                    bit_select_base_offset = field_start_bit;
                    // The width doesn't matter because it's overruled by whatever the parent bit-select does.
                }
            } else if op.left.datatype.primitive == .MODULE {
                assert(op.left.kind == .IDENTIFIER);
                assert(op.right.kind == .IDENTIFIER);

                mod := cast(*Ast_Identifier) op.left;
                port := cast(*Ast_Identifier) op.right;

                write_verilog("%__%", mod.name, port.name);
            } else {
                assert(false);
            }
        } else if op.operation == .OPERATOR_REPEAT {
            count := evaluate_constant_expression(op.left);
            write_verilog("{%{ ", count);
            generate_expression(op.right);
            write_verilog(" }}");
        } else if op.operation == .OPERATOR_WIDTH {
            width := evaluate_constant_expression(op.left);
            constant := evaluate_constant_expression(op.right);
            write_verilog("%'d%", width, constant);

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

        if id.declaration.constant {
            write_verilog("%", evaluate_constant_expression(id));
        } else {
            write_verilog(id.name);
        }

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

    return bit_select_base_offset;
}

write_verilog :: (code: string, format: .. Any, do_indent := true) {
    verilog := *context.verilog;

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
