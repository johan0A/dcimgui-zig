pub fn main() !void {
    // init sdl
    if (!c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_GAMEPAD)) return error.sdl_init_failed;

    const main_scale = c.SDL_GetDisplayContentScale(c.SDL_GetPrimaryDisplay());
    const window_flags: c.SDL_WindowFlags = c.SDL_WINDOW_RESIZABLE | c.SDL_WINDOW_HIDDEN | c.SDL_WINDOW_HIGH_PIXEL_DENSITY;
    const window = c.SDL_CreateWindow("dcimgui-zig example", @intFromFloat(1280 * main_scale), @intFromFloat(720 * main_scale), window_flags) orelse return error.sdl_init_failed;

    const sdl_renderer = c.SDL_CreateRenderer(window, null) orelse return error.sdl_init_failed;
    _ = c.SDL_SetRenderVSync(sdl_renderer, 1);
    _ = c.SDL_SetWindowPosition(window, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED);
    _ = c.SDL_ShowWindow(window);

    // init imgui
    _ = c.CIMGUI_CHECKVERSION();
    _ = c.ImGui_CreateContext(null);
    const imgui_io: *c.ImGuiIO = c.ImGui_GetIO();
    imgui_io.ConfigFlags |= c.ImGuiConfigFlags_NavEnableKeyboard | c.ImGuiConfigFlags_NavEnableGamepad | c.ImGuiConfigFlags_DockingEnable;

    c.ImGui_StyleColorsDark(null);

    const style: *c.ImGuiStyle = c.ImGui_GetStyle();
    c.ImGuiStyle_ScaleAllSizes(style, main_scale);

    _ = c.cImGui_ImplSDL3_InitForSDLRenderer(window, sdl_renderer);
    _ = c.cImGui_ImplSDLRenderer3_Init(sdl_renderer);

    var done = false;
    while (!done) {
        var event: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&event)) {
            _ = c.cImGui_ImplSDL3_ProcessEvent(&event);
            if (event.type == c.SDL_EVENT_QUIT) done = true;
            if (event.type == c.SDL_EVENT_WINDOW_CLOSE_REQUESTED and event.window.windowID == c.SDL_GetWindowID(window)) done = true;
        }

        if ((c.SDL_GetWindowFlags(window) & c.SDL_WINDOW_MINIMIZED) != 0) {
            c.SDL_Delay(10);
            continue;
        }

        c.cImGui_ImplSDLRenderer3_NewFrame();
        c.cImGui_ImplSDL3_NewFrame();
        c.ImGui_NewFrame();
        _ = c.ImGui_DockSpaceOverViewport();

        {
            c.ImGui_ShowDemoWindow(null);
        }

        c.ImGui_Render();
        _ = c.SDL_SetRenderScale(sdl_renderer, imgui_io.DisplayFramebufferScale.x, imgui_io.DisplayFramebufferScale.y);
        c.cImGui_ImplSDLRenderer3_RenderDrawData(c.ImGui_GetDrawData(), sdl_renderer);
        _ = c.SDL_RenderPresent(sdl_renderer);
    }
}

const std = @import("std");
const c = @import("c");
