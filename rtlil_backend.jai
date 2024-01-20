
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

                target := generate_expression(ass.target);
                source := generate_expression(ass.expr);

                rtlil_connect(context.rtlil.current_module, target, source);
            }
        }

        if it.kind == .SEQUENTIAL_CIRCUIT {
            seq := cast(*Ast_Sequential_Circuit) it;
            generate_process(seq);
        }
    }

    rtlil_finish_module(module);
    rtlil_done();

    yosys_run_pass("dump");
    yosys_run_pass("proc; opt; write_verilog");
}

generate_process :: (seq: *Ast_Sequential_Circuit) {
    using context.rtlil;

    sync_name := to_c_string(tprint("$%", seq.clock.name));
    sync := rtlil_signal_by_name(current_module, sync_name);
    process := rtlil_add_process(current_module, "$sequential", true, sync);

    generate_sequential_block(seq.block, process, null);
}

generate_sequential_block :: (block: *Ast_Block, process: *Rtlil_Process, parent: *Rtlil_Case) {
    using context.rtlil;

    for block.statements {
        if it.kind == .ASSIGNMENT {
            ass := cast(*Ast_Assignment) it;
            ident := cast(*Ast_Identifier) ass.target;

            wire_name := tprint("$%", ident.name);
            next_name := to_c_string(tprint("%_next", wire_name));

            next := rtlil_signal_by_name(current_module, next_name);
            target := rtlil_signal_by_name(current_module, to_c_string(wire_name));

            already_exists := next != null;

            if !already_exists {
                next = rtlil_add_wire(current_module, next_name, 1);
                rtlil_add_sync_action(process, target, next);
            }

            source := generate_expression(ass.expr);

            if !parent {
                rtlil_connect(current_module, next, source);
            } else {
                if !already_exists {
                    rtlil_add_root_action(process, next, target);
                }

                rtlil_add_action(parent, next, source);
            }
        }

        if it.kind == .IF {
            _if := cast(*Ast_If) it;

            comparison: Ast_Binary_Op;
            comparison.operation = .OPERATOR_GREATER_THAN;
            comparison.left = _if.condition;

            lit: Ast_Literal;
            lit.int_value = 0;
            lit.bit_width = 1;
            comparison.right = *lit;

            condition := generate_expression(*comparison);
            sw := rtlil_add_switch(process, parent, condition);
            c := rtlil_add_case(sw, rtlil_constant(1, 1));

            generate_sequential_block(_if.block, process, c);
            if _if.else_block != null {
                generate_sequential_block(_if.else_block, process, parent);
            }
        }
    }
}

generate_expression :: (expr: *Ast_Node) -> *Rtlil_Signal {
    using context.rtlil;

    if expr.kind == {
      case .LITERAL;
        lit := cast(*Ast_Literal) expr;
        width := ifx lit.bit_width == -1 then 32 else lit.bit_width;
        return rtlil_constant(xx lit.int_value, xx width);

      case .BIT_SELECT; return null; // Handled by BINARY_OP
      case .BINARY_OP;
        op := cast(*Ast_Binary_Op) expr;
        left := generate_expression(op.left);

        if op.operation == .OPEN_BRACKET {
            start, end: s32;

            if op.right.kind == .BIT_SELECT {
                bits := cast(*Ast_Bit_Select) op.right;
                start = xx evaluate_constant_expression(bits.left);
                end = xx evaluate_constant_expression(bits.right);
            } else {
                start = xx evaluate_constant_expression(op.right);
                end = -1;
            }

            return rtlil_bit_select(left, cast(s32) start, cast(s32) end);
        } else if op.operation == .OPERATOR_DOT {
            value := evaluate_constant_expression(op); // Todo this should be folded by this point
            return rtlil_constant(value, 32);
        } else {
            right := generate_expression(op.right);

            info := get_operator_info(op.operation);
            cell_type := to_c_string(info.rtlil_cell_type);

            width := max(op.left.datatype.bit_width, op.right.datatype.bit_width);
            if op.operation == .OPERATOR_ADD      width += 1;
            if op.operation == .OPERATOR_MULTIPLY width *= 2;

            result := rtlil_add_binary_cell(current_module, cell_type, left, right, width, op.location.line);
            return result;
        }

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        result := generate_expression(op.argument);
        // To do
        return result;

      case .IDENTIFIER;
        ident := cast(*Ast_Identifier) expr;
        return rtlil_signal_by_name(current_module, to_c_string(tprint("$%", ident.name)));

      case .CONCAT;
        cat := cast(*Ast_Concat) expr;

        signals: [..] *Rtlil_Signal;
        for cat.fields {
            field_signal := generate_expression(it);
            array_add(*signals, field_signal);
        }

        return rtlil_concatenate_signals(signals.data, cast(s32) signals.count);
    }

    assert(false);
    return null;
}
