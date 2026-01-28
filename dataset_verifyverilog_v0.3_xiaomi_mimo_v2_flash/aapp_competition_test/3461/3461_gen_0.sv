module stochastic_scheduling (
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

// State definitions
localparam [4:0] IDLE = 5'd0;
localparam [4:0] START = 5'd1;
localparam [4:0] COMPUTE_L = 5'd2;
localparam [4:0] COMPUTE_J = 5'd3;
localparam [4:0] NEXT_L = 5'd4;
localparam [4:0] CALC_DP = 5'd5;
localparam [4:0] NEXT_I = 5'd6;
localparam [4:0] FIND_MAX = 5'd7;
localparam [4:0] FIND_MAX_LOOP = 5'd8;
localparam [4:0] DONE_STATE = 5'd9;

// Internal registers
reg [4:0] state;
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
reg [7:0] s_reg_0;
reg [7:0] s_reg_1;
reg [7:0] s_reg_2;
reg [7:0] s_reg_3;
reg [7:0] s_reg_4;
reg [7:0] s_reg_5;
reg [7:0] s_reg_6;
reg [7:0] s_reg_7;

reg [7:0] a_reg_0;
reg [7:0] a_reg_1;
reg [7:0] a_reg_2;
reg [7:0] a_reg_3;
reg [7:0] a_reg_4;
reg [7:0] a_reg_5;
reg [7:0] a_reg_6;
reg [7:0] a_reg_7;

reg [7:0] b_reg_0;
reg [7:0] b_reg_1;
reg [7:0] b_reg_2;
reg [7:0] b_reg_3;
reg [7:0] b_reg_4;
reg [7:0] b_reg_5;
reg [7:0] b_reg_6;
reg [7:0] b_reg_7;

reg [31:0] dp_reg_0;
reg [31:0] dp_reg_1;
reg [31:0] dp_reg_2;
reg [31:0] dp_reg_3;
reg [31:0] dp_reg_4;
reg [31:0] dp_reg_5;
reg [31:0] dp_reg_6;
reg [31:0] dp_reg_7;

// Helper wires to access reg arrays
wire [7:0] s_reg [0:7];
wire [7:0] a_reg [0:7];
wire [7:0] b_reg [0:7];
wire [31:0] dp_reg [0:7];

assign s_reg[0] = s_reg_0;
assign s_reg[1] = s_reg_1;
assign s_reg[2] = s_reg_2;
assign s_reg[3] = s_reg_3;
assign s_reg[4] = s_reg_4;
assign s_reg[5] = s_reg_5;
assign s_reg[6] = s_reg_6;
assign s_reg[7] = s_reg_7;

assign a_reg[0] = a_reg_0;
assign a_reg[1] = a_reg_1;
assign a_reg[2] = a_reg_2;
assign a_reg[3] = a_reg_3;
assign a_reg[4] = a_reg_4;
assign a_reg[5] = a_reg_5;
assign a_reg[6] = a_reg_6;
assign a_reg[7] = a_reg_7;

assign b_reg[0] = b_reg_0;
assign b_reg[1] = b_reg_1;
assign b_reg[2] = b_reg_2;
assign b_reg[3] = b_reg_3;
assign b_reg[4] = b_reg_4;
assign b_reg[5] = b_reg_5;
assign b_reg[6] = b_reg_6;
assign b_reg[7] = b_reg_7;

assign dp_reg[0] = dp_reg_0;
assign dp_reg[1] = dp_reg_1;
assign dp_reg[2] = dp_reg_2;
assign dp_reg[3] = dp_reg_3;
assign dp_reg[4] = dp_reg_4;
assign dp_reg[5] = dp_reg_5;
assign dp_reg[6] = dp_reg_6;
assign dp_reg[7] = dp_reg_7;

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        result <= 32'd0;
        // Reset all registers
        s_reg_0 <= 8'd0; s_reg_1 <= 8'd0; s_reg_2 <= 8'd0; s_reg_3 <= 8'd0;
        s_reg_4 <= 8'd0; s_reg_5 <= 8'd0; s_reg_6 <= 8'd0; s_reg_7 <= 8'd0;
        a_reg_0 <= 8'd0; a_reg_1 <= 8'd0; a_reg_2 <= 8'd0; a_reg_3 <= 8'd0;
        a_reg_4 <= 8'd0; a_reg_5 <= 8'd0; a_reg_6 <= 8'd0; a_reg_7 <= 8'd0;
        b_reg_0 <= 8'd0; b_reg_1 <= 8'd0; b_reg_2 <= 8'd0; b_reg_3 <= 8'd0;
        b_reg_4 <= 8'd0; b_reg_5 <= 8'd0; b_reg_6 <= 8'd0; b_reg_7 <= 8'd0;
        dp_reg_0 <= 32'd0; dp_reg_1 <= 32'd0; dp_reg_2 <= 32'd0; dp_reg_3 <= 32'd0;
        dp_reg_4 <= 32'd0; dp_reg_5 <= 32'd0; dp_reg_6 <= 32'd0; dp_reg_7 <= 32'd0;
        i_idx <= 4'd0;
        j_idx <= 4'd0;
        L_val <= 8'd0;
        sum <= 32'd0;
        best_val <= 32'd0;
        t_val <= 9'd0;
        len_val <= 4'd0;
        rec_val <= 16'd0;
        product <= 64'd0;
        max_val <= 32'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    // Load inputs into registers
                    s_reg_0 <= s0; a_reg_0 <= a0; b_reg_0 <= b0;
                    s_reg_1 <= s1; a_reg_1 <= a1; b_reg_1 <= b1;
                    s_reg_2 <= s2; a_reg_2 <= a2; b_reg_2 <= b2;
                    s_reg_3 <= s3; a_reg_3 <= a3; b_reg_3 <= b3;
                    s_reg_4 <= s4; a_reg_4 <= a4; b_reg_4 <= b4;
                    s_reg_5 <= s5; a_reg_5 <= a5; b_reg_5 <= b5;
                    s_reg_6 <= s6; a_reg_6 <= a6; b_reg_6 <= b6;
                    s_reg_7 <= s7; a_reg_7 <= a7; b_reg_7 <= b7;
                    // Reset dp
                    dp_reg_0 <= 32'd0; dp_reg_1 <= 32'd0; dp_reg_2 <= 32'd0; dp_reg_3 <= 32'd0;
                    dp_reg_4 <= 32'd0; dp_reg_5 <= 32'd0; dp_reg_6 <= 32'd0; dp_reg_7 <= 32'd0;
                    // Initialize loop variables
                    if (n > 0) begin
                        i_idx <= n - 1'b1;
                    end else begin
                        i_idx <= 4'd0;
                    end
                    state <= START;
                end
            end

            START: begin
                if (i_idx >= n) begin
                    // All i done, go to find max
                    state <= FIND_MAX;
                end else begin
                    sum <= 32'd0;
                    // Get a and b for current i
                    case (i_idx)
                        4'd0: begin L_val <= a_reg_0; end
                        4'd1: begin L_val <= a_reg_1; end
                        4'd2: begin L_val <= a_reg_2; end
                        4'd3: begin L_val <= a_reg_3; end
                        4'd4: begin L_val <= a_reg_4; end
                        4'd5: begin L_val <= a_reg_5; end
                        4'd6: begin L_val <= a_reg_6; end
                        4'd7: begin L_val <= a_reg_7; end
                        default: begin L_val <= 8'd0; end
                    endcase
                    state <= COMPUTE_L;
                end
            end

            COMPUTE_L: begin
                // Get b for current i
                case (i_idx)
                    4'd0: begin if (L_val > b_reg_0) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd1: begin if (L_val > b_reg_1) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd2: begin if (L_val > b_reg_2) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd3: begin if (L_val > b_reg_3) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd4: begin if (L_val > b_reg_4) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd5: begin if (L_val > b_reg_5) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd6: begin if (L_val > b_reg_6) state <= CALC_DP; else state <= COMPUTE_J; end
                    4'd7: begin if (L_val > b_reg_7) state <= CALC_DP; else state <= COMPUTE_J; end
                    default: begin state <= CALC_DP; end
                endcase
                
                if (state == COMPUTE_J) begin
                    // Get b for current i
                    case (i_idx)
                        4'd0: begin t_val <= s_reg_0 + L_val; end
                        4'd1: begin t_val <= s_reg_1 + L_val; end
                        4'd2: begin t_val <= s_reg_2 + L_val; end
                        4'd3: begin t_val <= s_reg_3 + L_val; end
                        4'd4: begin t_val <= s_reg_4 + L_val; end
                        4'd5: begin t_val <= s_reg_5 + L_val; end
                        4'd6: begin t_val <= s_reg_6 + L_val; end
                        4'd7: begin t_val <= s_reg_7 + L_val; end
                        default: begin t_val <= 9'd0; end
                    endcase
                    best_val <= 32'd0;
                    j_idx <= 4'd0;
                end
                if (state == CALC_DP) begin
                    // Calculate length
                    case (i_idx)
                        4'd0: begin len_val <= b_reg_0 - a_reg_0 + 1'b1; end
                        4'd1: begin len_val <= b_reg_1 - a_reg_1 + 1'b1; end
                        4'd2: begin len_val <= b_reg_2 - a_reg_2 + 1'b1; end
                        4'd3: begin len_val <= b_reg_3 - a_reg_3 + 1'b1; end
                        4'd4: begin len_val <= b_reg_4 - a_reg_4 + 1'b1; end
                        4'd5: begin len_val <= b_reg_5 - a_reg_5 + 1'b1; end
                        4'd6: begin len_val <= b_reg_6 - a_reg_6 + 1'b1; end
                        4'd7: begin len_val <= b_reg_7 - a_reg_7 + 1'b1; end
                        default: begin len_val <= 4'd0; end
                    endcase
                end
            end

            COMPUTE_J: begin
                if (j_idx >= n) begin
                    // Done with j loop, add best to sum
                    sum <= sum + best_val;
                    state <= NEXT_L;
                end else begin
                    // Check if s_reg[j_idx] >= t_val and dp_reg[j_idx] > best_val
                    if (dp_reg[j_idx] > best_val) begin
                        // Get s for current j
                        case (j_idx)
                            4'd0: begin if (s_reg_0 >= t_val[7:0]) best_val <= dp_reg_0; end
                            4'd1: begin if (s_reg_1 >= t_val[7:0]) best_val <= dp_reg_1; end
                            4'd2: begin if (s_reg_2 >= t_val[7:0]) best_val <= dp_reg_2; end
                            4'd3: begin if (s_reg_3 >= t_val[7:0]) best_val <= dp_reg_3; end
                            4'd4: begin if (s_reg_4 >= t_val[7:0]) best_val <= dp_reg_4; end
                            4'd5: begin if (s_reg_5 >= t_val[7:0]) best_val <= dp_reg_5; end
                            4'd6: begin if (s_reg_6 >= t_val[7:0]) best_val <= dp_reg_6; end
                            4'd7: begin if (s_reg_7 >= t_val[7:0]) best_val <= dp_reg_7; end
                            default: begin end
                        endcase
                    end
                    j_idx <= j_idx + 1'b1;
                    state <= COMPUTE_J;
                end
            end

            NEXT_L: begin
                L_val <= L_val + 1'b1;
                state <= COMPUTE_L;
            end

            CALC_DP: begin
                // dp[i] = 1 + (sum * rec) >> 16
                // sum is Q16.16, rec is Q16.16
                rec_val <= compute_rec(len_val);
                product <= sum * rec_val;
                state <= NEXT_I;
            end

            NEXT_I: begin
                // Store dp result
                case (i_idx)
                    4'd0: begin dp_reg_0 <= 32'd65536 + (product >> 16); end
                    4'd1: begin dp_reg_1 <= 32'd65536 + (product >> 16); end
                    4'd2: begin dp_reg_2 <= 32'd65536 + (product >> 16); end
                    4'd3: begin dp_reg_3 <= 32'd65536 + (product >> 16); end
                    4'd4: begin dp_reg_4 <= 32'd65536 + (product >> 16); end
                    4'd5: begin dp_reg_5 <= 32'd65536 + (product >> 16); end
                    4'd6: begin dp_reg_6 <= 32'd65536 + (product >> 16); end
                    4'd7: begin dp_reg_7 <= 32'd65536 + (product >> 16); end
                    default: begin end
                endcase
                i_idx <= i_idx - 1'b1;
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
                    i_idx <= i_idx + 1'b1;
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