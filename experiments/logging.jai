#import "Basic";
#import "SDL";
#import "Vulkan";
#import "Thread";
#import "System";
#load "../src/core/logger.jai";

t1_status := true;
t1_proc :: (thread : *Thread) -> s64 {
    counter := 0;
    while t1_status {
        log(.DEBUG, "Hello from THREAD %1 - %2", context.thread_index, counter);
        counter += 1;
    }
    return 0;
}

main :: () {
    logger_init(0);
    defer logger_deinit();
    t1 : Thread;
    t1.index = 1;
    thread_init(*t1, t1_proc);
    thread_start(*t1);
    defer thread_deinit(*t1);
    SDL_Init(SDL_INIT_VIDEO);

    // Create an application window with the following settings:
    window := SDL_CreateWindow("An SDL2 window",
        SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 640, 480,
        SDL_WINDOW_OPENGL|SDL_WINDOW_SHOWN);

    // Check that the window was successfully created
    if window == null {
        // In the case that the window could not be made...
        print("Could not create window: %\n", to_string(SDL_GetError()));
        return;
    }
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
        log(.DEBUG, "Hello % %", frame_count, frame_count);
    
        reset_temporary_storage();
    }

    // Close and destroy the window
    SDL_DestroyWindow(window);

    // Clean up
    SDL_Quit();
}
