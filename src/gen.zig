pub const Backend = enum {
    imgui_impl_allegro5,
    imgui_impl_android,
    imgui_impl_dx10,
    imgui_impl_dx11,
    imgui_impl_dx12,
    imgui_impl_dx9,
    imgui_impl_glfw,
    imgui_impl_glut,
    imgui_impl_opengl2,
    imgui_impl_opengl3,
    imgui_impl_sdl2,
    imgui_impl_sdl3,
    imgui_impl_sdlrenderer2,
    imgui_impl_sdlrenderer3,
    imgui_impl_win32,
    imgui_impl_vulkan,
    imgui_impl_sdlgpu3,
    // imgui_impl_metal, // unsupported
    // imgui_impl_osx, // unsupported
};

const GenPaths = struct {
    const ImguiPath = struct {
        name: []const u8,
        path: []const u8,
    };

    generator_path: []const u8,
    out_path: []const u8,
    imgui: []const ImguiPath,
};

pub fn main() !void {
    var arena_allocator: std.heap.ArenaAllocator = .init(std.heap.page_allocator);
    const alloc = arena_allocator.allocator();

    const args = try std.process.argsAlloc(alloc);

    std.debug.print("\nrunning: {s}\n\n", .{try std.mem.join(alloc, " ", args)});

    if (args.len < 4) {
        std.debug.print("Usage: {s} <generator_path> <out_path> [--imgui name:path ...]\n", .{args[0]});
        return;
    }

    var headers: std.ArrayList(GenPaths.ImguiPath) = .empty;

    var i: usize = 3;
    while (i < args.len - 2) {
        if (std.mem.eql(u8, args[i], "--imgui")) {
            try headers.append(alloc, .{ .name = args[i + 1], .path = args[i + 2] });
            i += 3;
        } else {
            i += 1;
        }
    }

    const gen_paths = GenPaths{
        .generator_path = args[1],
        .out_path = args[2],
        .imgui = try headers.toOwnedSlice(alloc),
    };

    for (gen_paths.imgui) |imgui| {
        std.debug.print("{s}\n", .{imgui.path});
    }

    const out_dir = try std.fs.openDirAbsolute(gen_paths.out_path, .{ .iterate = true });
    var it = out_dir.iterate();
    while (try it.next()) |entry| {
        try out_dir.deleteTree(entry.name);
    }

    const python_path = "python";

    for (gen_paths.imgui) |imgui| {
        {
            const out_dir_path = try std.fs.path.join(alloc, &.{ gen_paths.out_path, imgui.name });
            try std.fs.makeDirAbsolute(out_dir_path);
            var proc = std.process.Child.init(&.{
                python_path,
                gen_paths.generator_path,
                try std.fs.path.join(alloc, &.{ imgui.path, "imgui.h" }),

                "-o",
                try std.fs.path.join(alloc, &.{ out_dir_path, "dcimgui" }),
            }, alloc);
            std.debug.print("\nrunning: {s}\n\n", .{try std.mem.join(alloc, " ", proc.argv)});
            _ = try proc.spawnAndWait();
        }

        const backends_out_dir_path = try std.fs.path.join(alloc, &.{ gen_paths.out_path, imgui.name, "backends" });
        try std.fs.makeDirAbsolute(backends_out_dir_path);
        inline for (@typeInfo(Backend).@"enum".fields) |field| {
            var proc = std.process.Child.init(&.{
                python_path,
                gen_paths.generator_path,
                "--backend",

                "--include",
                try std.fs.path.join(alloc, &.{ imgui.path, "imgui.h" }),

                try std.fmt.allocPrint(alloc, "{s}/{s}/{s}.h", .{ imgui.path, "backends", field.name }),

                "-o",
                try std.fmt.allocPrint(alloc, "{s}/dc{s}", .{ backends_out_dir_path, field.name }),
            }, alloc);
            std.debug.print("running: {s}\n\n", .{try std.mem.join(alloc, " ", proc.argv)});
            _ = try proc.spawnAndWait();
        }
    }

    var walk = try out_dir.walk(alloc);
    while (try walk.next()) |entry| {
        if (std.mem.eql(u8, std.fs.path.extension(entry.basename), ".json")) {
            try out_dir.deleteFile(entry.path);
        }
    }
}

const std = @import("std");
