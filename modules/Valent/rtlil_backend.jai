
#scope_module

#add_context rtlil: struct {
    current_module: *Rtlil_Module;
}

generate_rtlil :: (top: *Ast_Declaration) {
    rtlil_initialise_design();
    context.rtlil.current_module = rtlil_add_module(to_c_string(tprint("$%", top.name)));

    module := cast(*Ast_Module) top.expression;

    port_index: s32 = 1;

    Add_Wire :: (decl: *Ast_Declaration, port_type: enum { INPUT; OUTPUT; NEITHER; }) #expand {
        name := to_c_string(tprint("$%", decl.name));
        width := cast(s32) decl.datatype.bit_width;

        rtlil_add_wire(context.rtlil.current_module, name, width, port_index, port_type == .INPUT, port_type == .OUTPUT);

        if port_type != .NEITHER {
            port_index += 1;
        }
    }

    for module.outputs Add_Wire(it, .OUTPUT);
    for module.inputs  Add_Wire(it, .INPUT);

    for module.statements if it.kind == .DECLARATION {
        decl := cast(*Ast_Declaration) it;

        if decl.datatype.primitive == .FLIPFLOP || decl.datatype.primitive == .WIRE {
            Add_Wire(decl, .NEITHER);
        }
    }

    for module.statements {
        if it.kind == .COMBINATIONAL_CIRCUIT {
            comb := cast(*Ast_Combinational_Circuit) it;
            generate_process(comb.block);
        }

        if it.kind == .SEQUENTIAL_CIRCUIT {
            seq := cast(*Ast_Sequential_Circuit) it;

            sync_name := to_c_string(tprint("$%", seq.clock.name));
            sync := rtlil_signal_by_name(context.rtlil.current_module, sync_name);

            generate_process(seq.block, sync);
        }
    }

    rtlil_finish_module(context.rtlil.current_module);
    rtlil_done();

    yosys_run_pass("dump");
    // yosys_run_pass("proc; opt; write_verilog");
}

#scope_file

generate_process :: (block: *Ast_Block, sync: *Rtlil_Signal = null) {
    using context.rtlil;

    process := rtlil_add_process(current_module, "$the_process", sync != null, sync);
    generate_circuit_block(block, process, null);
}

generate_circuit_block :: (block: *Ast_Block, process: *Rtlil_Process, parent: *Rtlil_Case) {
    using context.rtlil;

    for block.statements {
        if it.kind == .ASSIGNMENT {
            ass := cast(*Ast_Assignment) it;

            source := generate_expression(ass.expr);
            target := generate_expression(ass.target);

            if block.block_type == .COMBINATIONAL {
                rtlil_add_action(parent, target, source);
                return;
            }

            ident := cast(*Ast_Identifier) ass.target;
            next_name := to_c_string(tprint("$%_next", ident.name));
            next := rtlil_signal_by_name(current_module, next_name);

            already_exists := next != null;

            if !already_exists {
                next = rtlil_add_wire(current_module, next_name, xx ass.target.datatype.bit_width);
                rtlil_add_sync_action(process, target, next);
            }

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

            generate_circuit_block(_if.block, process, c);
            if _if.else_block != null {
                generate_circuit_block(_if.else_block, process, parent);
            }
        }

        if it.kind == .SWITCH {
            switch := cast(*Ast_Switch) it;

            condition := generate_expression(switch.condition);
            sw := rtlil_add_switch(process, parent, condition);

            for switch.cases {
                print("Generating case %\n", node_location_string(it.compare));
                match := generate_expression(it.compare);
                c := rtlil_add_case(sw, match);
                generate_circuit_block(it.block, process, c);
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

            left := generate_expression(op.left);
            return rtlil_bit_select(left, cast(s32) start, cast(s32) end);

        } else if op.operation == .OPERATOR_REPEAT {
            count := evaluate_constant_expression(op.left);
            right := generate_expression(op.right);
            return rtlil_replicate_signal(right, cast(s32) count);

        } else if op.operation == .OPERATOR_DOT {
            if op.left.datatype.primitive == .ENUM {
                value := evaluate_constant_expression(op);
                return rtlil_constant(xx value, 32);

            } else if op.left.datatype.register_def {
                reg := op.left.datatype.register_def;
                ident := cast(*Ast_Identifier) op.right;

                // Both backends do this, maybe it can be moved to typechecking
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
                left := generate_expression(op.left);
                return rtlil_bit_select(left, xx field_start_bit, cast(s32) (field_start_bit + field.width));
            } else {
                assert(false);
            }

        } else {
            left := generate_expression(op.left);
            right := generate_expression(op.right);

            info := get_operator_info(op.operation);
            cell_type := to_c_string(info.rtlil_cell_type);

            result := rtlil_add_binary_cell(current_module, cell_type, left, right, op.datatype.bit_width, op.location.line);
            return result;
        }

      case .UNARY_OP;
        op := cast(*Ast_Unary_Op) expr;
        result := generate_expression(op.argument);
        // To do
        return result;

      case .IDENTIFIER;
        ident := cast(*Ast_Identifier) expr;

        if ident.declaration.constant {
            return rtlil_constant(xx evaluate_constant_expression(ident), 32);
        }

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
