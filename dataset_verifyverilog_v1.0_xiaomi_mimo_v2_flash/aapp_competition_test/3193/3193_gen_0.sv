module solve_linear_congruence (
    input clk,
    input rst_n,
    input start,
    input signed [31:0] a,
    input signed [31:0] b,
    input [31:0] P,
    input [31:0] M,
    output reg [31:0] x,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] INCREMENT = 3'd2;
    localparam [2:0] FOUND     = 3'd3;
    localparam [2:0] NOT_FOUND = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [31:0] x_reg;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd256; // Hardware limit for iteration

    // Intermediate computation values (combinational)
    wire signed [63:0] product;
    wire signed [63:0] sum;
    wire signed [31:0] mod_result;
    wire [31:0] unsigned_value;

    // Combinational logic for equation evaluation
    // (a * x + b) % M
    assign product = a * x_reg;
    assign sum = product + b;
    assign mod_result = sum % $signed({1'b0, M});
    
    // Convert signed mod result to unsigned for comparison
    // Handle negative results by adding M
    assign unsigned_value = (mod_result < 0) ? mod_result + $signed({1'b0, M}) : mod_result;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            x_reg <= 32'd0;
            x <= 32'd0;
            done <= 1'b0;
            cycle_count <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        x_reg <= 32'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Check if current x_reg satisfies the equation
                    if (unsigned_value == P) begin
                        x <= x_reg;
                        state <= FOUND;
                    end else if (x_reg >= (M - 32'd1)) begin
                        // Reached upper bound (M-1) without finding solution
                        state <= NOT_FOUND;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Hardware timeout protection
                        state <= NOT_FOUND;
                    end else begin
                        state <= INCREMENT;
                    end
                end

                INCREMENT: begin
                    x_reg <= x_reg + 32'd1;
                    cycle_count <= cycle_count + 32'd1;
                    state <= CHECK;
                end

                FOUND: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                NOT_FOUND: begin
                    x <= 32'hFFFFFFFF; // Indicate failure
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule