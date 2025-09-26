const std = @import("std");
const gen = @import("src/gen.zig");
pub const Backend = gen.Backend;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const backends = b.option([]const Backend, "backends", "") orelse &.{};
    const docking = b.option(bool, "docking", "") orelse false;
    const imconfig = blk: {
        var imconfig_include_dir = b.addWriteFiles();
        if (b.option(std.Build.LazyPath, "imconfig", "configuration file for imgui. see imconfig.h in root of imgui repo for details. /!\\ not every configs in imconfig.h are supported as some change the bindings generation and the bindings are pre-generated.")) |imconfig| {
            _ = imconfig_include_dir.addCopyFile(imconfig, "imconfig.h");
        } else {
            _ = imconfig_include_dir.add("imconfig.h", "");
        }
        break :blk imconfig_include_dir.getDirectory();
    };

    const imgui_path = blk: {
        const imgui_dep = switch (docking) {
            false => b.dependency("imgui", .{}),
            true => b.dependency("imgui_docking", .{}),
        };
        break :blk b.addWriteFiles().addCopyDirectory(imgui_dep.path(""), "", .{ .exclude_extensions = &.{"imconfig.h"} });
    };

    const dcimgui_path = switch (docking) {
        false => b.path("gen/imgui"),
        true => b.path("gen/imgui_docking"),
    };
    const dcimgui_backends_path = try dcimgui_path.join(b.allocator, "backends");

    const lib_cimgui_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = true,
    });

    {
        lib_cimgui_mod.addCSourceFiles(.{
            .root = imgui_path.path(b, ""),
            .files = &.{
                "imgui_demo.cpp",
                "imgui_draw.cpp",
                "imgui_tables.cpp",
                "imgui_widgets.cpp",
                "imgui.cpp",
            },
        });

        lib_cimgui_mod.addCSourceFile(.{ .file = dcimgui_path.path(b, "dcimgui.cpp") });

        for (backends) |backend| {
            lib_cimgui_mod.addCSourceFile(.{ .file = imgui_path.path(b, b.fmt("backends/{t}.cpp", .{backend})) });
            lib_cimgui_mod.addCSourceFile(.{ .file = dcimgui_backends_path.path(b, b.fmt("dc{t}.cpp", .{backend})) });
        }

        lib_cimgui_mod.addIncludePath(imconfig);

        lib_cimgui_mod.addIncludePath(imgui_path.path(b, ""));
        lib_cimgui_mod.addIncludePath(imgui_path.path(b, "backends/"));

        lib_cimgui_mod.addIncludePath(dcimgui_path);
        lib_cimgui_mod.addIncludePath(dcimgui_backends_path);

        const header_path_list = b.option([]std.Build.LazyPath, "include-path-list", "list of path to headers to be included for compiling the various backends that need it") orelse &.{};
        for (header_path_list) |headers_path| {
            lib_cimgui_mod.addIncludePath(headers_path);
        }
    }

    {
        const lib_cimgui = b.addLibrary(.{
            .linkage = b.option(std.builtin.LinkMode, "linkage", "default to static") orelse .static,
            .name = "cimgui_clib",
            .root_module = lib_cimgui_mod,
        });
        b.installArtifact(lib_cimgui);

        lib_cimgui.installHeadersDirectory(imconfig, "", .{});
        lib_cimgui.installHeadersDirectory(dcimgui_path, "", .{});
        lib_cimgui.installHeadersDirectory(imgui_path.path(b, ""), "", .{});
        for (backends) |backend| {
            const file_name = b.fmt("dc{t}.h", .{backend});
            lib_cimgui.installHeader(dcimgui_backends_path.path(b, file_name), file_name);
        }
    }

    {
        const generator = b.addWriteFiles();
        _ = generator.addCopyDirectory(b.dependency("dear_bindings", .{}).path(""), "", .{});
        _ = generator.addCopyDirectory(b.dependency("ply", .{}).path("src"), "", .{});
        const generator_path = generator.getDirectory().path(b, "dear_bindings.py");

        const gen_script = b.addExecutable(.{
            .name = "gen",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/gen.zig"),
                .target = b.graph.host,
            }),
        });

        const run_gen = b.addRunArtifact(gen_script);

        run_gen.addFileArg(generator_path);
        run_gen.addFileArg(b.path("gen"));

        run_gen.addArg("--imgui");
        run_gen.addArg("imgui");
        run_gen.addFileArg(b.dependency("imgui", .{}).path(""));

        run_gen.addArg("--imgui");
        run_gen.addArg("imgui_docking");
        run_gen.addFileArg(b.dependency("imgui_docking", .{}).path(""));

        const gen_step = b.step("gen", "");
        gen_step.dependOn(&run_gen.step);
    }
}

// TODO: use lazy dependencies
