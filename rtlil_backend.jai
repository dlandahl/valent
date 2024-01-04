
#add_context rtlil: struct {
    current_module: *Rtlil_Module;
}

generate :: (top: *Ast_Declaration) {
    rtlil_initialise_design();
    module := rtlil_add_module(to_c_string(tprint("$%", top.name)));

    context.rtlil.current_module = module;

    chip := cast(*Ast_Chip) top.initialisation_value;

    port_index: s32 = 1;

    Add_Wire :: (decl: *Ast_Declaration, port_type: enum { INPUT; OUTPUT; NEITHER; }) #expand {
        name := to_c_string(tprint("$%", decl.name));
        width := cast(s32) decl.datatype.bit_width;

        rtlil_add_wire(module, name, width, port_index, port_type == .INPUT, port_type == .OUTPUT);

        if port_type != .NEITHER {
            port_index += 1;
        }
    }

    for chip.outputs Add_Wire(it, .OUTPUT);
    for chip.inputs  Add_Wire(it, .INPUT);

    for chip.statements if it.kind == .DECLARATION {
        decl := cast(*Ast_Declaration) it;

        if decl.datatype.primitive == .FLIPFLOP || decl.datatype.primitive == .WIRE {
            Add_Wire(decl, .NEITHER);
        }
    }

    for chip.statements {
        if it.kind == .COMBINATIONAL_CIRCUIT {
            comb := cast(*Ast_Combinational_Circuit) it;
            for comb.block.statements if it.kind == .ASSIGNMENT {
                ass := cast(*Ast_Assignment) it;
                ident := cast(*Ast_Identifier) ass.target;

                target := rtlil_signal_by_name(module, to_c_string(tprint("$%", ident.name)));
                source := generate_expression(ass.expr);

                rtlil_connect_signals(context.rtlil.current_module, target, source);
            }
        }
    }

    rtlil_finish_module(module);
    rtlil_done();

    yosys_run_pass("dump");
}

generate_expression :: (expr: *Ast_Node) -> *Rtlil_Signal {
    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        width := ifx lit.bit_width == -1 then 32 else lit.bit_width;
        return rtlil_signal_from_constant(xx lit.int_value, xx width);

      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        left := generate_expression(op.left);
        right := generate_expression(op.right);

        info := get_operator_info(op.operation);
        cell_type := to_c_string(info.rtlil_cell_type);

        width := max(op.left.datatype.bit_width, op.right.datatype.bit_width);
        if op.operation == .OPERATOR_ADD      width += 1;
        if op.operation == .OPERATOR_MULTIPLY width *= 2;

        result := rtlil_add_binary_cell(context.rtlil.current_module, cell_type, left, right, width, op.location.line);
        return result;

      case .IDENTIFIER;
        ident := cast(*Ast_Identifier) expr;
        return rtlil_signal_by_name(context.rtlil.current_module, to_c_string(tprint("$%", ident.name)));
    }

    assert(false);
    return null;
}
