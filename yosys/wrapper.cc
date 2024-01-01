
#include <kernel/yosys.h>
#include <kernel/rtlil.h>

using namespace Yosys;

typedef void RTLIL_Module;
typedef void RTLIL_Wire;
typedef struct { uint8_t payload[sizeof(RTLIL::SigSpec)]; } RTLIL_Signal;

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

    __declspec(dllexport) RTLIL_Module *rtlil_create_module(const char *name) {

        RTLIL::Module *module = new RTLIL::Module;
        module->name = std::string(name);

        return module;
    }

    __declspec(dllexport) void finish_module(RTLIL_Module *module) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
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

    __declspec(dllexport) RTLIL_Signal rtlil_signal_from_wire(RTLIL_Wire *wire) {

        RTLIL::Wire *_wire = (RTLIL::Wire *)wire;
        RTLIL::SigSpec sig(_wire);
        return *(RTLIL_Signal *)&sig;
    }

    __declspec(dllexport) RTLIL_Signal rtlil_signal_from_constant(int value, int width) {

        RTLIL::Const _const(value, width);
        RTLIL::SigSpec sig(_const);
        return *(RTLIL_Signal *)&sig;
    }

    __declspec(dllexport) void rtlil_connect_signals(RTLIL_Module *module, RTLIL_Signal left, RTLIL_Signal right) {

        RTLIL::Module *_module =  (RTLIL::Module *)module;
        RTLIL::SigSpec _left   = *(RTLIL::SigSpec *)&left;
        RTLIL::SigSpec _right  = *(RTLIL::SigSpec *)&right;

        _module->connect(RTLIL::SigSig(_left, _right));
    }
}
