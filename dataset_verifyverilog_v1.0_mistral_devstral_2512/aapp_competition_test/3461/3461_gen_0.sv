module stochastic_scheduling(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] s0, a0, b0,
    input wire [7:0] s1, a1, b1,
    input wire [7:0] s2, a2, b2,
    input wire [7:0] s3, a3, b3,
    input wire [7:0] s4, a4, b4,
    input wire [7:0] s5, a5, b5,
    input wire [7:0] s6, a6, b6,
    input wire [7:0] s7, a7, b7,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] START = 4'd1;
    localparam [3:0] COMPUTE_L = 4'd2;
    localparam [3:0] COMPUTE_J = 4'd3;
    localparam [3:0] NEXT_L = 4'd4;
    localparam [3:0] CALC_DP = 4'd5;
    localparam [3:0] NEXT_I = 4'd6;
    localparam [3:0] FIND_MAX = 4'd7;
    localparam [3:0] FIND_MAX_LOOP = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;

    // Internal registers
    reg [3:0] state;
    reg [3:0] i_idx;
    reg [3:0] j_idx;
    reg [7:0] L_val;
    reg [31:0] sum;
    reg [31:0] best_val;
    reg [8:0] t_val;
    reg [3:0] len_val;
    reg [15:0] rec_val;
    reg [63:0] product;
    reg [31:0] max_val;

    // Storage for hearings
    reg [7:0] s_reg [0:7];
    reg [7:0] a_reg [0:7];
    reg [7:0] b_reg [0:7];
    reg [31:0] dp_reg [0:7];

    integer idx;

    // Helper function to compute reciprocal of length (1/len) in Q16.16
    function [15:0] compute_rec;
        input [3:0] len;
        begin
            case (len)
                4'd1: compute_rec = 16'd65536;
                4'd2: compute_rec = 16'd32768;
                4'd3: compute_rec = 16'd21845;
                4'd4: compute_rec = 16'd16384;
                4'd5: compute_rec = 16'd13107;
                4'd6: compute_rec = 16'd10923;
                4'd7: compute_rec = 16'd9362;
                4'd8: compute_rec = 16'd8192;
                4'd9: compute_rec = 16'd7282;
                4'd10: compute_rec = 16'd6554;
                4'd11: compute_rec = 16'd5958;
                4'd12: compute_rec = 16'd5461;
                4'd13: compute_rec = 16'd5041;
                4'd14: compute_rec = 16'd4681;
                4'd15: compute_rec = 16'd4369;
                4'd16: compute_rec = 16'd4096;
                default: compute_rec = 16'd0;
            endcase
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            // Reset all arrays
            for (idx = 0; idx < 8; idx = idx + 1) begin
                s_reg[idx] <= 8'd0;
                a_reg[idx] <= 8'd0;
                b_reg[idx] <= 8'd0;
                dp_reg[idx] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load inputs into registers
                        s_reg[0] <= s0; a_reg[0] <= a0; b_reg[0] <= b0;
                        s_reg[1] <= s1; a_reg[1] <= a1; b_reg[1] <= b1;
                        s_reg[2] <= s2; a_reg[2] <= a2; b_reg[2] <= b2;
                        s_reg[3] <= s3; a_reg[3] <= a3; b_reg[3] <= b3;
                        s_reg[4] <= s4; a_reg[4] <= a4; b_reg[4] <= b4;
                        s_reg[5] <= s5; a_reg[5] <= a5; b_reg[5] <= b5;
                        s_reg[6] <= s6; a_reg[6] <= a6; b_reg[6] <= b6;
                        s_reg[7] <= s7; a_reg[7] <= a7; b_reg[7] <= b7;
                        // Reset dp
                        for (idx = 0; idx < 8; idx = idx + 1) begin
                            dp_reg[idx] <= 32'd0;
                        end
                        // Initialize loop variables
                        i_idx <= (n > 0) ? n - 1 : 4'd0;
                        state <= START;
                    end
                end

                START: begin
                    if (i_idx < 0 || i_idx >= n) begin
                        // All i done, go to find max
                        state <= FIND_MAX;
                    end else begin
                        sum <= 32'd0;
                        L_val <= a_reg[i_idx];
                        state <= COMPUTE_L;
                    end
                end

                COMPUTE_L: begin
                    if (L_val > b_reg[i_idx]) begin
                        // Finished all L for this i, compute dp
                        len_val <= b_reg[i_idx] - a_reg[i_idx] + 1;
                        rec_val <= compute_rec(b_reg[i_idx] - a_reg[i_idx] + 1);
                        state <= CALC_DP;
                    end else begin
                        // Compute best over j
                        t_val <= s_reg[i_idx] + L_val;
                        best_val <= 32'd0;
                        j_idx <= 4'd0;
                        state <= COMPUTE_J;
                    end
                end

                COMPUTE_J: begin
                    if (j_idx >= n) begin
                        // Done with j loop, add best to sum
                        sum <= sum + best_val;
                        state <= NEXT_L;
                    end else begin
                        // Check if s_reg[j_idx] >= t_val and dp_reg[j_idx] > best_val
                        if (s_reg[j_idx] >= t_val && dp_reg[j_idx] > best_val) begin
                            best_val <= dp_reg[j_idx];
                        end
                        j_idx <= j_idx + 1;
                        state <= COMPUTE_J;
                    end
                end

                NEXT_L: begin
                    L_val <= L_val + 1;
                    state <= COMPUTE_L;
                end

                CALC_DP: begin
                    // dp[i] = 1 + (sum * rec) >> 16
                    // sum is Q16.16, rec is Q16.16
                    product <= sum * rec_val;
                    dp_reg[i_idx] <= 32'd65536 + (product >> 16);
                    state <= NEXT_I;
                end

                NEXT_I: begin
                    i_idx <= i_idx - 1;
                    state <= START;
                end

                FIND_MAX: begin
                    max_val <= 32'd0;
                    i_idx <= 4'd0;
                    state <= FIND_MAX_LOOP;
                end

                FIND_MAX_LOOP: begin
                    if (i_idx >= n) begin
                        result <= max_val;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end else begin
                        if (dp_reg[i_idx] > max_val) begin
                            max_val <= dp_reg[i_idx];
                        end
                        i_idx <= i_idx + 1;
                        state <= FIND_MAX_LOOP;
                    end
                end

                DONE_STATE: begin
                    if (!start) begin
                        done <= 1'b0;
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule