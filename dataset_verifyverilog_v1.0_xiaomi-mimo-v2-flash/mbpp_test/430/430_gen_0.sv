module directrix_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] a,
    input wire signed [7:0] b,
    input wire signed [7:0] c,
    output reg signed [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE1 = 3'd2;
    localparam [2:0] COMPUTE2 = 3'd3;
    localparam [2:0] DIVIDE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg signed [7:0] a_reg, b_reg, c_reg;
    reg signed [15:0] numerator;
    reg signed [15:0] denominator;
    reg signed [15:0] quotient;
    reg signed [15:0] remainder;
    reg [3:0] cycle_count;
    reg sign_flag;

    // State transition and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            a_reg <= 8'sd0;
            b_reg <= 8'sd0;
            c_reg <= 8'sd0;
            numerator <= 16'sd0;
            denominator <= 16'sd0;
            quotient <= 16'sd0;
            remainder <= 16'sd0;
            cycle_count <= 4'd0;
            sign_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        a_reg <= a;
                        b_reg <= b;
                        c_reg <= c;
                        state <= LOAD;
                    end
                end

                LOAD: begin
                    // Calculate b^2 + 1 (both signed)
                    // b_reg is 8-bit signed, b^2 is 16-bit
                    // b^2 + 1
                    numerator <= ($signed(b_reg) * $signed(b_reg)) + 16'sd1;
                    // Calculate 4*a (signed 8-bit * 4 = signed 12-bit)
                    denominator <= $signed(a_reg) * 4'sd4;
                    state <= COMPUTE1;
                end

                COMPUTE1: begin
                    // Calculate c * 4 * a = (c * 4) * a
                    // c is 8-bit signed, 4*c is 12-bit signed
                    // Then multiply by a (8-bit) -> 20-bit result
                    // Store numerator for later
                    numerator <= $signed(c_reg) * 4'sd4;
                    state <= COMPUTE2;
                end

                COMPUTE2: begin
                    // numerator = (c * 4 * a) - (b^2 + 1)
                    numerator <= ($signed(numerator) * $signed(a_reg)) - numerator;
                    // denominator remains 4*a
                    state <= DIVIDE;
                    cycle_count <= 4'd0;
                    sign_flag <= 1'b0;
                    quotient <= 16'sd0;
                    remainder <= 16'sd0;
                end

                DIVIDE: begin
                    // Perform integer division: numerator / denominator
                    // Handle sign
                    if (numerator < 0) begin
                        sign_flag <= 1'b1;
                        numerator <= -numerator;
                    end
                    if (denominator < 0) begin
                        sign_flag <= ~sign_flag;
                        denominator <= -denominator;
                    end

                    if (denominator != 0) begin
                        // Simple shift-subtract division
                        remainder <= numerator;
                        quotient <= 16'sd0;
                        // Limit cycles to prevent timeout
                        cycle_count <= 4'd0;
                    end
                    state <= DIVIDE;
                end

                DIVIDE: begin
                    // Re-declare for division algorithm
                    // Check if we should continue division
                    if (denominator != 0 && remainder >= denominator && cycle_count < 15) begin
                        remainder <= remainder - denominator;
                        quotient <= quotient + 16'sd1;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        // Apply sign
                        if (sign_flag) begin
                            quotient <= -quotient;
                        end
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= quotient;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule