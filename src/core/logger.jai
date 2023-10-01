#import "Basic";
#import "Thread";

Logger :: struct {
    log_mutex : Mutex;
    notif_cv : Condition_Variable;
    worker : Thread;
    closing := false;
    messages : [..]string;
}

logger_init :: () -> *Logger {
    logger := New(Logger);
    logger.worker.data = logger;
    thread_init(*logger.worker, logger_serialize); 
    init(*logger.notif_cv);
    init(*logger.log_mutex, "LogMutex", 1);
    thread_start(*logger.worker);
    return logger;
} 

logger_deinit :: (logger: *Logger) {
    defer thread_deinit(*logger.worker);
    lock(*logger.log_mutex);
    defer unlock(*logger.log_mutex);
    logger.closing = true;
    wake(*logger.notif_cv);
    destroy(*logger.log_mutex);
    destroy(*logger.notif_cv);
}

logger_serialize :: (thread : *Thread) -> s64 {
    logger := cast(*Logger)thread.data;
    while true {
        lock(*logger.log_mutex);
        defer unlock(*logger.log_mutex);
        wait(*logger.notif_cv, *logger.log_mutex); 
        for logger.messages {
            print("%", it);
        }
        array_reset(*logger.messages);
        if logger.closing{
            break;
        }
    }
    return 0;
}

log :: (logger: *Logger, message: string) {
    lock(*logger.log_mutex);
    defer unlock(*logger.log_mutex);
    array_add(*logger.messages, message);
    wake(*logger.notif_cv);
}

