
#include <kernel/yosys.h>
#include <kernel/rtlil.h>

using namespace Yosys;

typedef void RTLIL_Module;
typedef void RTLIL_Process;
typedef void RTLIL_Signal;
typedef void RTLIL_Switch;
typedef void RTLIL_Case;

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

    __declspec(dllexport) RTLIL_Signal *rtlil_add_wire(RTLIL_Module *module, const char *name, int width, int port_id, bool input, bool output) {

        RTLIL::Module *_module = (RTLIL::Module *)module;
        RTLIL::Wire *wire = _module->addWire(name, width);

        wire->port_id = port_id;
        wire->port_input = input;
        wire->port_output = output;

        RTLIL::SigSpec* result = new RTLIL::SigSpec(wire);
        return (RTLIL_Signal*)result;
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_constant(int value, int width) {

        RTLIL::Const _const(value, width);
        RTLIL::SigSpec* result = new RTLIL::SigSpec(_const);
        return (RTLIL_Signal*)result;
    }

    __declspec(dllexport) void rtlil_connect(RTLIL_Module *module, RTLIL_Signal *left, RTLIL_Signal *right) {

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

    __declspec(dllexport) RTLIL_Process *rtlil_add_process(RTLIL_Module *module, const char *name, bool sequential, RTLIL_Signal *sync) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        RTLIL::Process *proc = _module->addProcess(name);
        RTLIL::SyncRule *syncrule = new RTLIL::SyncRule;

        syncrule->type = sequential ? RTLIL::STp : RTLIL::STa;

        if (sequential) {
            RTLIL::SigSpec _sync = *(RTLIL::SigSpec *)sync;
            syncrule->signal = _sync;
        }
        proc->syncs.push_back(syncrule);

        return (RTLIL_Process *)proc;
    }

    __declspec(dllexport) RTLIL_Signal *rtlil_signal_by_name(RTLIL_Module *module, const char *name) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        if (_module->wires_.find(name) == _module->wires_.end()) {
            return NULL;
        }

        Wire *wire = _module->wires_.at(name);

        RTLIL::SigSpec *result = new RTLIL::SigSpec(wire);
        return (RTLIL_Signal *)result;
    }

    __declspec(dllexport) void rtlil_switch_test(RTLIL_Module *module, RTLIL_Process *process, RTLIL_Signal *condition, RTLIL_Signal* counter) {
        RTLIL::Module *_module = (RTLIL::Module *)module;
        RTLIL::Process *_process = (RTLIL::Process *)process;

        RTLIL::SwitchRule *sw = new RTLIL::SwitchRule;
        sw->signal = *(RTLIL::SigSpec *)condition;
        _process->root_case.switches.push_back(sw);

        auto counter_next = rtlil_add_wire(module, "$counter_next", 5, 0, false, false);

        auto increment = rtlil_add_binary_cell(_module, "$add", counter, rtlil_constant(1, 5), 5, 0);
        auto decrement = rtlil_add_binary_cell(_module, "$sub", counter, rtlil_constant(1, 5), 5, 0);

        RTLIL::CaseRule *c1 = new RTLIL::CaseRule;
        c1->compare.push_back(RTLIL::Const(0, 1));
        c1->actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)counter_next, *(RTLIL::SigSpec *)increment));

        RTLIL::CaseRule *c2 = new RTLIL::CaseRule;
        c2->compare.push_back(RTLIL::Const(1, 1));
        c2->actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)counter_next, *(RTLIL::SigSpec *)decrement));

        sw->cases.push_back(c1);
        sw->cases.push_back(c2);

        _process->syncs.at(0)->actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)counter, *(RTLIL::SigSpec *)counter_next));
    }

    __declspec(dllexport) RTLIL_Switch *rtlil_add_switch(RTLIL_Process *process, RTLIL_Case *optional_parent, RTLIL_Signal *condition) {
        RTLIL::Process *_process = (RTLIL::Process *)process;

        RTLIL::SwitchRule *sw = new RTLIL::SwitchRule;
        sw->signal = *(RTLIL::SigSpec *)condition;

        if (optional_parent != NULL) {
            RTLIL::CaseRule *parent = (RTLIL::CaseRule *)optional_parent;
            parent->switches.push_back(sw);
        } else {
            _process->root_case.switches.push_back(sw);
        }

        return (RTLIL_Switch *)sw;
    }

    __declspec(dllexport) RTLIL_Case *rtlil_add_case(RTLIL_Switch *parent, RTLIL_Signal *comparison) {
        RTLIL::CaseRule *c = new RTLIL::CaseRule;
        RTLIL::SwitchRule *sw = (RTLIL::SwitchRule *)parent;

        sw->cases.push_back(c);
        c->compare.push_back(*(RTLIL::SigSpec *)comparison);

        return (RTLIL_Case *)c;
    }

    __declspec(dllexport) void rtlil_add_action(RTLIL_Case *parent, RTLIL_Signal *lhs, RTLIL_Signal *rhs) {
        RTLIL::CaseRule *c = (RTLIL::CaseRule *)parent;
        c->actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)lhs, *(RTLIL::SigSpec *)rhs));
    }

    __declspec(dllexport) void rtlil_add_root_action(RTLIL_Process *process, RTLIL_Signal *lhs, RTLIL_Signal *rhs) {
        RTLIL::Process *_process = (RTLIL::Process *)process;
        _process->root_case.actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)lhs, *(RTLIL::SigSpec *)rhs));
    }

    __declspec(dllexport) void rtlil_add_sync_action(RTLIL_Process *process, RTLIL_Signal *lhs, RTLIL_Signal *rhs) {
        RTLIL::Process *_process = (RTLIL::Process *)process;
        _process->syncs.at(0)->actions.push_back(RTLIL::SigSig(*(RTLIL::SigSpec *)lhs, *(RTLIL::SigSpec *)rhs));
    }
}
