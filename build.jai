
#import "Basic";
#import "Compiler";
#import "File_Utilities";

#run {
    set_build_options_dc(.{do_output = false});

    release_modtime := file_modtime_and_size("yosys/x64/Release/yosys.dll");
    debug\ _modtime := file_modtime_and_size("yosys/x64/Debug/yosys.dll");

    dir := ifx release_modtime > debug_modtime then "Release" else "Debug";

    copy_file(tprint("yosys/x64/%/yosys.dll", dir), "modules/yosys.dll");
    copy_file(tprint("yosys/x64/%/yosys.lib", dir), "modules/yosys.lib");
    copy_file(tprint("yosys/x64/%/yosys.dll", dir), "yosys.dll");

    ws := compiler_create_workspace("cli");

    bo := get_build_options(ws);
    bo.output_executable_name = "valent";
    set_build_options(bo, ws);

    add_build_file("cli.jai", ws);
}
