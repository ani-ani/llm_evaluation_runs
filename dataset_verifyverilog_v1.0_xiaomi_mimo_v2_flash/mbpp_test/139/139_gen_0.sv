module circle_circumference (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] radius,
    output wire [31:0] circumference,
    output wire done
);

// Constants (Q16.16 format)
// pi = 3.141592653589793 * 2^16 = 205887
localparam [31:0] PI_FIXED = 32'd205887;
// 2.0 * 2^16 = 131072
localparam [31:0] TWO_FIXED = 32'd131072;

// State definitions
localparam [2:0] IDLE  = 3'd0;
localparam [2:0] CALC1 = 3'd1;  // Compute 2 * pi
localparam [2:0] CALC2 = 3'd2;  // Multiply by radius
localparam [2:0] DONE  = 3'd3;

// Internal registers
reg [2:0] state;
reg [31:0] result_reg;
reg done_reg;
reg [31:0] mult1_result;

// Computation logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
        mult1_result <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done_reg <= 1'b0;
                if (start) begin
                    state <= CALC1;
                    // Calculate 2 * pi (scaled to maintain Q16.16 format)
                    mult1_result <= TWO_FIXED * PI_FIXED;
                end
            end
            
            CALC1: begin
                state <= CALC2;
                // Multiply by radius (convert radius to Q16.16 by shifting left 8 bits)
                // radius is Q8.8, multiply by Q32.16 gives Q40.24, we need Q32.32
                // Actually: (2 * pi) is Q32.16, radius shifted left 8 is Q32.8
                // Result is Q64.24, we want Q32.16 after division
                // Simpler: (mult1_result * (radius << 8)) >> 16
                result_reg <= (mult1_result * (radius << 8)) >> 16;
            end
            
            CALC2: begin
                state <= DONE;
                // Result already computed in CALC1
            end
            
            DONE: begin
                done_reg <= 1'b1;
                if (!start) begin
                    state <= IDLE;
                end
            end
            
            default: state <= IDLE;
        endcase
    end
end

// Assign outputs
assign done = done_reg;
assign circumference = result_reg;

endmodule