const std = @import("std");
const types = @import("types.zig");
const runtime_mod = @import("runtime.zig");
const Runtime = runtime_mod.Runtime;

const RepoInfo = types.RepoInfo;

const script_order = [_][]const u8{ "dev", "test", "lint", "build" };
const compose_candidates = [_][]const u8{ "compose.yaml", "compose.yml", "docker-compose.yaml", "docker-compose.yml", "compose.override.yaml", "compose.override.yml", "docker-compose.override.yaml", "docker-compose.override.yml" };

pub fn scanRepo(rt: Runtime, allocator: std.mem.Allocator, path: []const u8) !?RepoInfo {
    const pkg_path = try runtime_mod.join(allocator, path, "package.json");
    defer allocator.free(pkg_path);
    const bytes = rt.readFileAlloc(allocator, pkg_path, 1024 * 1024) catch {
        try rt.print("Unsupported\n  No package.json found\n\nFix\n  Tyx currently supports Node/TypeScript repos.\n", .{});
        return null;
    };
    defer allocator.free(bytes);
    var parsed = try std.json.parseFromSlice(std.json.Value, allocator, bytes, .{});
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const root = parsed.value.object;
    var info = RepoInfo{};
    if (root.get("packageManager")) |pmv| if (pmv == .string) parsePackageManager(pmv.string, &info);
    if (root.get("engines")) |eng| {
        if (eng == .object) {
            if (eng.object.get("node")) |node| {
                if (node == .string) info.node = chooseNodeMajor(node.string);
            }
        }
    }
    inline for (.{ ".nvmrc", ".node-version" }) |file| {
        if (try readTrimmed(rt, allocator, path, file)) |v| info.node = chooseNodeMajor(v);
    }
    if (root.get("scripts")) |scripts| if (scripts == .object) try appendOrderedScripts(allocator, &info.scripts, scripts.object);
    for (compose_candidates) |file| {
        const full_path = try runtime_mod.join(allocator, path, file);
        if (rt.existsFile(full_path)) try info.compose_files.append(allocator, file);
    }
    const env_example_path = try runtime_mod.join(allocator, path, ".env.example");
    info.has_env_example = rt.existsFile(env_example_path);
    const env_file_path = try runtime_mod.join(allocator, path, ".env");
    info.has_env_file = rt.existsFile(env_file_path);
    if (info.package_manager.len == 0 and !try inferPackageManager(rt, allocator, path, &info)) return null;
    return info;
}

fn appendOrderedScripts(allocator: std.mem.Allocator, out: *std.ArrayList([]const u8), scripts: std.json.ObjectMap) !void {
    var seen = std.StringHashMap(void).init(allocator);
    defer seen.deinit();
    for (script_order) |name| if (scripts.contains(name)) {
        try out.append(allocator, name);
        try seen.put(name, {});
    };
    var rest = std.ArrayList([]const u8).empty;
    defer rest.deinit(allocator);
    var it = scripts.iterator();
    while (it.next()) |entry| if (!seen.contains(entry.key_ptr.*)) try rest.append(allocator, entry.key_ptr.*);
    std.mem.sort([]const u8, rest.items, {}, lessThanString);
    try out.appendSlice(allocator, rest.items);
}

fn lessThanString(_: void, a: []const u8, b: []const u8) bool {
    return std.mem.lessThan(u8, a, b);
}

fn inferPackageManager(rt: Runtime, allocator: std.mem.Allocator, path: []const u8, info: *RepoInfo) !bool {
    var detected = std.ArrayList([]const u8).empty;
    defer detected.deinit(allocator);
    inline for (.{ .{ "pnpm", "pnpm-lock.yaml" }, .{ "yarn", "yarn.lock" }, .{ "bun", "bun.lock" }, .{ "bun", "bun.lockb" }, .{ "npm", "package-lock.json" } }) |pair| {
        const full_path = try runtime_mod.join(allocator, path, pair[1]);
        if (rt.existsFile(full_path)) try detected.append(allocator, pair[0]);
    }
    if (detected.items.len > 1) {
        try rt.print("Fix\n  Multiple package manager lockfiles detected:\n", .{});
        for (detected.items) |name| try rt.print("    {s}\n", .{name});
        try rt.print("\n  Remove stale lockfiles or add packageManager to package.json.\n", .{});
        return false;
    }
    if (detected.items.len == 1) info.package_manager = detected.items[0] else info.package_manager = "npm";
    info.package_manager_version = "latest";
    return true;
}

fn parsePackageManager(pm: []const u8, info: *RepoInfo) void {
    if (std.mem.indexOfScalar(u8, pm, '@')) |i| {
        info.package_manager = pm[0..i];
        info.package_manager_version = pm[i + 1 ..];
    } else info.package_manager = pm;
}

fn chooseNodeMajor(expr: []const u8) []const u8 {
    if (std.mem.indexOf(u8, expr, "22") != null or std.mem.indexOf(u8, expr, ">=20") != null) return "22";
    if (std.mem.indexOf(u8, expr, "20") != null) return "20";
    if (std.mem.indexOf(u8, expr, "18") != null) return "18";
    return "22";
}

fn readTrimmed(rt: Runtime, allocator: std.mem.Allocator, root: []const u8, file: []const u8) !?[]const u8 {
    const p = try runtime_mod.join(allocator, root, file);
    defer allocator.free(p);
    const bytes = rt.readFileAlloc(allocator, p, 1024) catch return null;
    return std.mem.trim(u8, bytes, " \t\r\n");
}
