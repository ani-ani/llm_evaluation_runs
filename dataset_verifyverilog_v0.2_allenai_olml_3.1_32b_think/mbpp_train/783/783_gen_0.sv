module rgb_to_hsv (
    input [31:0] r, g, b,
    output [31:0] h, s, v
);

localparam HUE_60 = 60;
localparam HUE_120 = 120 * 65536;
localparam HUE_240 = 240 * 65536;
localparam HUE_360 = 360 * 65536;

reg [31:0] mx, mn;
mx = r > g ? r : g;
mx = mx > b ? mx : b;
mn = r < g ? r : g;
mn = mn < b ? mn : b;

reg [31:0] df;
 df = mx - mn;

v = mx * 100;

if (df == 0) begin
    h = 0;
    s = 0;
end else begin
    if (mx == r) begin
        reg [31:0] temp;
        temp = ((g - b) << 16) / df;
        h = (temp * HUE_60 + HUE_360);
        if (h >= HUE_360) h = h - HUE_360;
    end else if (mx == g) begin
        reg [31:0] temp;
        temp = ((b - r) << 16) / df;
        h = (temp * HUE_60 + HUE_120);
        if (h >= HUE_360) h = h - HUE_360;
    end else begin
        reg [31:0] temp;
        temp = ((r - g) << 16) / df;
        h = (temp * HUE_60 + HUE_240);
        if (h >= HUE_360) h = h - HUE_360;
    end

    reg [31:0] temp_s;
    temp_s = df * 100;
    s = (temp_s << 16) / mx;
end

endmodule