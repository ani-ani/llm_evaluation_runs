module degree_to_radian(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] degree_in,
    output reg signed [31:0] radian_out,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] MULT1    = 2'd1;
    localparam [1:0] MULT2    = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    // Fixed-point constants (Q16.16 format)
    localparam signed [31:0] PI_CONST     = 32'sh3243F6A8;  // 3.141592653589793
    localparam signed [31:0] INV_180      = 32'sh0002E14F;  // 0.005555555555556

    // Internal registers
    reg [1:0] state, next_state;
    reg signed [47:0] mult1_result;  // 16x16 = 32-bit, but we need 48-bit for proper shifting
    reg signed [31:0] mult2_result;
    reg signed [31:0] temp_result;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            radian_out <= 32'd0;
            done <= 1'b0;
            mult1_result <= 48'd0;
            mult2_result <= 32'd0;
            temp_result <= 32'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= MULT1;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                MULT1: begin
                    // First multiplication: degree_in (Q8.8) * PI (Q16.16)
                    // Convert degree_in to Q16.16 by shifting left 8 bits
                    mult1_result <= $signed({16'd0, degree_in}) * PI_CONST;
                    next_state <= MULT2;
                end

                MULT2: begin
                    // Shift right by 16 bits to get Q16.16 result
                    temp_result <= mult1_result[47:16];
                    
                    // Second multiplication with 1/180
                    mult2_result <= temp_result * INV_180;
                    next_state <= FINISH;
                end

                FINISH: begin
                    // Final result is Q16.16 format
                    radian_out <= mult2_result;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule