#import "Basic";
#import "SDL";
#import "Vulkan";
#import "Thread";
#import "Pool";
#import "System";
#load "core/logger.jai";

create_window :: () -> *SDL_Window, bool {
    SDL_Init(SDL_INIT_VIDEO);

    // Create an application window with the following settings:
    window := SDL_CreateWindow("An SDL2 window",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480,
        SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);

    // Check that the window was successfully created
    if window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return null, false;
    }
    return window, true;
}

print_available_vulkan_extensions :: () {
    extension_count: u32;
    vkEnumerateInstanceExtensionProperties(null, *extension_count, null);
    extension_array := NewArray(extension_count, VkExtensionProperties);
    defer free(extension_array.data);
    vkEnumerateInstanceExtensionProperties(null, *extension_count, extension_array.data);
    print("Available extensions:\n");
    for extension_array print("    % (%)\n", to_string(it.extensionName.data), it.specVersion);
}

get_num_threads :: () -> u64 {
    num_cpus := get_number_of_processors();
    assert(num_cpus >= 1);
    #if (OS == .WINDOWS) || (OS == .LINUX){ // hyperthreads lmao
        num_cpus /= 2;
    }
    return cast(u64)num_cpus - 1;
}

THREAD_COUNT :: #run get_num_threads();
#run print("Thread count: %", THREAD_COUNT);
Message :: struct {
    body: string;
}

pool: Pool;
thread_group : Thread_Group;

thread_group_ex :: () {
    init(*thread_group, THREAD_COUNT,  print_proc);
    thread_group.name = "Logging";
    thread_group.logging = false;
    allocator: Allocator;
    allocator.proc = pool_allocator_proc;
    allocator.data = *pool;
    start(*thread_group);
    for 1..500 {
        work := New(Message, allocator=allocator);
        work.body = "Hello hai hello\n";
        add_work(*thread_group, work, tprint("Work item %", it));
    }
    work_remaining:=500;
    while(work_remaining > 0){
        results := get_completed_work(*thread_group);
        work_remaining -= results.count;
        if(work_remaining & 1){
            work := New(Message, allocator=allocator);
            work.body = "uuuuuuuuuuuuuuu\n";
            add_work(*thread_group, work);
        }
    }
    reset_temporary_storage();
    shutdown(*thread_group);
}

print_proc :: (group: *Thread_Group, thread: *Thread, work: *void) -> Thread_Continue_Status {
    message := cast(*Message)work;
    print("%", message.body);
    return .CONTINUE;
}

t1_status := true;
t1_proc :: (thread : *Thread) -> s64 {
    logger := cast(*Logger)thread.data;
    counter := 0;
    while t1_status {
        log(logger, .DEBUG, "Hello from THREAD %1 - %2", context.thread_index, counter);
        counter += 1;
    }
    return 0;
}

main :: () {
    logger := logger_init(0);
    defer logger_deinit(logger);
    t1 : Thread;
    t1.data = logger;
    t1.index = 1;
    thread_init(*t1, t1_proc);
    thread_start(*t1);
    defer thread_deinit(*t1);
    window, window_ok := create_window();
    if !window_ok return;
    print_available_vulkan_extensions();
    exit := false;
    frame_count := 0;
    while !exit {
        defer frame_count += 1;
        event : SDL_Event;
        while SDL_PollEvent(*event) {
            if event.type == {
                case SDL_QUIT;
                    exit = true;
                case SDL_KEYUP;
                    if event.key.keysym.sym == SDLK_ESCAPE {
                        exit = true;
                        t1_status = false;
                    }
            }
        }
        log(logger, .DEBUG, "Hello % %", frame_count, frame_count);
        SDL_Delay(1);
        reset_temporary_storage();
    }

    // Close and destroy the window
    SDL_DestroyWindow(window);

    // Clean up
    SDL_Quit();
}
