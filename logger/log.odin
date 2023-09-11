package logger

import "core:fmt"
import "core:os"


info :: proc(args: ..any, sep := " "){
    fmt.fprintln(os.stdout, ..args, sep=sep, flush=true)
}

debug :: proc(args: ..any, sep := " "){
    fmt.fprintln(os.stdout, ..args, sep=sep, flush=true)
}

trace :: proc(args: ..any, sep := " "){
    fmt.fprintln(os.stdout, ..args, sep=sep, flush=true)
}

warning :: proc(args: ..any, sep := " "){
    fmt.fprintln(os.stdout, ..args, sep=sep, flush=true)
}

error :: proc(args: ..any, sep := " "){
    fmt.eprintln(args, sep)
}

fatal :: proc(args: ..any, sep := " "){
    fmt.eprintln(args, sep)
}

