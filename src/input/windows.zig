const std = @import("std");
const input = @import("../input.zig");
const windows = @cImport(@cInclude("windows.h"));

fn map(key: input.VK) windows.WORD {
    return switch (key) {
        .backspace => windows.VK_BACK,
        .tab => windows.VK_TAB,
        .enter => windows.VK_RETURN,
        .escape => windows.VK_ESCAPE,
        .space => windows.VK_SPACE,
        .exclamation_mark => 0,
        .double_quote => 0,
        .hash => 0,
        .dollar => 0,
        .percent => 0,
        .ampersand => 0,
        .single_quote => 0,
        .open_parenthesis => 0,
        .close_parenthesis => 0,
        .asterisk => 0,
        .plus => windows.VK_OEM_PLUS,
        .comma => windows.VK_OEM_COMMA,
        .minus => windows.VK_OEM_MINUS,
        .period => windows.VK_OEM_PERIOD,
        .slash => 0,
        .zero, .one, .two, .three, .four, .five, .six, .seven, .eight, .nine => @intFromEnum(key), // numbers
        .colon => 0,
        .semicolon => 0,
        .less_than => 0,
        .equal => 0,
        .greater_than => 0,
        .question_mark => 0,
        .at => 0,
        .a, .b, .c, .d, .e, .f, .g, .h, .i, .j, .k, .l, .m, .n, .o, .p, .q, .r, .s, .t, .u, .v, .w, .x, .y, .z => @intFromEnum(key), // letters
        .open_bracket => 0,
        .backslash => 0,
        .close_bracket => 0,
        .caret => 0,
        .underscore => 0,
        .backtick => 0,
        .open_brace => 0,
        .pipe => 0,
        .close_brace => 0,
        .tilde => 0,
        .control => windows.VK_CONTROL,
        .alt => windows.VK_MENU,
        .shift => windows.VK_SHIFT,
        .super => windows.VK_LWIN,
        .up => windows.VK_UP,
        .down => windows.VK_DOWN,
        .left => windows.VK_LEFT,
        .right => windows.VK_RIGHT,
        .home => windows.VK_HOME,
        .end => windows.VK_END,
        .page_up => windows.VK_PRIOR,
        .page_down => windows.VK_NEXT,
        .insert => windows.VK_INSERT,
        .delete => windows.VK_DELETE,
        .f1 => windows.VK_F1,
        .f2 => windows.VK_F2,
        .f3 => windows.VK_F3,
        .f4 => windows.VK_F4,
        .f5 => windows.VK_F5,
        .f6 => windows.VK_F6,
        .f7 => windows.VK_F7,
        .f8 => windows.VK_F8,
        .f9 => windows.VK_F9,
        .f10 => windows.VK_F10,
        .f11 => windows.VK_F11,
        .f12 => windows.VK_F12,
        .sleep => windows.VK_SLEEP,
        .volume_down => windows.VK_VOLUME_DOWN,
        .volume_up => windows.VK_VOLUME_UP,
        .volume_mute => windows.VK_VOLUME_MUTE,
        .media_play_pause => windows.VK_MEDIA_PLAY_PAUSE,
        .media_stop => windows.VK_MEDIA_STOP,
        .media_next => windows.VK_MEDIA_NEXT_TRACK,
        .media_prev => windows.VK_MEDIA_PREV_TRACK,
    };
}

pub fn press(key: input.VK) void {
    var in = windows.INPUT{};
    in.type = windows.INPUT_KEYBOARD;
    in.unnamed_0.ki.wVk = map(key);
    _ = windows.SendInput(1, &in, @sizeOf(windows.INPUT));
}

pub fn release(key: input.VK) void {
    var in = windows.INPUT{};
    in.type = windows.INPUT_KEYBOARD;
    in.unnamed_0.ki.wVk = map(key);
    in.unnamed_0.ki.dwFlags = windows.KEYEVENTF_KEYUP;
    _ = windows.SendInput(1, &in, @sizeOf(windows.INPUT));
}
