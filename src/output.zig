const std = @import("std");
const types = @import("types.zig");
const Runtime = @import("runtime.zig").Runtime;

const ProjectConfig = types.ProjectConfig;
const RepoInfo = types.RepoInfo;
const Tool = types.Tool;
const ResolvedTool = types.ResolvedTool;
const FileCheck = types.FileCheck;
const DependencyCheck = types.DependencyCheck;

pub fn printInitSuccess(rt: Runtime, allocator: std.mem.Allocator, info: RepoInfo) !void {
    try rt.print("Tyx initialized this repo\n", .{});
    try printSection(rt, "Wrote");
    try rt.print("  ✓ project.tyx\n", .{});
    try printDetectedRepo(rt, allocator, info);
    try printSection(rt, "Next");
    try rt.print("  tyx up\n", .{});
    if (info.scripts.items.len > 0) try rt.print("  tyx run {s}\n", .{try quoteIfNeeded(allocator, info.scripts.items[0])});
}

fn printDetectedRepo(rt: Runtime, allocator: std.mem.Allocator, info: RepoInfo) !void {
    try printSection(rt, "Detected");
    if (info.node.len > 0) try rt.print("  ✓ node {s:<15} package.json#engines.node/.nvmrc\n", .{info.node});
    if (info.package_manager.len > 0) try rt.print("  ✓ {s:<4} {s:<15} package.json#packageManager\n", .{ info.package_manager, info.package_manager_version });
    for (info.compose_files.items) |f| try rt.print("  ✓ compose             {s}\n", .{f});
    if (info.has_env_example) try rt.print("  ✓ env example         .env.example\n", .{});
    if (info.has_env_file) try rt.print("  ✓ env file            .env\n", .{});
    if (info.scripts.items.len > 0) try rt.print("  ✓ scripts             {s}\n", .{try joinDisplay(allocator, info.scripts.items)});
}

pub fn printUpSuccess(rt: Runtime, allocator: std.mem.Allocator, cfg: ProjectConfig, tools: []const ResolvedTool, compose: []const FileCheck, env_checks: []const FileCheck, deps: []const DependencyCheck) !void {
    try rt.print("Tyx prepared this repo\n", .{});
    try printSection(rt, "Wrote");
    try rt.print("  ✓ tyx.lock\n", .{});
    try printResolvedTools(rt, tools);
    try printFileChecks(rt, "Services", compose);
    try printFileChecks(rt, "Env", env_checks);
    try printDependencyChecks(rt, deps);
    try printScriptGroups(rt, cfg);
    try printFixes(rt, tools, compose, env_checks, deps);
    try printReady(rt, allocator, cfg);
}

pub fn printDownStart(rt: Runtime, compose: []const FileCheck) !void {
    try rt.print("Tyx tearing down this repo\n", .{});
    if (compose.len == 0) {
        try printSection(rt, "Ready");
        try rt.print("  no runtime services declared\n", .{});
        return;
    }
    try printFileChecks(rt, "Services", compose);
}

pub fn printParsedConfig(rt: Runtime, cfg: ProjectConfig) !void {
    try rt.print("Parsed project.tyx\n", .{});
    try printConfigTools(rt, cfg.tools.items);
    try printConfigServices(rt, cfg.compose_files.items);
    try printConfigEnv(rt, cfg.env_examples.items, cfg.env_files.items);
    try printScriptGroups(rt, cfg);
}

fn printConfigTools(rt: Runtime, tools: []const Tool) !void {
    if (tools.len == 0) return;
    try printSection(rt, "Tools");
    for (tools) |t| try rt.print("  ✓ {s} {s}\n", .{ t.name, t.version });
}

fn printConfigServices(rt: Runtime, compose_files: []const []const u8) !void {
    if (compose_files.len == 0) return;
    try printSection(rt, "Services");
    for (compose_files) |f| try rt.print("  ✓ compose {s}\n", .{f});
}

fn printConfigEnv(rt: Runtime, examples: []const []const u8, files: []const []const u8) !void {
    if (examples.len == 0 and files.len == 0) return;
    try printSection(rt, "Env");
    for (examples) |f| try rt.print("  ✓ example {s}\n", .{f});
    for (files) |f| try rt.print("  ✓ file {s}\n", .{f});
}

fn printResolvedTools(rt: Runtime, tools: []const ResolvedTool) !void {
    if (tools.len == 0) return;
    try printSection(rt, "Tools");
    for (tools) |t| {
        if (std.mem.eql(u8, t.status, "present") and t.matches) {
            try rt.print("  ✓ {s} {s} present", .{ t.name, t.requested });
            try printOptionalVersion(rt, t.version);
        } else if (std.mem.eql(u8, t.status, "present")) {
            try rt.print("  ! {s} {s} mismatch", .{ t.name, t.requested });
            try printOptionalVersion(rt, t.version);
        } else if (std.mem.eql(u8, t.status, "missing")) {
            try rt.print("  ! {s} {s} missing\n", .{ t.name, t.requested });
        } else {
            try rt.print("  ! {s} {s} unsupported\n", .{ t.name, t.requested });
        }
    }
}

