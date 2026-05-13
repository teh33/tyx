const std = @import("std");

pub const Runtime = struct {
    io: std.Io,

    pub fn print(self: Runtime, comptime fmt: []const u8, args: anytype) !void {
        var buffer: [4096]u8 = undefined;
        var writer = std.Io.File.stdout().writerStreaming(self.io, &buffer);
        try writer.interface.print(fmt, args);
        try writer.interface.flush();
    }

    pub fn writeFile(self: Runtime, path: []const u8, data: []const u8) !void {
        try std.Io.Dir.cwd().writeFile(self.io, .{ .sub_path = path, .data = data });
    }

    pub fn readFileAlloc(self: Runtime, allocator: std.mem.Allocator, path: []const u8, limit: usize) ![]u8 {
        return std.Io.Dir.cwd().readFileAlloc(self.io, path, allocator, .limited(limit));
    }

    pub fn fileReadErrorName(_: Runtime, err: anyerror) []const u8 {
        return switch (err) {
            error.FileNotFound => "Not_Exist",
            else => @errorName(err),
        };
    }

    pub fn existsFile(self: Runtime, path: []const u8) bool {
        const f = std.Io.Dir.cwd().openFile(self.io, path, .{}) catch return false;
        f.close(self.io);
        return true;
    }

    pub fn existsDir(self: Runtime, path: []const u8) bool {
        var d = std.Io.Dir.cwd().openDir(self.io, path, .{}) catch return false;
        d.close(self.io);
        return true;
    }

    pub fn runCommand(self: Runtime, argv: []const []const u8, cwd: []const u8) bool {
        var child = std.process.spawn(self.io, .{ .argv = argv, .cwd = .{ .path = cwd }, .stdin = .ignore, .stdout = .inherit, .stderr = .inherit }) catch return false;
        const term = child.wait(self.io) catch return false;
        return switch (term) {
            .exited => |code| code == 0,
            else => false,
        };
    }

    pub fn runCommandWithFix(self: Runtime, argv: []const []const u8, cwd: []const u8) bool {
        if (self.runCommand(argv, cwd)) return true;
        self.print("Fix\n  Command failed.\n", .{}) catch {};
        return false;
    }

    pub fn runCapture(self: Runtime, allocator: std.mem.Allocator, argv: []const []const u8) ![]const u8 {
        const result = try std.process.run(allocator, self.io, .{ .argv = argv, .stdout_limit = .limited(64 * 1024), .stderr_limit = .limited(64 * 1024) });
        defer allocator.free(result.stderr);
        return result.stdout;
    }
};

pub fn join(allocator: std.mem.Allocator, a: []const u8, b: []const u8) ![]u8 {
    return std.fs.path.join(allocator, &.{ a, b });
}
