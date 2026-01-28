module MinClusterSize(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] S,
    input wire [15:0] T,
    input wire [23:0] a_0, input wire [23:0] a_1, input wire [23:0] a_2, input wire [23:0] a_3,
    input wire [23:0] a_4, input wire [23:0] a_5, input wire [23:0] a_6, input wire [23:0] a_7,
    input wire [23:0] a_8, input wire [23:0] a_9, input wire [23:0] a_10, input wire [23:0] a_11,
    input wire [23:0] a_12, input wire [23:0] a_13, input wire [23:0] a_14, input wire [23:0] a_15,
    input wire [23:0] b_0, input wire [23:0] b_1, input wire [23:0] b_2, input wire [23:0] b_3,
    input wire [23:0] b_4, input wire [23:0] b_5, input wire [23:0] b_6, input wire [23:0] b_7,
    input wire [23:0] b_8, input wire [23:0] b_9, input wire [23:0] b_10, input wire [23:0] b_11,
    input wire [23:0] b_12, input wire [23:0] b_13, input wire [23:0] b_14, input wire [23:0] b_15,
    input wire c_0, input wire c_1, input wire c_2, input wire c_3,
    input wire c_4, input wire c_5, input wire c_6, input wire c_7,
    input wire c_8, input wire c_9, input wire c_10, input wire c_11,
    input wire c_12, input wire c_13, input wire c_14, input wire c_15,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_SUMS = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] SCAN = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    
    reg [2:0] state;
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // Weighted sums (32-bit)
    reg [31:0] sum [0:15];
    
    // Sorted indices
    reg [3:0] sorted_idx [0:15];
    
    // Scan variables
    reg [3:0] first_idx;
    reg [3:0] last_idx;
    reg [3:0] scan_idx;
    reg found_first;
    reg found_last;

    // Fixed-point multiplication
    wire signed [39:0] a_times_S_0 = $signed({16'd0, a_0}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_1 = $signed({16'd0, a_1}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_2 = $signed({16'd0, a_2}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_3 = $signed({16'd0, a_3}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_4 = $signed({16'd0, a_4}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_5 = $signed({16'd0, a_5}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_6 = $signed({16'd0, a_6}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_7 = $signed({16'd0, a_7}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_8 = $signed({16'd0, a_8}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_9 = $signed({16'd0, a_9}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_10 = $signed({16'd0, a_10}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_11 = $signed({16'd0, a_11}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_12 = $signed({16'd0, a_12}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_13 = $signed({16'd0, a_13}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_14 = $signed({16'd0, a_14}) * $signed({8'd0, S});
    wire signed [39:0] a_times_S_15 = $signed({16'd0, a_15}) * $signed({8'd0, S});

    wire signed [39:0] b_times_T_0 = $signed({16'd0, b_0}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_1 = $signed({16'd0, b_1}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_2 = $signed({16'd0, b_2}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_3 = $signed({16'd0, b_3}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_4 = $signed({16'd0, b_4}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_5 = $signed({16'd0, b_5}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_6 = $signed({16'd0, b_6}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_7 = $signed({16'd0, b_7}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_8 = $signed({16'd0, b_8}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_9 = $signed({16'd0, b_9}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_10 = $signed({16'd0, b_10}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_11 = $signed({16'd0, b_11}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_12 = $signed({16'd0, b_12}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_13 = $signed({16'd0, b_13}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_14 = $signed({16'd0, b_14}) * $signed({8'd0, T});
    wire signed [39:0] b_times_T_15 = $signed({16'd0, b_15}) * $signed({8'd0, T});

    // Initialize sorted indices
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            
            // Initialize sorted indices
            for (i = 0; i < 16; i = i + 1) begin
                sorted_idx[i] <= i;
            end
            
            first_idx <= 4'd0;
            last_idx <= 4'd0;
            scan_idx <= 4'd0;
            found_first <= 1'b0;
            found_last <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        state <= COMPUTE_SUMS;
                    end
                end
                
                COMPUTE_SUMS: begin
                    // Compute weighted sums
                    sum[0] <= (a_times_S_0 + b_times_T_0) >>> 8;
                    sum[1] <= (a_times_S_1 + b_times_T_1) >>> 8;
                    sum[2] <= (a_times_S_2 + b_times_T_2) >>> 8;
                    sum[3] <= (a_times_S_3 + b_times_T_3) >>> 8;
                    sum[4] <= (a_times_S_4 + b_times_T_4) >>> 8;
                    sum[5] <= (a_times_S_5 + b_times_T_5) >>> 8;
                    sum[6] <= (a_times_S_6 + b_times_T_6) >>> 8;
                    sum[7] <= (a_times_S_7 + b_times_T_7) >>> 8;
                    sum[8] <= (a_times_S_8 + b_times_T_8) >>> 8;
                    sum[9] <= (a_times_S_9 + b_times_T_9) >>> 8;
                    sum[10] <= (a_times_S_10 + b_times_T_10) >>> 8;
                    sum[11] <= (a_times_S_11 + b_times_T_11) >>> 8;
                    sum[12] <= (a_times_S_12 + b_times_T_12) >>> 8;
                    sum[13] <= (a_times_S_13 + b_times_T_13) >>> 8;
                    sum[14] <= (a_times_S_14 + b_times_T_14) >>> 8;
                    sum[15] <= (a_times_S_15 + b_times_T_15) >>> 8;
                    
                    state <= SORT;
                end
                
                SORT: begin
                    // Bitonic sort network for N=16
                    // Stage 1
                    bitonic_sort_stage(0, 1);
                    bitonic_sort_stage(2, 3);
                    bitonic_sort_stage(4, 5);
                    bitonic_sort_stage(6, 7);
                    bitonic_sort_stage(8, 9);
                    bitonic_sort_stage(10, 11);
                    bitonic_sort_stage(12, 13);
                    bitonic_sort_stage(14, 15);
                    
                    // Stage 2
                    bitonic_sort_stage(0, 2);
                    bitonic_sort_stage(1, 3);
                    bitonic_sort_stage(4, 6);
                    bitonic_sort_stage(5, 7);
                    bitonic_sort_stage(8, 10);
                    bitonic_sort_stage(9, 11);
                    bitonic_sort_stage(12, 14);
                    bitonic_sort_stage(13, 15);
                    
                    // Stage 3
                    bitonic_sort_stage(0, 4);
                    bitonic_sort_stage(1, 5);
                    bitonic_sort_stage(2, 6);
                    bitonic_sort_stage(3, 7);
                    bitonic_sort_stage(8, 12);
                    bitonic_sort_stage(9, 13);
                    bitonic_sort_stage(10, 14);
                    bitonic_sort_stage(11, 15);
                    
                    // Stage 4
                    bitonic_sort_stage(0, 8);
                    bitonic_sort_stage(1, 9);
                    bitonic_sort_stage(2, 10);
                    bitonic_sort_stage(3, 11);
                    bitonic_sort_stage(4, 12);
                    bitonic_sort_stage(5, 13);
                    bitonic_sort_stage(6, 14);
                    bitonic_sort_stage(7, 15);
                    
                    // Stage 5
                    bitonic_sort_stage(1, 2);
                    bitonic_sort_stage(3, 5);
                    bitonic_sort_stage(4, 8);
                    bitonic_sort_stage(6, 9);
                    bitonic_sort_stage(7, 10);
                    bitonic_sort_stage(11, 13);
                    bitonic_sort_stage(12, 14);
                    bitonic_sort_stage(15, 0);
                    
                    // Stage 6
                    bitonic_sort_stage(2, 4);
                    bitonic_sort_stage(5, 7);
                    bitonic_sort_stage(8, 10);
                    bitonic_sort_stage(9, 11);
                    bitonic_sort_stage(12, 14);
                    bitonic_sort_stage(13, 15);
                    
                    // Stage 7
                    bitonic_sort_stage(1, 4);
                    bitonic_sort_stage(2, 8);
                    bitonic_sort_stage(3, 5);
                    bitonic_sort_stage(6, 10);
                    bitonic_sort_stage(7, 11);
                    bitonic_sort_stage(9, 12);
                    bitonic_sort_stage(13, 14);
                    
                    // Stage 8
                    bitonic_sort_stage(2, 4);
                    bitonic_sort_stage(5, 8);
                    bitonic_sort_stage(6, 9);
                    bitonic_sort_stage(7, 10);
                    bitonic_sort_stage(11, 13);
                    bitonic_sort_stage(12, 14);
                    
                    // Stage 9
                    bitonic_sort_stage(3, 4);
                    bitonic_sort_stage(5, 6);
                    bitonic_sort_stage(7, 8);
                    bitonic_sort_stage(9, 10);
                    bitonic_sort_stage(11, 12);
                    bitonic_sort_stage(13, 14);
                    
                    state <= SCAN;
                end
                
                SCAN: begin
                    cycle_count <= cycle_count + 10'd1;
                    
                    if (!found_first) begin
                        case (scan_idx)
                            4'd0: begin
                                if (c_0) begin
                                    first_idx <= sorted_idx[0];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd1;
                            end
                            4'd1: begin
                                if (c_1) begin
                                    first_idx <= sorted_idx[1];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd2;
                            end
                            4'd2: begin
                                if (c_2) begin
                                    first_idx <= sorted_idx[2];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd3;
                            end
                            4'd3: begin
                                if (c_3) begin
                                    first_idx <= sorted_idx[3];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd4;
                            end
                            4'd4: begin
                                if (c_4) begin
                                    first_idx <= sorted_idx[4];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd5;
                            end
                            4'd5: begin
                                if (c_5) begin
                                    first_idx <= sorted_idx[5];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd6;
                            end
                            4'd6: begin
                                if (c_6) begin
                                    first_idx <= sorted_idx[6];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd7;
                            end
                            4'd7: begin
                                if (c_7) begin
                                    first_idx <= sorted_idx[7];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd8;
                            end
                            4'd8: begin
                                if (c_8) begin
                                    first_idx <= sorted_idx[8];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd9;
                            end
                            4'd9: begin
                                if (c_9) begin
                                    first_idx <= sorted_idx[9];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd10;
                            end
                            4'd10: begin
                                if (c_10) begin
                                    first_idx <= sorted_idx[10];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd11;
                            end
                            4'd11: begin
                                if (c_11) begin
                                    first_idx <= sorted_idx[11];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd12;
                            end
                            4'd12: begin
                                if (c_12) begin
                                    first_idx <= sorted_idx[12];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd13;
                            end
                            4'd13: begin
                                if (c_13) begin
                                    first_idx <= sorted_idx[13];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd14;
                            end
                            4'd14: begin
                                if (c_14) begin
                                    first_idx <= sorted_idx[14];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd15;
                            end
                            4'd15: begin
                                if (c_15) begin
                                    first_idx <= sorted_idx[15];
                                    found_first <= 1'b1;
                                end
                                scan_idx <= 4'd0;
                                found_last <= 1'b1;
                            end
                        endcase
                    end else begin
                        if (!found_last) begin
                            case (scan_idx)
                                4'd0: begin
                                    if (c_0) last_idx <= sorted_idx[0];
                                    scan_idx <= 4'd1;
                                end
                                4'd1: begin
                                    if (c_1) last_idx <= sorted_idx[1];
                                    scan_idx <= 4'd2;
                                end
                                4'd2: begin
                                    if (c_2) last_idx <= sorted_idx[2];
                                    scan_idx <= 4'd3;
                                end
                                4'd3: begin
                                    if (c_3) last_idx <= sorted_idx[3];
                                    scan_idx <= 4'd4;
                                end
                                4'd4: begin
                                    if (c_4) last_idx <= sorted_idx[4];
                                    scan_idx <= 4'd5;
                                end
                                4'd5: begin
                                    if (c_5) last_idx <= sorted_idx[5];
                                    scan_idx <= 4'd6;
                                end
                                4'd6: begin
                                    if (c_6) last_idx <= sorted_idx[6];
                                    scan_idx <= 4'd7;
                                end
                                4'd7: begin
                                    if (c_7) last_idx <= sorted_idx[7];
                                    scan_idx <= 4'd8;
                                end
                                4'd8: begin
                                    if (c_8) last_idx <= sorted_idx[8];
                                    scan_idx <= 4'd9;
                                end
                                4'd9: begin
                                    if (c_9) last_idx <= sorted_idx[9];
                                    scan_idx <= 4'd10;
                                end
                                4'd10: begin
                                    if (c_10) last_idx <= sorted_idx[10];
                                    scan_idx <= 4'd11;
                                end
                                4'd11: begin
                                    if (c_11) last_idx <= sorted_idx[11];
                                    scan_idx <= 4'd12;
                                end
                                4'd12: begin
                                    if (c_12) last_idx <= sorted_idx[12];
                                    scan_idx <= 4'd13;
                                end
                                4'd13: begin
                                    if (c_13) last_idx <= sorted_idx[13];
                                    scan_idx <= 4'd14;
                                end
                                4'd14: begin
                                    if (c_14) last_idx <= sorted_idx[14];
                                    scan_idx <= 4'd15;
                                end
                                4'd15: begin
                                    if (c_15) last_idx <= sorted_idx[15];
                                    scan_idx <= 4'd0;
                                    found_last <= 1'b1;
                                end
                            endcase
                        end else begin
                            state <= FINISH;
                        end
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Compute cluster size
                    if (found_first && found_last) begin
                        result <= (last_idx - first_idx) + 5'd1;
                    end else begin
                        result <= 5'd0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Bitonic sort comparator
    task bitonic_sort_stage;
        input [3:0] i;
        input [3:0] j;
        reg [3:0] idx_i;
        reg [3:0] idx_j;
        reg [31:0] sum_i;
        reg [31:0] sum_j;
        reg c_i;
        reg c_j;
        reg should_swap;
        
        begin
            idx_i = sorted_idx[i];
            idx_j = sorted_idx[j];
            
            // Get sums and c values
            case (idx_i)
                4'd0: begin sum_i = sum[0]; c_i = c_0; end
                4'd1: begin sum_i = sum[1]; c_i = c_1; end
                4'd2: begin sum_i = sum[2]; c_i = c_2; end
                4'd3: begin sum_i = sum[3]; c_i = c_3; end
                4'd4: begin sum_i = sum[4]; c_i = c_4; end
                4'd5: begin sum_i = sum[5]; c_i = c_5; end
                4'd6: begin sum_i = sum[6]; c_i = c_6; end
                4'd7: begin sum_i = sum[7]; c_i = c_7; end
                4'd8: begin sum_i = sum[8]; c_i = c_8; end
                4'd9: begin sum_i = sum[9]; c_i = c_9; end
                4'd10: begin sum_i = sum[10]; c_i = c_10; end
                4'd11: begin sum_i = sum[11]; c_i = c_11; end
                4'd12: begin sum_i = sum[12]; c_i = c_12; end
                4'd13: begin sum_i = sum[13]; c_i = c_13; end
                4'd14: begin sum_i = sum[14]; c_i = c_14; end
                4'd15: begin sum_i = sum[15]; c_i = c_15; end
            endcase
            
            case (idx_j)
                4'd0: begin sum_j = sum[0]; c_j = c_0; end
                4'd1: begin sum_j = sum[1]; c_j = c_1; end
                4'd2: begin sum_j = sum[2]; c_j = c_2; end
                4'd3: begin sum_j = sum[3]; c_j = c_3; end
                4'd4: begin sum_j = sum[4]; c_j = c_4; end
                4'd5: begin sum_j = sum[5]; c_j = c_5; end
                4'd6: begin sum_j = sum[6]; c_j = c_6; end
                4'd7: begin sum_j = sum[7]; c_j = c_7; end
                4'd8: begin sum_j = sum[8]; c_j = c_8; end
                4'd9: begin sum_j = sum[9]; c_j = c_9; end
                4'd10: begin sum_j = sum[10]; c_j = c_10; end
                4'd11: begin sum_j = sum[11]; c_j = c_11; end
                4'd12: begin sum_j = sum[12]; c_j = c_12; end
                4'd13: begin sum_j = sum[13]; c_j = c_13; end
                4'd14: begin sum_j = sum[14]; c_j = c_14; end
                4'd15: begin sum_j = sum[15]; c_j = c_15; end
            endcase
            
            // Compare: if sum_i > sum_j, swap
            // If equal, put c_i=1 before c_i=0
            should_swap = (sum_i > sum_j) || 
                         ((sum_i == sum_j) && (c_i == 1'b0) && (c_j == 1'b1));
            
            if (should_swap) begin
                sorted_idx[i] <= idx_j;
                sorted_idx[j] <= idx_i;
            end
        end
    endtask

endmodule