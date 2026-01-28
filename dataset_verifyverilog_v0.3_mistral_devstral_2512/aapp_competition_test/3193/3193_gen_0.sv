module solve_linear_congruence (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] a,    // Coefficient of x
    input signed [31:0] b,    // Constant term
    input [31:0] P,           // Target remainder
    input [31:0] M,           // Modulus
    output reg [31:0] x,      // Solution
    output reg done           // Computation complete
);

// State declarations
localparam [1:0] IDLE    = 2'd0;
localparam [1:0] COMPUTE = 2'd1;
localparam [1:0] FINISH  = 2'd2;

reg [1:0] state;
reg [31:0] x_reg;
reg [7:0] cycle_count;
localparam [7:0] MAX_CYCLES = 8'd255;

// Compute the value (a*x + b) % M
wire signed [63:0] product = a * x_reg;
wire signed [63:0] sum = product + b;
wire signed [63:0] value_signed = sum % $signed(M);
wire [31:0] value = (value_signed < 0) ? value_signed + $signed(M) : value_signed;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        x_reg <= 32'd0;
        x <= 32'd0;
        done <= 1'b0;
        cycle_count <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_count <= 8'd0;
                if (start) begin
                    state <= COMPUTE;
                    x_reg <= 32'd0;
                end
            end
            
            COMPUTE: begin
                cycle_count <= cycle_count + 8'd1;
                
                if (value == P) begin
                    state <= FINISH;
                end else if (x_reg == M - 1 || cycle_count >= MAX_CYCLES) begin
                    // No solution found or timeout
                    x_reg <= 32'd0;
                    state <= FINISH;
                end else begin
                    x_reg <= x_reg + 32'd1;
                end
            end
            
            FINISH: begin
                x <= x_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule