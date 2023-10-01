#import "Basic";
#import "Thread";

Logger :: struct {
    log_mutex : Mutex;
    notif_cv : Condition_Variable;
    worker : Thread;
    closing := false;
    sb : String_Builder;
}

logger_init :: (thread_index: s64) -> *Logger {
    logger := New(Logger);
    logger.worker.data = logger;
    logger.sb.allocator = temp;
    thread_init(*logger.worker, logger_serialize); 
    init(*logger.notif_cv);
    init(*logger.log_mutex, "LogMutex", 1);
    thread_start(*logger.worker);
    return logger;
} 

logger_deinit :: (logger: *Logger) {
    lock(*logger.log_mutex);
    logger.closing = true;
    wake(*logger.notif_cv);
    destroy(*logger.log_mutex);
    destroy(*logger.notif_cv);
    unlock(*logger.log_mutex);
    thread_deinit(*logger.worker);
    free(logger);
}

logger_serialize :: (thread : *Thread) -> s64 {
    logger := cast(*Logger)thread.data;
    while true {
        lock(*logger.log_mutex);
        defer unlock(*logger.log_mutex);
        wait(*logger.notif_cv, *logger.log_mutex); 
        // for logger.messages {
        //     print("%", it);
        // }
        // array_reset(*logger.messages);
        print("%", builder_to_string(*logger.sb, logger.sb.allocator));
        reset(*logger.sb);
        if logger.closing{
            reset_temporary_storage();
            break;
        }
        reset_temporary_storage();
    }
    return 0;
}

Severity :: enum u8{
    DEBUG;
    INFO;
    WARNING;
    ERROR;
    FATAL;
}

log :: (logger: *Logger,severity : Severity = .INFO, format_string: string, args: .. Any) {
    lock(*logger.log_mutex);
    defer unlock(*logger.log_mutex);
    // array_add(*logger.messages, message);
    if severity == {
        case .DEBUG; append(*logger.sb, "[DEBUG]: ");
        case .INFO; append(*logger.sb, "[INFO]: ");
        case .WARNING; append(*logger.sb, "[WARNING]: ");
        case .ERROR; append(*logger.sb, "[ERROR]: ");
        case .FATAL; append(*logger.sb, "[FATAL]: ");
    }
    print_to_builder(*logger.sb, format_string, ..args);
    append(*logger.sb, "\n");
    wake(*logger.notif_cv);
}

