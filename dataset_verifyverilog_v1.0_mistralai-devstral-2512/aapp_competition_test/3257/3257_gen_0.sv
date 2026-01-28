module EquilateralTriangleArea(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a_in,
    input wire [7:0] b_in,
    input wire [7:0] c_in,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH = 3'd1;
    localparam [2:0] CHECK = 3'd2;
    localparam [2:0] COMPUTE = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Input registers
    reg [7:0] a_reg, b_reg, c_reg;

    // Fixed-point values (Q16.16)
    reg [31:0] a_fp, b_fp, c_fp;
    reg [31:0] s_sq_low, s_sq_high, s_sq_mid;
    reg [31:0] s_sq_result;
    reg [31:0] a_sq, b_sq, c_sq;
    reg [31:0] sum_sq, sum_4th;
    reg [31:0] lhs, rhs;
    reg [31:0] temp1, temp2, temp3;

    // Precomputed constants
    localparam [31:0] SQRT3_OVER_4 = 32'd28378; // Q16.16: 0.4330127 * 65536
    localparam [31:0] MAX_S_SQ = 32'd26214400; // 10000 * 256^2

    // Binary search iteration counter
    reg [3:0] iter_count;
    localparam [3:0] MAX_ITER = 4'd16;

    // Validity flag
    reg valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            c_reg <= 8'd0;
            a_fp <= 32'd0;
            b_fp <= 32'd0;
            c_fp <= 32'd0;
            s_sq_low <= 32'd0;
            s_sq_high <= 32'd0;
            s_sq_mid <= 32'd0;
            s_sq_result <= 32'd0;
            a_sq <= 32'd0;
            b_sq <= 32'd0;
            c_sq <= 32'd0;
            sum_sq <= 32'd0;
            sum_4th <= 32'd0;
            lhs <= 32'd0;
            rhs <= 32'd0;
            temp1 <= 32'd0;
            temp2 <= 32'd0;
            temp3 <= 32'd0;
            iter_count <= 4'd0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= LATCH;
                    end
                end

                LATCH: begin
                    a_reg <= a_in;
                    b_reg <= b_in;
                    c_reg <= c_in;
                    state <= CHECK;
                end

                CHECK: begin
                    // Scale inputs to Q16.16 (a_in * 256)
                    a_fp <= {a_reg, 8'd0};
                    b_fp <= {b_reg, 8'd0};
                    c_fp <= {c_reg, 8'd0};

                    // Check triangle inequalities (a + b > c, etc.)
                    // In fixed-point, compare (a + b) > c
                    if ((a_fp + b_fp) > c_fp && 
                        (a_fp + c_fp) > b_fp && 
                        (b_fp + c_fp) > a_fp) begin
                        valid <= 1'b1;
                    end else begin
                        valid <= 1'b0;
                    end

                    // Initialize binary search bounds
                    s_sq_low <= 32'd0;
                    s_sq_high <= MAX_S_SQ;
                    iter_count <= 4'd0;
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Binary search for s^2
                    s_sq_mid <= (s_sq_low + s_sq_high) >>> 1;

                    // Compute a^2, b^2, c^2
                    a_sq <= a_fp * a_fp;
                    b_sq <= b_fp * b_fp;
                    c_sq <= c_fp * c_fp;

                    // Compute sum of squares
                    sum_sq <= a_sq + b_sq + c_sq + s_sq_mid;

                    // Compute sum of fourth powers
                    temp1 <= a_sq * a_sq;
                    temp2 <= b_sq * b_sq;
                    temp3 <= c_sq * c_sq;
                    sum_4th <= temp1 + temp2 + temp3 + (s_sq_mid * s_sq_mid);

                    // Compute LHS: 3*(a^4 + b^4 + c^4 + s^4)
                    lhs <= sum_4th << 2; // Multiply by 3 (shift left by 1 and add)
                    lhs <= lhs + sum_4th;

                    // Compute RHS: (a^2 + b^2 + c^2 + s^2)^2
                    rhs <= sum_sq * sum_sq;

                    // Compare and adjust bounds
                    if (lhs > rhs) begin
                        s_sq_high <= s_sq_mid - 32'd1;
                    end else begin
                        s_sq_low <= s_sq_mid + 32'd1;
                    end

                    // Check if converged or max iterations reached
                    if (iter_count == MAX_ITER - 4'd1 || 
                        (s_sq_high - s_sq_low) < 32'd100) begin
                        s_sq_result <= s_sq_mid;
                        state <= FINISH;
                    end else begin
                        iter_count <= iter_count + 4'd1;
                    end

                    // Safety check for infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        valid <= 1'b0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (valid && s_sq_result > 32'd0) begin
                        // Compute area = (sqrt(3)/4) * s^2
                        result <= SQRT3_OVER_4 * s_sq_result;
                    end else begin
                        result <= 32'd4294967295; // -1 in 32-bit
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule