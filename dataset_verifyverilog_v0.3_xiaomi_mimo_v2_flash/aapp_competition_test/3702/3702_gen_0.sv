module fib_seq_solver(
    input [19:0] n,
    input [19:0] a,
    input [19:0] d,
    output reg [63:0] b,
    output reg [63:0] e
);

    // Constant definitions with explicit widths
    localparam [63:0] CONST = 64'd368131125;
    localparam [63:0] MOD = 64'd1000000000;
    localparam [63:0] SCALE = 64'd12000000000;
    
    // Intermediate results
    wire [63:0] const_a_product;
    wire [63:0] const_a_mod;
    wire [63:0] const_a_scaled;
    wire [63:0] const_d_product;
    wire [63:0] const_d_mod;
    wire [63:0] const_d_scaled;

    // Compute b = ((CONST * a) % MOD) * SCALE + 1
    assign const_a_product = CONST * {44'd0, a};
    assign const_a_mod = const_a_product % MOD;
    assign const_a_scaled = const_a_mod * SCALE;
    
    // Compute e = ((CONST * d) % MOD) * SCALE
    assign const_d_product = CONST * {44'd0, d};
    assign const_d_mod = const_d_product % MOD;
    assign const_d_scaled = const_d_mod * SCALE;

    // Assign outputs
    always @(*) begin
        b = const_a_scaled + 64'd1;
        e = const_d_scaled;
    end

endmodule