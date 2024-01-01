
#include <kernel/yosys.h>
#include <kernel/rtlil.h>

extern "C" {
    __declspec(dllexport) void yosys_setup() {
        Yosys::log_streams.push_back(&std::cout);
        Yosys::log_error_stderr = true;

        Yosys::yosys_setup();
    }

    __declspec(dllexport) void yosys_banner() {
        Yosys::yosys_banner();
    }
}
