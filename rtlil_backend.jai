
generate :: (top: *Ast_Declaration) -> string {
    rtlil_initialise_design();
    module := rtlil_create_module(top.name);

    chip := cast(*Ast_Chip) top.initialisation_value;

    port_index: s32 = 1;

    Add_Wire :: (decl: *Ast_Declaration, port_type: enum { INPUT, OUTPUT, NEITHER }) #expand {
        name := temp_c_string(decl.name);
        width := cast(s32) decl.datatype.bit_width;

        rtlil_add_wire(module, name, width, port_index, port_type == .INPUT, port_type == .OUTPUT);

        if port_type != .NEITHER {
            port_index += 1;
        }
    }

    for chip.inputs  Add_Wire(it, .INPUT);
    for chip.outputs Add_Wire(it, .OUTPUT);

    for chip.statements if it.kind == .DECLARATION {
        Add_Wire(cast(*Ast_Declaration) it, .NEITHER);
    }
}

yosys_test :: () {
    rtlil_initialise_design();
    module := rtlil_create_module("test");

    input_wire := rtlil_add_wire(module, "the_input", 3, 1, true, false);
    output_wire := rtlil_add_wire(module, "the_output", 3, 2, false, true);

    rtlil_connect_signals(
        module,
        rtlil_signal_from_wire(output_wire),
        rtlil_signal_from_wire(input_wire)
    );

    finish_module(module);
    rtlil_done();

    yosys_run_pass("write_edif test.edif");
}
