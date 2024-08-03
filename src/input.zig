const std = @import("std");

const internal = switch (@import("builtin").os.tag) {
    .windows => @import("input/windows.zig"),
    else => @compileError("Unsupported OS"),
};

pub const VK = enum(u16) {
    // ...
    backspace = 0x0008,
    tab = 0x0009,
    enter = 0x000A,
    // ...
    escape = 0x001B,
    // ...
    space = ' ', // 0x0020
    exclamation_mark = '!',
    double_quote = '"',
    hash = '#',
    dollar = '$',
    percent = '%',
    ampersand = '&',
    single_quote = '\'',
    open_parenthesis = '(',
    close_parenthesis = ')',
    asterisk = '*',
    plus = '+',
    comma = ',',
    minus = '-',
    period = '.',
    slash = '/',
    zero = '0', // 0x0030
    one = '1', // 0x0031
    two = '2', // 0x0032
    three = '3', // 0x0033
    four = '4', // 0x0034
    five = '5', // 0x0035
    six = '6', // 0x0036
    seven = '7', // 0x0037
    eight = '8', // 0x0038
    nine = '9', // 0x0039
    colon = ':',
    semicolon = ';',
    less_than = '<',
    equal = '=',
    greater_than = '>',
    question_mark = '?',
    at = '@', // 0x0040
    a = 'A', // 0x0041
    b = 'B', // 0x0042
    c = 'C', // 0x0043
    d = 'D', // 0x0044
    e = 'E', // 0x0045
    f = 'F', // 0x0046
    g = 'G', // 0x0047
    h = 'H', // 0x0048
    i = 'I', // 0x0049
    j = 'J', // 0x004A
    k = 'K', // 0x004B
    l = 'L', // 0x004C
    m = 'M', // 0x004D
    n = 'N', // 0x004E
    o = 'O', // 0x004F
    p = 'P', // 0x0050
    q = 'Q', // 0x0051
    r = 'R', // 0x0052
    s = 'S', // 0x0053
    t = 'T', // 0x0054
    u = 'U', // 0x0055
    v = 'V', // 0x0056
    w = 'W', // 0x0057
    x = 'X', // 0x0058
    y = 'Y', // 0x0059
    z = 'Z', // 0x005A
    open_bracket = '[',
    backslash = '\\',
    close_bracket = ']',
    caret = '^',
    underscore = '_',
    backtick = '`',
    open_brace = '{',
    pipe = '|',
    close_brace = '}',
    tilde = '~',
    // ...
    control = 0x0080,
    alt = 0x0081,
    shift = 0x0082,
    super = 0x0083,
    // ...
    up = 0x0086,
    down = 0x0087,
    left = 0x0088,
    right = 0x0089,
    home = 0x008A,
    end = 0x008B,
    page_up = 0x008C,
    page_down = 0x008D,
    insert = 0x008E,
    delete = 0x008F,
    f1 = 0x0090,
    f2 = 0x0091,
    f3 = 0x0092,
    f4 = 0x0093,
    f5 = 0x0094,
    f6 = 0x0095,
    f7 = 0x0096,
    f8 = 0x0097,
    f9 = 0x0098,
    f10 = 0x0099,
    f11 = 0x00A0,
    f12 = 0x00A1,
    // ...
    sleep = 0x00FF,
    volume_down = 0x0100,
    volume_up = 0x0101,
    volume_mute = 0x0102,
    // ...
    media_play_pause = 0x0110,
    media_stop = 0x0111,
    media_next = 0x0113,
    media_prev = 0x0112,

    pub fn fromAscii(c: u8) !VK {
        const values = std.enums.values(VK);
        for (values) |value| {
            if (@as(u16, @intFromEnum(value)) == @as(u16, c)) return value;
        } else return error.InvalidCharacter;
    }
};

const tap_interval_ns = std.time.ns_per_ms * 20;
const write_interval_ns = std.time.ns_per_ms * 30;

pub fn tap(key: VK) void {
    press(key);
    std.time.sleep(tap_interval_ns);
    release(key);
}

pub fn press(key: VK) void {
    internal.press(key);
}

pub fn release(key: VK) void {
    internal.release(key);
}

pub fn write(text: []const u8) void {
    for (text) |c| {
        if (std.ascii.isAlphabetic(c) and std.ascii.isUpper(c)) {
            press(VK.shift);
            tap(VK.fromAscii(c) catch continue);
            release(VK.shift);
        } else {
            tap(VK.fromAscii(std.ascii.toUpper(c)) catch continue);
        }
        std.time.sleep(write_interval_ns);
    }
}
