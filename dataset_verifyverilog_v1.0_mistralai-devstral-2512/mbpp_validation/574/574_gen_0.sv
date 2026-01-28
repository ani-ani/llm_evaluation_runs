module cylinder_surface_area(
    input clk,
    input rst_n,
    input start,
    input [15:0] r,
    input [15:0] h,
    output reg [31:0] result,
    output reg done
);

    // Fixed-point constants
    localparam [31:0] PI_Q16_16 = 32'h0003243F;  // 3.1415926535 * 65536

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;

    reg [2:0] state;
    reg [15:0] r_plus_h;
    reg [31:0] pi_times_r;
    reg [31:0] two_times_pi_times_r;
    reg [31:0] final_result;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            r_plus_h <= 16'd0;
            pi_times_r <= 32'd0;
            two_times_pi_times_r <= 32'd0;
            final_result <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Stage 1: Compute r + h
                    r_plus_h <= r + h;

                    // Stage 2: Compute pi * r (32-bit multiplication)
                    pi_times_r <= PI_Q16_16 * r;

                    // Stage 3: Compute 2 * (pi * r) (left shift by 1)
                    two_times_pi_times_r <= pi_times_r << 1;

                    // Stage 4: Compute final result (2 * pi * r * (r + h))
                    final_result <= two_times_pi_times_r * r_plus_h;

                    state <= OUTPUT;
                end

                OUTPUT: begin
                    result <= final_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule