const std = @import("std");
const types = @import("types.zig");
const Runtime = @import("runtime.zig").Runtime;

const ProjectConfig = types.ProjectConfig;
const ScriptGroup = types.ScriptGroup;

pub fn loadProjectConfig(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !?ProjectConfig {
    const bytes = rt.readFileAlloc(allocator, path, 1024 * 1024) catch |err| {
        try rt.print("Fix\n  Could not read {s}: {s}\n", .{ path, rt.fileReadErrorName(err) });
        return null;
    };
    defer allocator.free(bytes);
    return parseTyx(rt, allocator, bytes);
}

fn parseTyx(rt: Runtime, allocator: std.mem.Allocator, input: []const u8) !?ProjectConfig {
    var cfg = ProjectConfig{};
    var current = std.ArrayList([]const u8).empty;
    defer current.deinit(allocator);
    var seen_project = false;
    var lines = std.mem.splitScalar(u8, input, '\n');
    var line_no: usize = 1;
    while (lines.next()) |line_raw| : (line_no += 1) {
        const line = std.mem.trim(u8, line_raw, " \t\r");
        if (line.len == 0 or std.mem.startsWith(u8, line, "#")) continue;
        if (hasUnclosedQuote(line)) {
            try rt.print("Fix\n  Unterminated quoted token on line {d}.\n", .{line_no});
            return null;
        }
        if (isHeader(line)) {
            current.clearRetainingCapacity();
            const head = line[0 .. line.len - 1];
            var toks = try tokenize(allocator, head);
            defer toks.deinit(allocator);
            if (!try validateHeader(rt, toks.items, line_no, &seen_project)) return null;
            for (toks.items) |tok| try current.append(allocator, try allocator.dupe(u8, tok));
        } else {
            if (current.items.len == 0) {
                try rt.print("Fix\n  Entry before any section on line {d}.\n", .{line_no});
                return null;
            }
            var toks = try tokenize(allocator, line);
            defer toks.deinit(allocator);
            if (!try validateEntry(rt, current.items, toks.items, line_no)) return null;
            try addConfigEntry(allocator, &cfg, current.items, toks.items);
        }
    }
    if (!seen_project) {
        try rt.print("Fix\n  project.tyx is missing the `project:` header.\n\n  Add `project:` near the top of the file.\n", .{});
        return null;
    }
    return cfg;
}

fn validateHeader(rt: Runtime, tokens: []const []const u8, line: usize, seen_project: *bool) !bool {
    if (tokens.len == 0) return false;
    const section = tokens[0];
    if (std.mem.eql(u8, section, "project")) {
        if (tokens.len != 1) return false;
        seen_project.* = true;
        return true;
    }
    if (std.mem.eql(u8, section, "tools") or std.mem.eql(u8, section, "services") or std.mem.eql(u8, section, "env")) {
        if (tokens.len == 1) return true;
        try rt.print("Unsupported\n  Qualified `{s}` section on line {d} is not supported yet.\n\nFix\n  Use `{s}:` without qualifiers for the MVP.\n", .{ section, line, section });
        return false;
    }
    if (std.mem.eql(u8, section, "scripts")) {
        if (tokens.len != 2) {
            try rt.print("Fix\n  `scripts` section on line {d} needs exactly one runner.\n", .{line});
            return false;
        }
        return true;
    }
    try rt.print("Unsupported\n  section `{s}` on line {d} is not supported.\n\nFix\n  Use project:, tools:, services:, env:, or scripts <runner>:\n", .{ section, line });
    return false;
}

fn validateEntry(rt: Runtime, header: []const []const u8, tokens: []const []const u8, line: usize) !bool {
    const section = header[0];
    if (std.mem.eql(u8, section, "tools")) {
        if (tokens.len != 2) {
            try rt.print("Fix\n  Tool entry on line {d} must be `<tool> <version>`.\n\n  Example: `node 22`\n", .{line});
            return false;
        }
        if (!isSupportedTool(tokens[0])) {
            try rt.print("Unsupported\n  tool `{s}` on line {d} is not supported yet.\n\nFix\n  Use node, npm, pnpm, yarn, or bun for the MVP.\n", .{ tokens[0], line });
            return false;
        }
    } else if (std.mem.eql(u8, section, "services")) {
        if (!(tokens.len == 2 and std.mem.eql(u8, tokens[0], "compose"))) return false;
    } else if (std.mem.eql(u8, section, "env")) {
        if (!(tokens.len == 2 and (std.mem.eql(u8, tokens[0], "example") or std.mem.eql(u8, tokens[0], "file")))) return false;
    } else if (std.mem.eql(u8, section, "scripts")) {
        if (tokens.len != 1) {
            try rt.print("Fix\n  Script entry on line {d} must be one script name.\n\n  Quote names that contain spaces, e.g. `\"dev server\"`.\n", .{line});
            return false;
        }
    }
    return true;
}

fn addConfigEntry(allocator: std.mem.Allocator, cfg: *ProjectConfig, header: []const []const u8, tokens: []const []const u8) !void {
    if (std.mem.eql(u8, header[0], "tools")) try cfg.tools.append(allocator, .{ .name = try allocator.dupe(u8, tokens[0]), .version = try allocator.dupe(u8, tokens[1]) }) else if (std.mem.eql(u8, header[0], "services")) try cfg.compose_files.append(allocator, try allocator.dupe(u8, tokens[1])) else if (std.mem.eql(u8, header[0], "env")) {
        if (std.mem.eql(u8, tokens[0], "example")) try cfg.env_examples.append(allocator, try allocator.dupe(u8, tokens[1])) else try cfg.env_files.append(allocator, try allocator.dupe(u8, tokens[1]));
    } else if (std.mem.eql(u8, header[0], "scripts")) {
        for (cfg.script_groups.items) |*group| if (std.mem.eql(u8, group.runner, header[1])) {
            try group.scripts.append(allocator, try allocator.dupe(u8, tokens[0]));
            return;
        };
        var group = ScriptGroup{ .runner = try allocator.dupe(u8, header[1]) };
        try group.scripts.append(allocator, try allocator.dupe(u8, tokens[0]));
        try cfg.script_groups.append(allocator, group);
    }
}

fn tokenize(allocator: std.mem.Allocator, line: []const u8) !std.ArrayList([]const u8) {
    var tokens = std.ArrayList([]const u8).empty;
    var i: usize = 0;
    while (i < line.len) {
        while (i < line.len and isSpace(line[i])) i += 1;
        if (i >= line.len) break;
        if (line[i] == '"') {
            i += 1;
            const start = i;
            while (i < line.len and line[i] != '"') i += 1;
            if (i >= line.len) return error.UnclosedQuote;
            try tokens.append(allocator, line[start..i]);
            i += 1;
        } else {
            const start = i;
            while (i < line.len and !isSpace(line[i])) i += 1;
            try tokens.append(allocator, line[start..i]);
        }
    }
    return tokens;
}

fn hasUnclosedQuote(line: []const u8) bool {
    var in_quote = false;
    var escaped = false;
    for (line) |b| {
        if (escaped) {
            escaped = false;
            continue;
        }
        if (b == '\\' and in_quote) {
            escaped = true;
            continue;
        }
        if (b == '"') in_quote = !in_quote;
    }
    return in_quote;
}

fn isHeader(line: []const u8) bool {
    return line.len > 0 and line[line.len - 1] == ':' and !hasUnclosedQuote(line);
}
fn isSpace(b: u8) bool {
    return b == ' ' or b == '\t' or b == '\r';
}
fn isSupportedTool(name: []const u8) bool {
    return std.mem.eql(u8, name, "node") or std.mem.eql(u8, name, "npm") or std.mem.eql(u8, name, "pnpm") or std.mem.eql(u8, name, "yarn") or std.mem.eql(u8, name, "bun");
}
