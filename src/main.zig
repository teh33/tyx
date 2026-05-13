const std = @import("std");
const types = @import("types.zig");
const Tool = types.Tool;
const ResolvedTool = types.ResolvedTool;
const render = @import("render.zig");
const output = @import("output.zig");
const parser = @import("parser.zig");
const repo_scan = @import("repo_scan.zig");
const runtime_mod = @import("runtime.zig");
const Runtime = runtime_mod.Runtime;

const ProjectConfig = types.ProjectConfig;
const FileCheck = types.FileCheck;
const DependencyCheck = types.DependencyCheck;

pub fn main(init: std.process.Init) !void {
    const rt: Runtime = .{ .io = init.io };
    const allocator = init.arena.allocator();
    const args_z = try init.minimal.args.toSlice(allocator);
    const args = @as([]const []const u8, args_z);
    if (args.len < 2) return usage(rt, 1);

    const ok = if (std.mem.eql(u8, args[1], "init"))
        try cmdInit(rt, allocator, if (args.len >= 3) args[2] else ".")
    else if (std.mem.eql(u8, args[1], "up"))
        try cmdUp(rt, allocator, if (args.len >= 3) args[2] else ".")
    else if (std.mem.eql(u8, args[1], "down"))
        try cmdDown(rt, allocator, if (args.len >= 3) args[2] else ".")
    else if (std.mem.eql(u8, args[1], "parse"))
        try cmdParse(rt, allocator, if (args.len >= 3) args[2] else "project.tyx")
    else if (std.mem.eql(u8, args[1], "run"))
        try dispatchRun(rt, allocator, args)
    else blk: {
        usage(rt, 1) catch {};
        break :blk false;
    };
    if (!ok) std.process.exit(1);
}

fn usage(rt: Runtime, code: u8) !void {
    try rt.print("Tyx spike\n\nUsage\n  tyx init [path]\n  tyx up [path]\n  tyx down [path]\n  tyx parse [project.tyx]\n  tyx run [--path <path>] <script|command> [args...]\n", .{});
    std.process.exit(code);
}

fn dispatchRun(rt: Runtime, allocator: std.mem.Allocator, args: []const []const u8) !bool {
    var path: []const u8 = ".";
    var first: usize = 2;
    if (args.len >= 4 and std.mem.eql(u8, args[2], "--path")) {
        path = args[3];
        first = 4;
    }
    if (args.len <= first) {
        try rt.print("Fix\n  Usage: tyx run [--path <path>] <script|command> [args...]\n", .{});
        return false;
    }
    return cmdRun(rt, allocator, path, args[first..]);
}

