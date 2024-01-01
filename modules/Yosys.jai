
yosys :: #library "yosys";

SIZEOF_RTLIL_SIGSPEC :: 56;

Rtlil_Module :: void;
Rtlil_Wire   :: void;
Rtlil_Signal :: struct { payload: [SIZEOF_RTLIL_SIGSPEC] u8; };

yosys_run_pass :: (command: *u8) #foreign yosys;

rtlil_initialise_design :: () #foreign yosys;
rtlil_done :: () #foreign yosys;
rtlil_create_module :: (name: *u8) -> *Rtlil_Module #foreign yosys;
finish_module :: (module: *Rtlil_Module) #foreign yosys;
rtlil_add_wire :: (module: *Rtlil_Module, name: *u8, width: s32, port: s32, input: bool, output: bool) -> *Rtlil_Wire #foreign yosys;
rtlil_signal_from_wire :: (wire: *Rtlil_Wire) -> Rtlil_Signal #foreign yosys;
rtlil_signal_from_constant :: (value: s32, width: s32) -> Rtlil_Signal #foreign yosys;
rtlil_connect_signals :: (module: *Rtlil_Module, left: Rtlil_Signal, right: Rtlil_Signal) #foreign yosys;
