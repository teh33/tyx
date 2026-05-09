package main

import "core:fmt"
import "core:os"

main :: proc() {
    args := os.args
    if len(args) < 2 {
        print_usage()
        os.exit(1)
    }

    cmd := args[1]
    switch cmd {
    case "init":
        path := "."
        if len(args) >= 3 do path = args[2]
        if !cmd_init(path) do os.exit(1)
    case "up":
        path := "."
        if len(args) >= 3 do path = args[2]
        if !cmd_up(path) do os.exit(1)
    case "down":
        path := "."
        if len(args) >= 3 do path = args[2]
        if !cmd_down(path) do os.exit(1)
    case "parse":
        path := "project.tyx"
        if len(args) >= 3 do path = args[2]
        if !cmd_parse(path) do os.exit(1)
    case "run":
        path := "."
        first_arg := 2
        if len(args) >= 4 && args[2] == "--path" {
            path = args[3]
            first_arg = 4
        }
        if len(args) <= first_arg {
            fmt.println("Fix\n  Usage: tyx run [--path <path>] <script|command> [args...]")
            os.exit(1)
        }
        if !cmd_run(path, args[first_arg:]) do os.exit(1)
    case:
        print_usage()
        os.exit(1)
    }
}
