module rect_intersection_area (
    input clk,
    input rst_n,
    input start,
    input [15:0] w,
    input [15:0] h,
    input [15:0] alpha_deg,
    output reg [31:0] area,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE = 3'b001;
    localparam CALCULATE = 3'b010;
    localparam DONE = 3'b011;

    // Internal registers
    reg [2:0] state;
    reg [9:0] counter; // Counter for computation steps (up to 1024)
    reg [15:0] w_reg;
    reg [15:0] h_reg;
    reg [15:0] alpha_reg;
    reg [15:0] alpha_norm;
    reg [31:0] A; // max(w,h)
    reg [31:0] B; // min(w,h)
    reg [31:0] t; // tan(alpha/2)
    reg [31:0] sin_alpha;
    reg [31:0] tan_alpha;
    reg [31:0] x_rad; // alpha in radians
    reg [31:0] x_half_rad; // alpha/2 in radians
    reg [63:0] x_sq; // x^2
    reg [63:0] x_cub; // x^3
    reg [63:0] x_quad; // x^4
    reg [63:0] mul_temp;
    reg [63:0] sub_temp;
    reg [63:0] add_temp;
    reg [63:0] x_temp1;
    reg [63:0] x_temp2;
    reg [63:0] x_temp3;
    reg [31:0] x_div_rem;
    reg [31:0] x_div_den;
    reg [31:0] x_div_quot;
    // Constants
    localparam PI = 32'h0003243F; // ~3.14159
    localparam ONE = 32'h00010000;
    localparam C_DIV_6 = 32'h00002AAA; // 1/6
    localparam C_DIV_3 = 32'h00005555; // 1/3
    localparam C_DIV_120 = 32'h00000222; // 1/120
    localparam DEG_TO_RAD_Q16 = 32'h00000478; // PI/180 approx 0.0174533 in Q16.16 is 0x0000478

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            area <= 0;
            counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    counter <= 0;
                    if (start) begin
                        state <= PRECOMPUTE;
                        w_reg <= w;
                        h_reg <= h;
                        alpha_reg <= alpha_deg;
                    end
                end

                PRECOMPUTE: begin
                    // Normalize angle: alpha = min(alpha, 180-alpha)
                    if (alpha_reg <= (32'd180 * 65536 - alpha_reg)) begin
                        alpha_norm <= alpha_reg;
                    end else begin
                        alpha_norm <= (32'd180 * 65536) - alpha_reg;
                    end
                    // Determine A and B (Q16.16 values)
                    if (w >= h) begin
                        A <= {w_reg, 16'h0000};
                        B <= {h_reg, 16'h0000};
                    end else begin
                        A <= {h_reg, 16'h0000};
                        B <= {w_reg, 16'h0000};
                    end
                    state <= CALCULATE;
                    counter <= 0;
                end

                CALCULATE: begin
                    // Trigonometry Calculation Sequence (0-14)
                    if (counter == 0) begin
                        mul_temp <= alpha_norm * DEG_TO_RAD_Q16;
                        counter <= 1;
                    end else if (counter == 1) begin
                        x_rad <= mul_temp[47:16];
                        mul_temp <= (alpha_norm >> 1) * DEG_TO_RAD_Q16;
                        counter <= 2;
                    end else if (counter == 2) begin
                        x_half_rad <= mul_temp[47:16];
                        counter <= 3;
                    end else if (counter == 3) begin
                        mul_temp <= x_half_rad * x_half_rad;
                        x_sq <= x_rad * x_rad;
                        counter <= 4;
                    end else if (counter == 4) begin
                        x_cub <= mul_temp[47:16]; // x_half_sq stored in x_cub temporarily
                        mul_temp <= mul_temp[47:16] * x_half_rad; // x_half_cub
                        x_sq <= x_sq[47:16] * x_rad; // x_cub (rad)
                        counter <= 5;
                    end else if (counter == 5) begin
                        // Store x_half_cub in x_cub (overwrite temp)
                        x_cub <= mul_temp[47:16];
                        // Calculate x_rad^5
                        // x_sq holds x_cub (rad)
                        // We need x_rad^3 * x_rad^2.
                        // Let's just recalculate x_rad^2 in x_quad
                        // Actually, x_sq currently holds x_cub (rad). Let's use x_quad for x_rad^2.
                        // To simplify, let's do:
                        // x_quad = x_rad^2 (from x_rad * x_rad)
                        // x_cub = x_rad^3
                        // x_add = x_rad^5
                        x_quad <= x_rad * x_rad;
                        x_cub <= x_quad * x_rad;
                        x_temp1 <= x_cub * x_quad;
                        counter <= 6;
                    end else if (counter == 6) begin
                        // Calculate t = x_half + x_half_cub/3
                        mul_temp <= x_cub * C_DIV_3;
                        x_cub <= x_half_rad << 16;
                        t <= x_cub + mul_temp[47:16];
                        counter <= 7;
                    end else if (counter == 7) begin
                        // Calculate sin_alpha terms
                        mul_temp <= x_cub * C_DIV_6;
                        x_sq <= mul_temp[47:16]; // x_sq holds term2_s
                        mul_temp <= x_temp1 * C_DIV_120;
                        counter <= 8;
                    end else if (counter == 8) begin
                        // Calculate sin_alpha = x_rad - term2_s + term3_s
                        sub_temp <= x_rad - x_sq;
                        x_sq <= mul_temp[47:16];
                        sin_alpha <= sub_temp[31:0] + x_sq;
                        counter <= 9;
                    end else if (counter == 9) begin
                        // Calculate tan_alpha = x_rad + x_rad^3/3
                        mul_temp <= x_cub * C_DIV_3;
                        tan_alpha <= x_rad + mul_temp[47:16];
                        counter <= 10;
                    end else if (counter == 10) begin
                        // Check special cases
                        if (alpha_norm == 0) begin
                            mul_temp <= A * B;
                            counter <= 20;
                        end else if (alpha_norm == (90 << 16)) begin
                            mul_temp <= B * B;
                            counter <= 20;
                        end else if ((t * A) > {B, 16'h0000}) begin
                            // Prepare Division: (B^2 / sin_alpha)
                            mul_temp <= B * B;
                            x_sq <= sin_alpha;
                            x_div_rem <= mul_temp[47:16]; // N (Q16.16)
                            x_div_den <= x_sq; // D (Q16.16)
                            x_div_quot <= 0;
                            counter <= 200;
                        end else begin
                            // t <= B/A
                            x_temp3 <= A * B;
                            mul_temp <= B * t;
                            x_cub <= A * t;
                            counter <= 100;
                        end
                    end else if (counter >= 200 && counter < 216) begin
                        // Division Loop
                        if (x_div_rem >= x_div_den) begin
                            x_div_rem <= (x_div_rem - x_div_den) << 1;
                            x_div_quot <= (x_div_quot << 1) | 1;
                        end else begin
                            x_div_rem <= x_div_rem << 1;
                            x_div_quot <= x_div_quot << 1;
                        end
                        if (counter == 215) begin
                            if (x_div_rem >= x_div_den) begin
                                x_div_quot <= (x_div_quot << 1) | 1;
                                x_div_rem <= x_div_rem - x_div_den;
                            end else begin
                                x_div_quot <= x_div_quot << 1;
                            end
                            area <= x_div_quot;
                            state <= DONE;
                            done <= 1;
                        end else begin
                            counter <= counter + 1;
                        end
                    end else if (counter == 100) begin
                        // Calculate (A - B*t)^2 and (B - A*t)^2
                        x_temp1 <= {A, 16'h0000};
                        x_temp2 <= {B, 16'h0000};
                        counter <= 101;
                    end else if (counter == 101) begin
                        // Subtraction
                        x_temp1 <= x_temp1 - mul_temp;
                        x_temp2 <= x_temp2 - x_cub;
                        counter <= 102;
                    end else if (counter == 102) begin
                        // Square sub1 and sub2
                        mul_temp <= x_temp1 * x_temp1;
                        x_temp3 <= x_temp2;
                        counter <= 103;
                    end else if (counter == 103) begin
                        // Save sq1 and square sub2
                        x_div_rem <= mul_temp[63:0];
                        mul_temp <= x_temp3 * x_temp3;
                        counter <= 104;
                    end else if (counter == 104) begin
                        // Add sq1 + sq2
                        x_div_rem <= x_div_rem + mul_temp;
                        mul_temp <= x_div_rem * tan_alpha;
                        counter <= 105;
                    end else if (counter == 105) begin
                        // Shift right 2
                        x_div_rem <= mul_temp >> 2;
                        counter <= 106;
                    end else if (counter == 106) begin
                        // Final subtraction: A*B - (term/4)
                        sub_temp <= x_temp3 - {18'b0, x_div_rem[63:46]};
                        counter <= 107;
                    end else if (counter == 107) begin
                        // Final result
                        area <= sub_temp[47:16];
                        state <= DONE;
                        done <= 1;
                    end else if (counter == 20) begin
                        // Special cases (alpha 0 or 90)
                        area <= mul_temp[47:16];
                        state <= DONE;
                        done <= 1;
                    end
                end
            endcase
        end
    end
endmodule