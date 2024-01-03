
#include <kernel/yosys.h>
#include <kernel/rtlil.h>

using namespace Yosys;

typedef void RTLIL_Module;
typedef void RTLIL_Wire;
typedef void RTLIL_Process;
typedef void RTLIL_Signal;

extern "C" {
    __declspec(dllexport) void rtlil_initialise_design() {
        log_streams.push_back(&std::cout);
        log_error_stderr = true;

        yosys_setup();
    }

    __declspec(dllexport) void rtlil_done() {
        yosys_design->check();
    }

    __declspec(dllexport) void yosys_run_pass(const char *command) {
        run_pass(command);
    }

    __declspec(dllexport) RTLIL_Module *rtlil_add_module(const char *name) {

        RTLIL::Module *module = new RTLIL::Module;
        module->name = std::string(name);

        return module;
    }

    __declspec(dllexport) void rtlil_finish_module(RTLIL_Module *module) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        _module->fixup_ports();
        yosys_design->add(_module);
    }

    __declspec(dllexport) RTLIL_Wire *rtlil_add_wire(RTLIL_Module *module, const char *name, int width, int port_id, bool input, bool output) {

        RTLIL::Module *_module = (RTLIL::Module *)module;
        RTLIL::IdString id = std::string(name);
        RTLIL::Wire *wire = _module->addWire(id, width);

        wire->port_id = port_id;
        wire->port_input = input;
        wire->port_output = output;

        return wire;
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_signal_from_wire(RTLIL_Wire *wire) {

        RTLIL::Wire *_wire = (RTLIL::Wire *)wire;
        RTLIL::SigSpec* result = new RTLIL::SigSpec(_wire);
        return (RTLIL_Signal*)result;
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_signal_from_constant(int value, int width) {

        RTLIL::Const _const(value, width);
        RTLIL::SigSpec* result = new RTLIL::SigSpec(_const);
        return (RTLIL_Signal*)result;
    }

    __declspec(dllexport) void rtlil_connect_signals(RTLIL_Module *module, RTLIL_Signal *left, RTLIL_Signal *right) {

        RTLIL::Module *_module =  (RTLIL::Module *)module;
        RTLIL::SigSpec _right  = *(RTLIL::SigSpec *)right;
        RTLIL::SigSpec _left   = *(RTLIL::SigSpec *)left;

        _module->connect(RTLIL::SigSig(_left, _right));
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_add_binary_cell(RTLIL_Module *module, const char *type, RTLIL_Signal *left, RTLIL_Signal *right, int width, int line_number) {
        RTLIL::Module *_module = (RTLIL::Module *)module;

        IdString name = stringf("%s$%s:%d$%d", type, "_VALENT_", line_number, autoidx++);
        RTLIL::Cell* cell = _module->addCell(name, type);

        cell->parameters[ID::A_SIGNED] = RTLIL::Const(0);
        cell->parameters[ID::B_SIGNED] = RTLIL::Const(0);

        RTLIL::SigSpec _left = *(RTLIL::SigSpec *)left, _right = *(RTLIL::SigSpec *)right;
        cell->parameters[ID::A_WIDTH] = RTLIL::Const(_left.size());
        cell->parameters[ID::B_WIDTH] = RTLIL::Const(_right.size());

        cell->setPort(ID::A, _left);
        cell->setPort(ID::B, _right);

        cell->parameters[ID::Y_WIDTH] = width;
    
        RTLIL::Wire *wire = _module->addWire(cell->name.str() + "_Y", width);
        cell->setPort(ID::Y, wire);

        RTLIL::SigSpec *result = new RTLIL::SigSpec(wire);
        return (RTLIL_Signal *)result;
    }

    __declspec(dllexport) RTLIL_Process rtlil_add_process(RTLIL_Module *module, const char *name, bool sequential, RTLIL_Signal *sync) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        RTLIL::Process *proc = _module->addProcess(stringf("$proc$%s", name));
        RTLIL::SyncRule *syncrule = new RTLIL::SyncRule;

        syncrule->type = sequential ? RTLIL::STp : RTLIL::STa;

        RTLIL::SigSpec _sync = *(RTLIL::SigSpec *)sync;
        if (sequential) {
            syncrule->signal = _sync;
        }
        proc->syncs.push_back(syncrule);
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_signal_by_name(RTLIL_Module *module, const char *name) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        IdString id = std::string(name);
        Wire *wire = _module->wires_.at(id);

        RTLIL::SigSpec* result = new RTLIL::SigSpec(wire);
        return (RTLIL_Signal*)result;
    }
}
