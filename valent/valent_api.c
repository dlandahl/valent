
#include "valent.h"

struct Vga_Format__Zones {
    vlnt_constant_t video;
    vlnt_constant_t front;
    vlnt_constant_t sync;
    vlnt_constant_t back;
};

struct Vga_Format {
    struct Vga_Format__Zones horizontal;
    struct Vga_Format__Zones vertical;
};

int main() {
    vlnt_t workspace = vlnt_create_workspace("My computer chip");

    const char *code = read_entire_file("syntax.valent");

    vlnt_add_source_code(workspace, code);

    struct Vga_Format vga_format = {
        { 480, 11, 2,  31 },
        { 640, 16, 96, 48 }
    };

    vlnt_sim_options_t options;
    options.timestep_ps = 1;
    options.top = "Vga_Generator";
    options.top_params = { &vga_format };

    vlnt_sim_t *simulation = vlnt_create_simulation(workspace, options);

    const char *binary = read_entire_file("Image.bin");
    vlnt_load_memory(simulation, "bram_vmem.memory", binary);

    for (int i = 0; i < 10; i++) {
        vlnt_run_for_ns(simulation, 5);

        vlnt_set("in.clk", vlnt_op_bitnot(vlnt_get("in.clk"));
    }

    vlnt_compile_options_t options;
    options.top = "Vga_Generator";
    vlnt_compile(workspace);

    const char *verilog = vlnt_generate_code(workspace, VLNT_CODE_VERILOG);
    const char *rtlil = vlnt_generate_code(workspace, VLNT_CODE_RTLIL);
}
