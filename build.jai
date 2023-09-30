build :: (){
    make_directory_if_it_does_not_exist("bin");
    {
        w := compiler_create_workspace("Code Crimson");
        if !w {
            print("Workspace creation failed.\n");
            return;
        }
        options := get_build_options();
        set_optimization(*options, .DEBUG);
        options.output_path = "./bin/";
        options.output_executable_name = "code-crimson";
        set_build_options(options, w);
        add_build_file("./src/main.jai", w);
    }
    set_build_options_dc(.{do_output=false});
}

#run build();

#import "Basic";
#import "Compiler";
#import "File";
