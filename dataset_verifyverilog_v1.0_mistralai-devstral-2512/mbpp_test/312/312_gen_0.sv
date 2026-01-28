module cone_volume(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] r,
    input wire signed [15:0] h,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] STAGE1  = 3'd1;
    localparam [2:0] STAGE2  = 3'd2;
    localparam [2:0] STAGE3  = 3'd3;
    localparam [2:0] STAGE4  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Fixed-point constants
    localparam signed [31:0] PI = 32'sd3243F;  // 3.14159 in Q16.16
    localparam signed [31:0] ONE_THIRD = 32'sd5555;  // 0.3333 in Q16.16

    // Pipeline registers
    reg [2:0] state;
    reg signed [31:0] r_squared;
    reg signed [31:0] r_squared_h;
    reg signed [31:0] r_squared_h_pi;
    reg signed [31:0] result_reg;
    reg [3:0] cycle_count;
    reg start_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            r_squared <= 32'sd0;
            r_squared_h <= 32'sd0;
            r_squared_h_pi <= 32'sd0;
            result_reg <= 32'sd0;
            cycle_count <= 4'd0;
            start_reg <= 1'b0;
            result <= 32'sd0;
            done <= 1'b0;
        end else begin
            // Register inputs
            start_reg <= start;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start_reg) begin
                        state <= STAGE1;
                        cycle_count <= 4'd1;
                    end
                end

                STAGE1: begin
                    // Compute r^2 (16x16 -> 32 bits)
                    r_squared <= $signed(r) * $signed(r);
                    state <= STAGE2;
                    cycle_count <= cycle_count + 4'd1;
                end

                STAGE2: begin
                    // Multiply r^2 by h (32x16 -> 32 bits, keep upper 32)
                    r_squared_h <= r_squared * $signed(h);
                    state <= STAGE3;
                    cycle_count <= cycle_count + 4'd1;
                end

                STAGE3: begin
                    // Multiply by PI (32x32 -> 32 bits, keep upper 32)
                    r_squared_h_pi <= r_squared_h * PI;
                    state <= STAGE4;
                    cycle_count <= cycle_count + 4'd1;
                end

                STAGE4: begin
                    // Multiply by 1/3 (32x32 -> 32 bits, keep upper 32)
                    result_reg <= r_squared_h_pi * ONE_THIRD;
                    state <= DONE_STATE;
                    cycle_count <= cycle_count + 4'd1;
                end

                DONE_STATE: begin
                    // Output result and done pulse
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule