module badge_decks (
    input [5:0] b,
    input [5:0] g,
    input [5:0] n,
    output [5:0] count
);
// Compute lower = max(0, n - g)
wire [5:0] lower;
assign lower = (n >= g) ? (n - g) : 0;
// Compute upper = min(b, n)
wire [5:0] upper;
assign upper = (b <= n) ? b : n;
// Check if lower <= upper
wire valid = lower <= upper;
// Compute count: if valid, upper - lower + 1, else 0
wire [6:0] temp_count;
assign temp_count = valid ? (upper - lower + 1) : 0;
// Truncate to 6 bits
assign count = temp_count[5:0];
endmodule