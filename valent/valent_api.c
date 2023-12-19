
#include "valent.h"

struct Vga_Format__Zones {
    vdl_constant_t video;
    vdl_constant_t front;
    vdl_constant_t sync;
    vdl_constant_t back;
};

struct Vga_Format {
    struct Vga_Format__Zones horizontal;
    struct Vga_Format__Zones vertical;
};

int main() {
    vdl_t workspace = vdl_create_workspace("My computer chip");

    const char *code = read_entire_file("syntax.my_hdl");

    vdl_add_source_code(workspace, code);
    vdl_compile(workspace);

    int timestep = 1; // ps

    vdl_sim_t *simulation = vdl_create_simulation(workspace, timestep);

    struct Vga_Format vga_format = {
        { 480, 11, 2,  31 },
        { 640, 16, 96, 48 }
    };

    vdl_instantiate_object(simulation, "Vga_Generator", "/vga_gen", &vga_format, vdl_lookup(my_circuit));
    vdl_object_t *clock = vdl_get_object(simulation, "/vga_gen/in.clk");

    for (int i = 0; i < 100000; i++) {
        vdl_step_simulation(simulation);

        if (i % 5000 == 0)
            vdl_logic_not(clock);
    }

    const char *verilog = vdl_generate_code(ast, VDL_CODE_VERILOG);
}
