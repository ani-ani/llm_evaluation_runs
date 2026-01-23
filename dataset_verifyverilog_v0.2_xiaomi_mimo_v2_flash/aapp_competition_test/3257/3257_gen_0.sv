module carpet_area(
    input clk,
    input rst_n,
    input start,
    input [31:0] dist_a,
    input [31:0] dist_b,
    input [31:0] dist_c,
    output reg [31:0] area,
    output reg done
);

    // State definitions
    localparam IDLE = 4'b0000;
    localparam CHECK_VALIDITY = 4'b0001;
    localparam COMPUTE_SQUARED = 4'b0010;
    localparam SOLVE_QUADRATIC = 4'b0011;
    localparam VERIFY_INSIDE = 4'b0100;
    localparam COMPUTE_AREA = 4'b0101;
    localparam DONE = 4'b0110;

    // Constants (Q16.16)
    localparam [31:0] SQRT3 = 32'h0001BB67; // sqrt(3) = 1.73205
    localparam [31:0] ONE_HALF = 32'h00008000; // 0.5
    localparam [31:0] ONE = 32'h00010000; // 1.0
    localparam [31:0] NEG_ONE = 32'hFFFF0000; // -1.0

    // Registers for state and data
    reg [3:0] state;
    reg [3:0] next_state;
    reg [31:0] a_val, b_val, c_val;
    reg [31:0] a_sq, b_sq, c_sq;
    reg [31:0] a_4, b_4, c_4;
    reg [31:0] ab_sq, bc_sq, ca_sq;
    reg [63:0] Q; // Q = a^2 + b^2 + c^2 (Q32.32)
    reg [63:0] R; // R = a^4 + b^4 + c^4 - a^2*b^2 - ...
    reg [63:0] D; // Discriminant Q^2 - R
    reg [63:0] S_sq; // S^2 in Q32.32
    reg [63:0] temp_val;
    reg [63:0] temp_val2;
    reg [4:0] iter_cnt;
    reg [63:0] mult_a;
    reg [63:0] mult_b;
    reg [63:0] mult_result;
    reg [63:0] add_a;
    reg [63:0] add_b;
    reg [63:0] add_result;
    reg [63:0] sub_a;
    reg [63:0] sub_b;
    reg [63:0] sub_result;
    reg [63:0] div_numer;
    reg [63:0] div_denom;
    reg [63:0] div_result;
    reg valid_flag;
    reg inside_flag;

    // Multiplier (simple combinatorial for partial product)
    // For Q16.16 * Q16.16 = Q32.32
    always @(*) begin
        mult_result = mult_a[31:0] * mult_b[31:0];
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            area <= 32'h00000000;
            done <= 1'b0;
            a_val <= 32'd0;
            b_val <= 32'd0;
            c_val <= 32'd0;
            valid_flag <= 1'b0;
            inside_flag <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a_val <= dist_a;
                        b_val <= dist_b;
                        c_val <= dist_c;
                        state <= CHECK_VALIDITY;
                        iter_cnt <= 5'd0;
                    end
                end
                CHECK_VALIDITY: begin
                    if (dist_a == 32'd0 || dist_b == 32'd0 || dist_c == 32'd0) begin
                        state <= DONE;
                        area <= 32'hFFFFFFFF; // -1
                    end else begin
                        a_sq <= (dist_a[15:0] * dist_a[15:0]) << 16;
                        b_sq <= (dist_b[15:0] * dist_b[15:0]) << 16;
                        c_sq <= (dist_c[15:0] * dist_c[15:0]) << 16;
                        state <= COMPUTE_SQUARED;
                        iter_cnt <= 5'd0;
                    end
                end
                COMPUTE_SQUARED: begin
                    if (iter_cnt == 5'd0) begin
                        Q <= {16'd0, a_sq} + {16'd0, b_sq} + {16'd0, c_sq};
                        a_4 <= (a_sq[31:16] * a_sq[31:16]) << 16;
                        b_4 <= (b_sq[31:16] * b_sq[31:16]) << 16;
                        c_4 <= (c_sq[31:16] * c_sq[31:16]) << 16;
                        ab_sq <= (a_sq[31:16] * b_sq[31:16]) << 16;
                        bc_sq <= (b_sq[31:16] * c_sq[31:16]) << 16;
                        ca_sq <= (c_sq[31:16] * a_sq[31:16]) << 16;
                        iter_cnt <= 5'd1;
                    end else if (iter_cnt == 5'd1) begin
                        R <= {16'd0, a_4} + {16'd0, b_4} + {16'd0, c_4} - ({16'd0, ab_sq} + {16'd0, bc_sq} + {16'd0, ca_sq});
                        temp_val <= {16'd0, Q};
                        iter_cnt <= 5'd2;
                    end else if (iter_cnt == 5'd2) begin
                        state <= SOLVE_QUADRATIC;
                        iter_cnt <= 5'd0;
                    end
                end
                SOLVE_QUADRATIC: begin
                    if (iter_cnt == 5'd0) begin
                        mult_a <= {16'd0, Q[47:16]};
                        mult_b <= {16'd0, Q[47:16]};
                        iter_cnt <= 5'd1;
                    end else if (iter_cnt == 5'd1) begin
                        temp_val <= mult_result >> 16;
                        iter_cnt <= 5'd2;
                    end else if (iter_cnt == 5'd2) begin
                        temp_val2 <= temp_val - R;
                        iter_cnt <= 5'd3;
                    end else if (iter_cnt == 5'd3) begin
                        if (temp_val2[63]) begin
                            state <= DONE;
                            area <= 32'hFFFFFFFF;
                        end else begin
                            div_numer <= temp_val2 << 16;
                            div_denom <= {16'd0, Q[47:16]};
                            div_result <= 64'd0;
                            iter_cnt <= 5'd4;
                        end
                    end else if (iter_cnt >= 5'd4 && iter_cnt <= 5'd19) begin
                        if ({div_numer[62:0], 1'b0} >= div_denom) begin
                            div_numer <= {div_numer[62:0], 1'b0} - div_denom;
                            div_result <= {div_result[62:0], 1'b1};
                        end else begin
                            div_numer <= {div_numer[62:0], 1'b0};
                            div_result <= {div_result[62:0], 1'b0};
                        end
                        if (iter_cnt == 5'd19) begin
                            S_sq <= Q + div_result;
                            iter_cnt <= 5'd20;
                        end else begin
                            iter_cnt <= iter_cnt + 1;
                        end
                    end else if (iter_cnt == 5'd20) begin
                        temp_val <= S_sq;
                        state <= VERIFY_INSIDE;
                        iter_cnt <= 5'd0;
                    end
                end
                VERIFY_INSIDE: begin
                    if (temp_val > 0 && temp_val[63:32] < 10000) begin
                        state <= COMPUTE_AREA;
                        iter_cnt <= 5'd0;
                    end else begin
                        state <= DONE;
                        area <= 32'hFFFFFFFF;
                    end
                end
                COMPUTE_AREA: begin
                    if (iter_cnt == 5'd0) begin
                        mult_a <= {16'd0, temp_val[47:16]};
                        mult_b <= SQRT3;
                        iter_cnt <= 5'd1;
                    end else if (iter_cnt == 5'd1) begin
                        area <= mult_result[63:18];
                        state <= DONE;
                        done <= 1'b1;
                    end
                end
                DONE: begin
                    done <= 1'b1;
                    if (start == 0) begin
                    end
                end
            endcase
        end
    end
endmodule