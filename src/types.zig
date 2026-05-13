const std = @import("std");

pub const Entry = struct {
    header: []const []const u8,
    tokens: []const []const u8,
    line: usize,
};

pub const Tool = struct { name: []const u8, version: []const u8 };
pub const ScriptGroup = struct { runner: []const u8, scripts: std.ArrayList([]const u8) = .empty };

pub const ProjectConfig = struct {
    tools: std.ArrayList(Tool) = .empty,
    compose_files: std.ArrayList([]const u8) = .empty,
    env_examples: std.ArrayList([]const u8) = .empty,
    env_files: std.ArrayList([]const u8) = .empty,
    script_groups: std.ArrayList(ScriptGroup) = .empty,

    pub fn deinit(self: *ProjectConfig, allocator: std.mem.Allocator) void {
        self.tools.deinit(allocator);
        self.compose_files.deinit(allocator);
        self.env_examples.deinit(allocator);
        self.env_files.deinit(allocator);
        for (self.script_groups.items) |*group| group.scripts.deinit(allocator);
        self.script_groups.deinit(allocator);
    }
};

pub const RepoInfo = struct {
    node: []const u8 = "22",
    package_manager: []const u8 = "",
    package_manager_version: []const u8 = "latest",
    scripts: std.ArrayList([]const u8) = .empty,
    compose_files: std.ArrayList([]const u8) = .empty,
    has_env_example: bool = false,
    has_env_file: bool = false,

    pub fn deinit(self: *RepoInfo, allocator: std.mem.Allocator) void {
        self.scripts.deinit(allocator);
        self.compose_files.deinit(allocator);
    }
};

pub const FileCheck = struct { kind: []const u8, path: []const u8, status: []const u8 };
pub const DependencyCheck = struct { runner: []const u8, manifest: []const u8, path: []const u8, status: []const u8 };
pub const ResolvedTool = struct {
    name: []const u8,
    requested: []const u8,
    status: []const u8,
    provider: []const u8 = "path",
    version: []const u8 = "",
    matches: bool = false,
};
