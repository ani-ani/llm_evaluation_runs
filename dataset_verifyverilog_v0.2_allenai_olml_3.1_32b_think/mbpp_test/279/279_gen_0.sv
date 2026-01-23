module decagonal (
    input [7:0] n,
    output [19:0] result
);

wire [15:0] n_ext = {8{0}, n};
wire [31:0] n_squared;
assign n_squared = n_ext * n_ext;

wire [17:0] term1;
assign term1 = n_squared << 2;

wire [17:0] term2;
assign term2 = 3 * n;

assign result = {2'b0, term1 - term2};

endmodule