fn cmdInit(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !bool {
    const out_path = try runtime_mod.join(allocator, path, "project.tyx");
    defer allocator.free(out_path);
    if (rt.existsFile(out_path)) {
        try rt.print("Fix\n  project.tyx already exists\n\n  Remove it before running tyx init again.\n", .{});
        return false;
    }
    var info = try repo_scan.scanRepo(rt, allocator, path) orelse return false;
    defer info.deinit(allocator);
    const rendered = try render.renderProject(allocator, info);
    defer allocator.free(rendered);
    try rt.writeFile(out_path, rendered);
    try output.printInitSuccess(rt, allocator, info);
    return true;
}

fn cmdUp(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !bool {
    const project_path = try runtime_mod.join(allocator, path, "project.tyx");
    defer allocator.free(project_path);
    var cfg = try parser.loadProjectConfig(rt, allocator, project_path) orelse return false;
    defer cfg.deinit(allocator);
    var tools = try resolveTools(rt, allocator, cfg);
    defer tools.deinit(allocator);
    var compose = try checkFiles(rt, allocator, path, "compose", cfg.compose_files.items);
    defer compose.deinit(allocator);
    var env_checks = try checkEnvFiles(rt, allocator, path, cfg);
    defer env_checks.deinit(allocator);
    var deps = try checkDependencies(rt, allocator, path, cfg);
    defer deps.deinit(allocator);
    const install_ok = try installMissing(rt, path, deps.items);
    deps.deinit(allocator);
    deps = try checkDependencies(rt, allocator, path, cfg);
    const lock = try render.renderLock(allocator, cfg, tools.items, compose.items, env_checks.items, deps.items);
    defer allocator.free(lock);
    const lock_path = try runtime_mod.join(allocator, path, "tyx.lock");
    defer allocator.free(lock_path);
    try rt.writeFile(lock_path, lock);
    const compose_ok = composeRun(rt, allocator, path, compose.items, "up", true);
    try output.printUpSuccess(rt, allocator, cfg, tools.items, compose.items, env_checks.items, deps.items);
    return install_ok and compose_ok;
}

fn cmdDown(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !bool {
    const project_path = try runtime_mod.join(allocator, path, "project.tyx");
    defer allocator.free(project_path);
    var cfg = try parser.loadProjectConfig(rt, allocator, project_path) orelse return false;
    defer cfg.deinit(allocator);
    var compose = try checkFiles(rt, allocator, path, "compose", cfg.compose_files.items);
    defer compose.deinit(allocator);
    try output.printDownStart(rt, compose.items);
    return composeRun(rt, allocator, path, compose.items, "down", false);
}

fn cmdParse(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !bool {
    var cfg = try parser.loadProjectConfig(rt, allocator, path) orelse return false;
    defer cfg.deinit(allocator);
    try output.printParsedConfig(rt, cfg);
    return true;
}

fn cmdRun(rt: Runtime, allocator: std.mem.Allocator, path: []const u8, args: []const []const u8) !bool {
    var command = std.ArrayList([]const u8).empty;
    defer command.deinit(allocator);
    const project_path = try runtime_mod.join(allocator, path, "project.tyx");
    defer allocator.free(project_path);
    if (rt.existsFile(project_path)) {
        var cfg = try parser.loadProjectConfig(rt, allocator, project_path) orelse ProjectConfig{};
        defer cfg.deinit(allocator);
        if (try resolveScript(allocator, cfg, args[0])) |resolved| {
            command = resolved;
        }
    }
    if (command.items.len == 0) try command.appendSlice(allocator, args);
    return rt.runCommandWithFix(command.items, path);
}

fn resolveTools(rt: Runtime, allocator: std.mem.Allocator, cfg: ProjectConfig) !std.ArrayList(ResolvedTool) {
    var out = std.ArrayList(ResolvedTool).empty;
    for (cfg.tools.items) |tool| try out.append(allocator, try resolveTool(rt, allocator, tool));
    return out;
}

fn resolveTool(rt: Runtime, allocator: std.mem.Allocator, tool: Tool) !ResolvedTool {
    var result = ResolvedTool{ .name = tool.name, .requested = tool.version, .status = "missing" };
    var argv = [_][]const u8{ tool.name, "--version" };
    const r = rt.runCapture(allocator, &argv) catch return result;
    defer allocator.free(r);
    result.status = "present";
    result.version = try allocator.dupe(u8, firstLine(r));
    result.matches = versionMatches(tool.version, result.version);
    return result;
}

fn checkFiles(rt: Runtime, allocator: std.mem.Allocator, root: []const u8, kind: []const u8, paths: []const []const u8) !std.ArrayList(FileCheck) {
    var out = std.ArrayList(FileCheck).empty;
    for (paths) |p| {
        const full_path = try runtime_mod.join(allocator, root, p);
        const status = if (rt.existsFile(full_path)) "present" else "missing";
        try out.append(allocator, .{ .kind = kind, .path = p, .status = status });
    }
    return out;
}

fn checkEnvFiles(rt: Runtime, allocator: std.mem.Allocator, root: []const u8, cfg: ProjectConfig) !std.ArrayList(FileCheck) {
    var out = std.ArrayList(FileCheck).empty;
    for (cfg.env_examples.items) |p| {
        const full_path = try runtime_mod.join(allocator, root, p);
        const status = if (rt.existsFile(full_path)) "present" else "missing";
        try out.append(allocator, .{ .kind = "example", .path = p, .status = status });
    }
    for (cfg.env_files.items) |p| {
        const full_path = try runtime_mod.join(allocator, root, p);
        const status = if (rt.existsFile(full_path)) "present" else "missing";
        try out.append(allocator, .{ .kind = "file", .path = p, .status = status });
    }
    return out;
}

fn checkDependencies(rt: Runtime, allocator: std.mem.Allocator, root: []const u8, cfg: ProjectConfig) !std.ArrayList(DependencyCheck) {
    var out = std.ArrayList(DependencyCheck).empty;
    for (cfg.script_groups.items) |group| if (isNodeRunner(group.runner)) {
        const package_json_path = try runtime_mod.join(allocator, root, "package.json");
        const node_modules_path = try runtime_mod.join(allocator, root, "node_modules");
        const present = rt.existsFile(package_json_path) and rt.existsDir(node_modules_path);
        try out.append(allocator, .{ .runner = group.runner, .manifest = "package.json", .path = "node_modules", .status = if (present) "present" else "missing" });
    };
    return out;
}

fn installMissing(rt: Runtime, path: []const u8, deps: []const DependencyCheck) !bool {
    var ok = true;
    for (deps) |dep| if (std.mem.eql(u8, dep.status, "missing")) {
        try rt.print("\nInstalling\n  → {s} install\n", .{dep.runner});
        var argv = [_][]const u8{ dep.runner, "install" };
        if (!rt.runCommand(&argv, path)) ok = false;
    };
    return ok;
}

fn composeRun(rt: Runtime, allocator: std.mem.Allocator, root: []const u8, compose: []const FileCheck, action: []const u8, detached: bool) bool {
    var present_count: usize = 0;
    for (compose) |c| {
        if (std.mem.eql(u8, c.status, "present")) present_count += 1;
    }
    if (present_count == 0) return true;

    var argv = std.ArrayList([]const u8).empty;
    defer argv.deinit(allocator);
    argv.append(allocator, "docker") catch return false;
    argv.append(allocator, "compose") catch return false;
    for (compose) |c| if (std.mem.eql(u8, c.status, "present")) {
        argv.append(allocator, "-f") catch return false;
        argv.append(allocator, c.path) catch return false;
    };
    argv.append(allocator, action) catch return false;
    if (detached) argv.append(allocator, "-d") catch return false;

    if (std.mem.eql(u8, action, "up")) {
        rt.print("\nStarting\n  → docker compose up -d\n", .{}) catch {};
    } else {
        rt.print("Stopping\n  → docker compose down\n", .{}) catch {};
    }
    if (!rt.runCommand(argv.items, root)) {
        if (std.mem.eql(u8, action, "up")) {
            rt.print("Fix\n  `docker compose up -d` failed. Resolve the Docker error and run `tyx up` again.\n", .{}) catch {};
        } else {
            rt.print("Fix\n  `docker compose down` failed. Resolve the Docker error and run `tyx down` again.\n", .{}) catch {};
        }
        return false;
    }
    return true;
}

fn resolveScript(allocator: std.mem.Allocator, cfg: ProjectConfig, name: []const u8) !?std.ArrayList([]const u8) {
    for (cfg.script_groups.items) |group| for (group.scripts.items) |script| if (std.mem.eql(u8, script, name)) {
        var out = std.ArrayList([]const u8).empty;
        try out.append(allocator, group.runner);
        try out.append(allocator, name);
        return out;
    };
    return null;
}

fn firstLine(s: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, s, " \t\r\n");
    return if (std.mem.indexOfScalar(u8, trimmed, '\n')) |i| std.mem.trim(u8, trimmed[0..i], " \t\r") else trimmed;
}
fn versionMatches(req: []const u8, actual: []const u8) bool {
    if (req.len == 0 or std.mem.eql(u8, req, "latest")) return true;
    return std.mem.eql(u8, leadingMajor(req), leadingMajor(actual));
}
fn leadingMajor(s: []const u8) []const u8 {
    var start: usize = 0;
    while (start < s.len and !std.ascii.isDigit(s[start])) start += 1;
    var end = start;
    while (end < s.len and std.ascii.isDigit(s[end])) end += 1;
    return s[start..end];
}
fn isNodeRunner(r: []const u8) bool {
    return std.mem.eql(u8, r, "npm") or std.mem.eql(u8, r, "pnpm") or std.mem.eql(u8, r, "yarn") or std.mem.eql(u8, r, "bun");
}
