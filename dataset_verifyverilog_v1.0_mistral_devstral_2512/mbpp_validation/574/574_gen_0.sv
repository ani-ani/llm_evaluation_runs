module cylinder_surface_area(
    input clk,
    input rst_n,
    input start,
    input [15:0] radius,
    input [15:0] height,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_R_SQUARED = 3'd1;
    localparam [2:0] CALC_TERM1 = 3'd2;
    localparam [2:0] CALC_TERM2 = 3'd3;
    localparam [2:0] OUTPUT = 3'd4;

    // Fixed-point constants
    localparam [15:0] PI_FIXED = 16'd804;  // Q8.8 representation of π

    // Internal registers
    reg [2:0] state;
    reg [31:0] r_squared;  // Q16.16 format
    reg [31:0] term1;      // Q16.16 format
    reg [31:0] term2;      // Q16.16 format
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            r_squared <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CALC_R_SQUARED;
                    end
                end

                CALC_R_SQUARED: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Calculate r² with 32-bit precision
                    // radius is Q8.8, so r² is Q16.16
                    r_squared <= $signed(radius) * $signed(radius);
                    state <= CALC_TERM1;
                end

                CALC_TERM1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // term1 = 2 * π * r² (Q16.16)
                    // PI_FIXED is Q8.8, r_squared is Q16.16
                    // Multiply gives Q24.24, take upper 32 bits (Q16.16)
                    term1 <= (r_squared * $signed(PI_FIXED)) << 1;
                    state <= CALC_TERM2;
                end

                CALC_TERM2: begin
                    cycle_count <= cycle_count + 8'd1;
                    // term2 = 2 * π * r * h (Q16.16)
                    // radius and height are Q8.8, product is Q16.16
                    // Multiply by PI_FIXED (Q8.8) gives Q24.24, take upper 32 bits
                    term2 <= ($signed(radius) * $signed(height) * $signed(PI_FIXED)) << 1;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    // Final result = term1 + term2 (Q16.16)
                    result <= term1 + term2;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                state <= IDLE;
                done <= 1'b0;
            end
        end
    end
endmodule