fn printOptionalVersion(rt: Runtime, version: []const u8) !void {
    if (version.len > 0) try rt.print(" ({s})", .{version});
    try rt.print("\n", .{});
}

fn printFileChecks(rt: Runtime, title: []const u8, checks: []const FileCheck) !void {
    if (checks.len == 0) return;
    try printSection(rt, title);
    for (checks) |c| {
        const mark = if (std.mem.eql(u8, c.status, "present")) "✓" else "!";
        const suffix = if (std.mem.eql(u8, c.status, "present")) "" else " missing";
        if (std.mem.eql(u8, c.kind, "compose")) {
            try rt.print("  {s} compose {s}{s}\n", .{ mark, c.path, suffix });
        } else {
            try rt.print("  {s} {s} {s}{s}\n", .{ mark, c.kind, c.path, suffix });
        }
    }
}

fn printDependencyChecks(rt: Runtime, deps: []const DependencyCheck) !void {
    if (deps.len == 0) return;
    try printSection(rt, "Dependencies");
    for (deps) |d| {
        if (std.mem.eql(u8, d.status, "present")) {
            try rt.print("  ✓ {s} dependencies present ({s})\n", .{ d.runner, d.path });
        } else {
            try rt.print("  ! {s} dependencies missing ({s})\n", .{ d.runner, d.path });
        }
    }
}

fn printScriptGroups(rt: Runtime, cfg: ProjectConfig) !void {
    for (cfg.script_groups.items) |group| {
        if (group.scripts.items.len == 0) continue;
        try printSectionFmt(rt, "Scripts {s}", .{group.runner});
        for (group.scripts.items) |s| try rt.print("  ✓ {s}\n", .{s});
    }
}

fn printFixes(rt: Runtime, tools: []const ResolvedTool, compose: []const FileCheck, env_checks: []const FileCheck, deps: []const DependencyCheck) !void {
    var printed = false;
    for (tools) |t| {
        if (std.mem.eql(u8, t.status, "present") and t.matches) continue;
        try printFixHeader(rt, &printed);
        if (std.mem.eql(u8, t.status, "missing")) {
            try rt.print("  Install {s} {s} or make it available on PATH.\n", .{ t.name, t.requested });
        } else if (std.mem.eql(u8, t.status, "present")) {
            try rt.print("  Use {s} {s}; found {s} on PATH.\n", .{ t.name, t.requested, t.version });
        } else {
            try rt.print("  Tool {s} is not supported by Tyx tool detection yet.\n", .{t.name});
        }
    }
    for (compose) |c| if (!std.mem.eql(u8, c.status, "present")) {
        try printFixHeader(rt, &printed);
        try rt.print("  Restore compose file {s} or remove it from project.tyx.\n", .{c.path});
    };
    for (env_checks) |c| if (!std.mem.eql(u8, c.status, "present")) {
        try printFixHeader(rt, &printed);
        if (std.mem.eql(u8, c.kind, "file")) {
            try rt.print("  Create {s} or remove it from project.tyx.\n", .{c.path});
        } else {
            try rt.print("  Restore env example {s} or remove it from project.tyx.\n", .{c.path});
        }
    };
    for (deps) |d| if (!std.mem.eql(u8, d.status, "present")) {
        try printFixHeader(rt, &printed);
        try rt.print("  Run {s} install to create {s}.\n", .{ d.runner, d.path });
    };
}

fn printReady(rt: Runtime, allocator: std.mem.Allocator, cfg: ProjectConfig) !void {
    try printSection(rt, "Ready");
    if (firstScript(cfg)) |script| {
        try rt.print("  tyx run {s}\n", .{try quoteIfNeeded(allocator, script)});
    } else {
        try rt.print("  project.tyx parsed successfully\n", .{});
    }
}

fn firstScript(cfg: ProjectConfig) ?[]const u8 {
    for (cfg.script_groups.items) |group| if (group.scripts.items.len > 0) return group.scripts.items[0];
    return null;
}

fn printFixHeader(rt: Runtime, printed: *bool) !void {
    if (printed.*) return;
    try printSection(rt, "Fix");
    printed.* = true;
}

fn printSection(rt: Runtime, title: []const u8) !void {
    try rt.print("\n{s}\n", .{title});
}

fn printSectionFmt(rt: Runtime, comptime fmt: []const u8, args: anytype) !void {
    try rt.print("\n" ++ fmt ++ "\n", args);
}

fn quoteIfNeeded(allocator: std.mem.Allocator, s: []const u8) ![]const u8 {
    if (std.mem.indexOfAny(u8, s, " \t") == null) return s;
    return std.fmt.allocPrint(allocator, "\"{s}\"", .{s});
}

fn joinDisplay(allocator: std.mem.Allocator, items: []const []const u8) ![]const u8 {
    var out = std.ArrayList(u8).empty;
    for (items, 0..) |item, i| {
        if (i > 0) try out.appendSlice(allocator, ", ");
        try out.appendSlice(allocator, try quoteIfNeeded(allocator, item));
    }
    return out.toOwnedSlice(allocator);
}
