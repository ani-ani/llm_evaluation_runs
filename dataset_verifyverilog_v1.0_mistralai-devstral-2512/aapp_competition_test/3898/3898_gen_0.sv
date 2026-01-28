module StatueRearrangement(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_in_0,
    input [7:0] arr_in_1,
    input [7:0] arr_in_2,
    input [7:0] arr_in_3,
    input [7:0] arr_in_4,
    input [7:0] arr_in_5,
    input [7:0] arr_in_6,
    input [7:0] arr_in_7,
    input [7:0] arr_in_8,
    input [7:0] arr_in_9,
    input [7:0] arr_in_10,
    input [7:0] arr_in_11,
    input [7:0] arr_in_12,
    input [7:0] arr_in_13,
    input [7:0] arr_in_14,
    input [7:0] arr_in_15,
    input [7:0] arr_tgt_0,
    input [7:0] arr_tgt_1,
    input [7:0] arr_tgt_2,
    input [7:0] arr_tgt_3,
    input [7:0] arr_tgt_4,
    input [7:0] arr_tgt_5,
    input [7:0] arr_tgt_6,
    input [7:0] arr_tgt_7,
    input [7:0] arr_tgt_8,
    input [7:0] arr_tgt_9,
    input [7:0] arr_tgt_10,
    input [7:0] arr_tgt_11,
    input [7:0] arr_tgt_12,
    input [7:0] arr_tgt_13,
    input [7:0] arr_tgt_14,
    input [7:0] arr_tgt_15,
    output reg result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE     = 4'd0;
    localparam [3:0] EXTRACT_A = 4'd1;
    localparam [3:0] EXTRACT_B = 4'd2;
    localparam [3:0] FIND_IDX  = 4'd3;
    localparam [3:0] COMPARE   = 4'd4;
    localparam [3:0] FINISH    = 4'd5;

    reg [3:0] state, next_state;

    // Counters and temporary storage
    reg [3:0] idx_in;
    reg [3:0] idx_tgt;
    reg [3:0] seq_A_len;
    reg [3:0] seq_B_len;
    reg [3:0] find_idx;
    reg [3:0] compare_idx;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Temporary buffers for non-zero elements
    reg [7:0] seq_A [0:14];
    reg [7:0] seq_B [0:14];
    reg [7:0] shifted_B [0:14];

    // Flags
    reg found_match;
    reg length_match;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            idx_in <= 4'd0;
            idx_tgt <= 4'd0;
            seq_A_len <= 4'd0;
            seq_B_len <= 4'd0;
            find_idx <= 4'd0;
            compare_idx <= 4'd0;
            cycle_count <= 8'd0;
            found_match <= 1'b0;
            length_match <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = EXTRACT_A;
                end
            end

            EXTRACT_A: begin
                if (idx_in == 4'd16) begin
                    next_state = EXTRACT_B;
                end
            end

            EXTRACT_B: begin
                if (idx_tgt == 4'd16) begin
                    next_state = FIND_IDX;
                end
            end

            FIND_IDX: begin
                if (find_idx == 4'd16 || found_match) begin
                    next_state = COMPARE;
                end
            end

            COMPARE: begin
                if (compare_idx == 4'd16 || !length_match) begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Extraction logic for seq_A
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 15; i = i + 1) begin
                seq_A[i] <= 8'd0;
            end
        end else if (state == EXTRACT_A && idx_in < 4'd16) begin
            case (idx_in)
                4'd0:  if (arr_in_0  != 8'd0) seq_A[seq_A_len] <= arr_in_0;
                4'd1:  if (arr_in_1  != 8'd0) seq_A[seq_A_len] <= arr_in_1;
                4'd2:  if (arr_in_2  != 8'd0) seq_A[seq_A_len] <= arr_in_2;
                4'd3:  if (arr_in_3  != 8'd0) seq_A[seq_A_len] <= arr_in_3;
                4'd4:  if (arr_in_4  != 8'd0) seq_A[seq_A_len] <= arr_in_4;
                4'd5:  if (arr_in_5  != 8'd0) seq_A[seq_A_len] <= arr_in_5;
                4'd6:  if (arr_in_6  != 8'd0) seq_A[seq_A_len] <= arr_in_6;
                4'd7:  if (arr_in_7  != 8'd0) seq_A[seq_A_len] <= arr_in_7;
                4'd8:  if (arr_in_8  != 8'd0) seq_A[seq_A_len] <= arr_in_8;
                4'd9:  if (arr_in_9  != 8'd0) seq_A[seq_A_len] <= arr_in_9;
                4'd10: if (arr_in_10 != 8'd0) seq_A[seq_A_len] <= arr_in_10;
                4'd11: if (arr_in_11 != 8'd0) seq_A[seq_A_len] <= arr_in_11;
                4'd12: if (arr_in_12 != 8'd0) seq_A[seq_A_len] <= arr_in_12;
                4'd13: if (arr_in_13 != 8'd0) seq_A[seq_A_len] <= arr_in_13;
                4'd14: if (arr_in_14 != 8'd0) seq_A[seq_A_len] <= arr_in_14;
                4'd15: if (arr_in_15 != 8'd0) seq_A[seq_A_len] <= arr_in_15;
            endcase
            if (idx_in < 4'd16) begin
                if (arr_in_0  != 8'd0 && idx_in == 4'd0)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_1  != 8'd0 && idx_in == 4'd1)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_2  != 8'd0 && idx_in == 4'd2)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_3  != 8'd0 && idx_in == 4'd3)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_4  != 8'd0 && idx_in == 4'd4)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_5  != 8'd0 && idx_in == 4'd5)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_6  != 8'd0 && idx_in == 4'd6)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_7  != 8'd0 && idx_in == 4'd7)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_8  != 8'd0 && idx_in == 4'd8)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_9  != 8'd0 && idx_in == 4'd9)  seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_10 != 8'd0 && idx_in == 4'd10) seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_11 != 8'd0 && idx_in == 4'd11) seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_12 != 8'd0 && idx_in == 4'd12) seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_13 != 8'd0 && idx_in == 4'd13) seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_14 != 8'd0 && idx_in == 4'd14) seq_A_len <= seq_A_len + 4'd1;
                if (arr_in_15 != 8'd0 && idx_in == 4'd15) seq_A_len <= seq_A_len + 4'd1;
                idx_in <= idx_in + 4'd1;
            end
        end
    end

    // Extraction logic for seq_B
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 15; i = i + 1) begin
                seq_B[i] <= 8'd0;
            end
        end else if (state == EXTRACT_B && idx_tgt < 4'd16) begin
            case (idx_tgt)
                4'd0:  if (arr_tgt_0  != 8'd0) seq_B[seq_B_len] <= arr_tgt_0;
                4'd1:  if (arr_tgt_1  != 8'd0) seq_B[seq_B_len] <= arr_tgt_1;
                4'd2:  if (arr_tgt_2  != 8'd0) seq_B[seq_B_len] <= arr_tgt_2;
                4'd3:  if (arr_tgt_3  != 8'd0) seq_B[seq_B_len] <= arr_tgt_3;
                4'd4:  if (arr_tgt_4  != 8'd0) seq_B[seq_B_len] <= arr_tgt_4;
                4'd5:  if (arr_tgt_5  != 8'd0) seq_B[seq_B_len] <= arr_tgt_5;
                4'd6:  if (arr_tgt_6  != 8'd0) seq_B[seq_B_len] <= arr_tgt_6;
                4'd7:  if (arr_tgt_7  != 8'd0) seq_B[seq_B_len] <= arr_tgt_7;
                4'd8:  if (arr_tgt_8  != 8'd0) seq_B[seq_B_len] <= arr_tgt_8;
                4'd9:  if (arr_tgt_9  != 8'd0) seq_B[seq_B_len] <= arr_tgt_9;
                4'd10: if (arr_tgt_10 != 8'd0) seq_B[seq_B_len] <= arr_tgt_10;
                4'd11: if (arr_tgt_11 != 8'd0) seq_B[seq_B_len] <= arr_tgt_11;
                4'd12: if (arr_tgt_12 != 8'd0) seq_B[seq_B_len] <= arr_tgt_12;
                4'd13: if (arr_tgt_13 != 8'd0) seq_B[seq_B_len] <= arr_tgt_13;
                4'd14: if (arr_tgt_14 != 8'd0) seq_B[seq_B_len] <= arr_tgt_14;
                4'd15: if (arr_tgt_15 != 8'd0) seq_B[seq_B_len] <= arr_tgt_15;
            endcase
            if (idx_tgt < 4'd16) begin
                if (arr_tgt_0  != 8'd0 && idx_tgt == 4'd0)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_1  != 8'd0 && idx_tgt == 4'd1)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_2  != 8'd0 && idx_tgt == 4'd2)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_3  != 8'd0 && idx_tgt == 4'd3)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_4  != 8'd0 && idx_tgt == 4'd4)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_5  != 8'd0 && idx_tgt == 4'd5)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_6  != 8'd0 && idx_tgt == 4'd6)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_7  != 8'd0 && idx_tgt == 4'd7)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_8  != 8'd0 && idx_tgt == 4'd8)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_9  != 8'd0 && idx_tgt == 4'd9)  seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_10 != 8'd0 && idx_tgt == 4'd10) seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_11 != 8'd0 && idx_tgt == 4'd11) seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_12 != 8'd0 && idx_tgt == 4'd12) seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_13 != 8'd0 && idx_tgt == 4'd13) seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_14 != 8'd0 && idx_tgt == 4'd14) seq_B_len <= seq_B_len + 4'd1;
                if (arr_tgt_15 != 8'd0 && idx_tgt == 4'd15) seq_B_len <= seq_B_len + 4'd1;
                idx_tgt <= idx_tgt + 4'd1;
            end
        end
    end

    // Find index logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            found_match <= 1'b0;
            length_match <= 1'b0;
        end else if (state == FIND_IDX && find_idx < 4'd16) begin
            if (seq_A_len == seq_B_len && seq_A_len > 4'd0) begin
                length_match <= 1'b1;
                if (seq_B[find_idx] == seq_A[0]) begin
                    found_match <= 1'b1;
                end
            end
            find_idx <= find_idx + 4'd1;
        end
    end

    // Compare logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 1'b0;
        end else if (state == COMPARE && compare_idx < 4'd16) begin
            if (length_match) begin
                if (found_match) begin
                    if (seq_A[compare_idx] == seq_B[(find_idx - 4'd1 + compare_idx) % seq_B_len]) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    compare_idx <= 4'd16;
                    found_match <= 1'b0;
                    find_idx <= 4'd0;
                    next_state = FIND_IDX;
                    state <= FIND_IDX;
                    return;
                    end
                end else begin
                    result <= 1'b0;
                end
            end else begin
                result <= 1'b0;
            end
            compare_idx <= compare_idx + 4'd1;
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            done <= 1'b1;
        end else if (state != IDLE) begin
            done <= 1'b0;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (state != IDLE) begin
            cycle_count <= cycle_count + 8'd1;
            if (cycle_count >= MAX_CYCLES) begin
                next_state = FINISH;
            end
        end
    end

endmodule