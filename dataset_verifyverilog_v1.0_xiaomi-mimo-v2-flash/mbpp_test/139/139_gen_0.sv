module circumference_calculator (
    input clk,
    input rst_n,
    input start,
    input [7:0] radius,
    output reg signed [23:0] circumference,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Fixed-point constants
    localparam signed [16:0] PI_FIXED = 17'd205887;  // 3.141592653589793 * 65536
    localparam signed [16:0] TWO_FIXED = 17'd131072; // 2.0 * 65536

    // Internal registers
    reg [1:0] state;
    reg [7:0] radius_reg;
    reg signed [23:0] temp_mult;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            radius_reg <= 8'd0;
            circumference <= 24'sd0;
            temp_mult <= 24'sd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    circumference <= 24'sd0;
                    if (start) begin
                        radius_reg <= radius;
                        state <= CALC;
                    end
                end

                CALC: begin
                    // Calculate: circumference = (radius * PI_FIXED) << 1
                    // radius is 8-bit unsigned, PI_FIXED is 17-bit signed
                    // Product: 8 + 17 = 25 bits, stored in 24-bit signed register
                    // Multiply by 2 (shift left by 1) to get 24-bit result
                    temp_mult <= $signed(radius_reg) * PI_FIXED;
                    circumference <= ($signed(radius_reg) * PI_FIXED) <<< 1;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule