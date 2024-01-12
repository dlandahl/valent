
yosys :: #library "yosys";

Rtlil_Module  :: void;
Rtlil_Process :: void;
Rtlil_Signal  :: void;
Rtlil_Switch  :: void;
Rtlil_Case  :: void;

yosys_run_pass :: (command: *u8) #foreign yosys;

rtlil_initialise_design    :: () #foreign yosys;
rtlil_done                 :: () #foreign yosys;
rtlil_add_module           :: (name: *u8) -> *Rtlil_Module #foreign yosys;
rtlil_finish_module        :: (module: *Rtlil_Module) #foreign yosys;
rtlil_add_wire             :: (module: *Rtlil_Module, name: *u8, width: s32, port: s32 = 0, input := false, output := false) -> *Rtlil_Signal #foreign yosys;
rtlil_constant             :: (value: s32, width: s32) -> *Rtlil_Signal #foreign yosys;
rtlil_connect              :: (module: *Rtlil_Module, left: *Rtlil_Signal, right: *Rtlil_Signal) #foreign yosys;
rtlil_add_binary_cell      :: (module: *Rtlil_Module, type: *u8, left: *Rtlil_Signal, right: *Rtlil_Signal, width: int, line_number: int) -> *Rtlil_Signal #foreign yosys;
rtlil_add_process          :: (module: *Rtlil_Module, name: *u8, sequential: bool, sync_signal: *Rtlil_Signal) -> *Rtlil_Process #foreign yosys;
rtlil_signal_by_name       :: (module: *Rtlil_Module, name: *u8) -> *Rtlil_Signal #foreign yosys;
rtlil_switch_test          :: (module: *Rtlil_Module, process: *Rtlil_Process, condition: *Rtlil_Signal, counter: *Rtlil_Signal) #foreign yosys;
rtlil_add_switch           :: (process: *Rtlil_Process, optional_parent: *Rtlil_Case, condition: *Rtlil_Signal) -> *Rtlil_Switch #foreign yosys;
rtlil_add_case             :: (parent: *Rtlil_Switch, comparison: *Rtlil_Signal) -> *Rtlil_Case #foreign yosys;
rtlil_add_action           :: (parent: *Rtlil_Case, lhs: *Rtlil_Signal, rhs: *Rtlil_Signal) #foreign yosys;
rtlil_add_root_action      :: (process: *Rtlil_Process, lhs: *Rtlil_Signal, rhs: *Rtlil_Signal) #foreign yosys;
rtlil_add_sync_action      :: (process: *Rtlil_Process, lhs: *Rtlil_Signal, rhs: *Rtlil_Signal) #foreign yosys;
rtlil_concatenate_signals   :: (signals: **Rtlil_Signal, count: s32) -> *Rtlil_Signal #foreign yosys;
