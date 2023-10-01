#import "Basic";
#import "Thread";
#import "Pool";

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
