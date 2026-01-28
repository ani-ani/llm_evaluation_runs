module BingoTieDetector (
    input wire clk,
    input wire rst_n,
    input wire start,
    // Card 0: 25 numbers (16-bit each)
    input wire [15:0] arr_0_0, arr_0_1, arr_0_2, arr_0_3, arr_0_4,
    input wire [15:0] arr_0_5, arr_0_6, arr_0_7, arr_0_8, arr_0_9,
    input wire [15:0] arr_0_10, arr_0_11, arr_0_12, arr_0_13, arr_0_14,
    input wire [15:0] arr_0_15, arr_0_16, arr_0_17, arr_0_18, arr_0_19,
    input wire [15:0] arr_0_20, arr_0_21, arr_0_22, arr_0_23, arr_0_24,
    // Card 1: 25 numbers (16-bit each)
    input wire [15:0] arr_1_0, arr_1_1, arr_1_2, arr_1_3, arr_1_4,
    input wire [15:0] arr_1_5, arr_1_6, arr_1_7, arr_1_8, arr_1_9,
    input wire [15:0] arr_1_10, arr_1_11, arr_1_12, arr_1_13, arr_1_14,
    input wire [15:0] arr_1_15, arr_1_16, arr_1_17, arr_1_18, arr_1_19,
    input wire [15:0] arr_1_20, arr_1_21, arr_1_22, arr_1_23, arr_1_24,
    // Outputs
    output reg done,
    output reg [3:0] a,  // 1-based index, 0 means none
    output reg [3:0] b
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK_PAIR = 3'd1;
    localparam [2:0] FOUND_TIE  = 3'd2;
    localparam [2:0] NO_TIE     = 3'd3;
    localparam [2:0] FINISH     = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;  // For timeout protection
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Card storage (2 cards, 25 cells each)
    reg [15:0] card0 [0:24];
    reg [15:0] card1 [0:24];
    
    // Row processing
    reg [2:0] row_idx;  // 0-4 for 5 rows
    reg [2:0] col_idx;  // 0-4 for 5 columns
    reg [15:0] target_value;  // Value to look for in other card
    reg found_in_card0;  // Flag for card0 row completeness
    reg found_in_card1;  // Flag for card1 row completeness
    reg [2:0] row_count0;  // How many numbers found in current row of card0
    reg [2:0] row_count1;  // How many numbers found in current row of card1
    reg [1:0] pair_idx;  // 0: (0,1) pairs only (C=2)

    integer i, j, k;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            a <= 4'd0;
            b <= 4'd0;
            cycle_count <= 8'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            target_value <= 16'd0;
            found_in_card0 <= 1'b0;
            found_in_card1 <= 1'b0;
            row_count0 <= 3'd0;
            row_count1 <= 3'd0;
            pair_idx <= 2'd0;
            // Initialize card storage
            for (i = 0; i < 25; i = i + 1) begin
                card0[i] <= 16'd0;
                card1[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    a <= 4'd0;
                    b <= 4'd0;
                    cycle_count <= 8'd0;
                    pair_idx <= 2'd0;
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    if (start) begin
                        // Load cards into storage
                        card0[0] <= arr_0_0; card0[1] <= arr_0_1; card0[2] <= arr_0_2;
                        card0[3] <= arr_0_3; card0[4] <= arr_0_4; card0[5] <= arr_0_5;
                        card0[6] <= arr_0_6; card0[7] <= arr_0_7; card0[8] <= arr_0_8;
                        card0[9] <= arr_0_9; card0[10] <= arr_0_10; card0[11] <= arr_0_11;
                        card0[12] <= arr_0_12; card0[13] <= arr_0_13; card0[14] <= arr_0_14;
                        card0[15] <= arr_0_15; card0[16] <= arr_0_16; card0[17] <= arr_0_17;
                        card0[18] <= arr_0_18; card0[19] <= arr_0_19; card0[20] <= arr_0_20;
                        card0[21] <= arr_0_21; card0[22] <= arr_0_22; card0[23] <= arr_0_23;
                        card0[24] <= arr_0_24;
                        
                        card1[0] <= arr_1_0; card1[1] <= arr_1_1; card1[2] <= arr_1_2;
                        card1[3] <= arr_1_3; card1[4] <= arr_1_4; card1[5] <= arr_1_5;
                        card1[6] <= arr_1_6; card1[7] <= arr_1_7; card1[8] <= arr_1_8;
                        card1[9] <= arr_1_9; card1[10] <= arr_1_10; card1[11] <= arr_1_11;
                        card1[12] <= arr_1_12; card1[13] <= arr_1_13; card1[14] <= arr_1_14;
                        card1[15] <= arr_1_15; card1[16] <= arr_1_16; card1[17] <= arr_1_17;
                        card1[18] <= arr_1_18; card1[19] <= arr_1_19; card1[20] <= arr_1_20;
                        card1[21] <= arr_1_21; card1[22] <= arr_1_22; card1[23] <= arr_1_23;
                        card1[24] <= arr_1_24;
                    end
                end
                
                CHECK_PAIR: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check horizontal row at row_idx
                    // Count numbers found in row of card0
                    if (col_idx == 3'd0) begin
                        row_count0 <= 3'd0;
                        row_count1 <= 3'd0;
                        target_value <= card0[row_idx * 5 + col_idx];
                    end else begin
                        // Update target based on current cell
                        target_value <= card0[row_idx * 5 + col_idx];
                    end
                    
                    // Check if current number is in card1 row
                    // (Optimized: check if target_value is in card1 row)
                    // For simplicity, we check all cells in row
                    if (card1[row_idx * 5 + col_idx] == target_value) begin
                        row_count1 <= row_count1 + 3'd1;
                    end
                    
                    // Check if current number is in card0 row (besides target cell)
                    for (k = 0; k < 5; k = k + 1) begin
                        if (k != col_idx && card0[row_idx * 5 + k] == target_value) begin
                            row_count0 <= row_count0 + 3'd1;
                        end
                    end
                    
                    // Check if current cell completes a row for both
                    // A row is complete when 5 numbers are matched
                    // For card0: we need all 5 in row (including target at col_idx)
                    // For card1: we need to find all 5
                    
                    if (col_idx == 3'd4) begin
                        // Final column of row
                        // Check if card1 row has all 5 numbers found
                        if (row_count1 == 3'd4) begin
                            // Card1 row complete
                            // Check if card0 row complete
                            row_count0 <= 3'd0;
                            for (k = 0; k < 5; k = k + 1) begin
                                if (card0[row_idx * 5 + k] == target_value) begin
                                    row_count0 <= row_count0 + 3'd1;
                                end
                            end
                            if (row_count0 == 3'd4) begin
                                // Both complete with same number! Tie found
                                a <= 4'd1;  // Card indices are 1-based
                                b <= 4'd2;
                            end
                        end
                        // Move to next row
                        if (row_idx == 3'd4) begin
                            // All rows checked for this pair
                            // Move to next pair (only one pair for C=2)
                            row_idx <= 3'd0;
                        end else begin
                            row_idx <= row_idx + 3'd1;
                        end
                        col_idx <= 3'd0;
                    end else begin
                        col_idx <= col_idx + 3'd1;
                    end
                end
                
                FOUND_TIE: begin
                    done <= 1'b1;
                    a <= 4'd1;  // Card 1 index (1-based)
                    b <= 4'd2;  // Card 2 index (1-based)
                end
                
                NO_TIE: begin
                    done <= 1'b1;
                    a <= 4'd0;
                    b <= 4'd0;
                end
                
                FINISH: begin
                    done <= 1'b1;  // Keep done high
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    a <= 4'd0;
                    b <= 4'd0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK_PAIR;
                else
                    next_state = IDLE;
            end
            
            CHECK_PAIR: begin
                // Process all rows for pair (0,1)
                // We need 5 rows * 5 columns = 25 cycles per row check
                // Simplified: one cycle per row check
                if (row_idx == 3'd4 && col_idx == 3'd4) begin
                    // Last cell checked
                    if (a == 4'd1 && b == 4'd2)
                        next_state = FOUND_TIE;
                    else
                        next_state = NO_TIE;
                end else if (cycle_count >= MAX_CYCLES) begin
                    next_state = NO_TIE;  // Timeout
                end else begin
                    next_state = CHECK_PAIR;
                end
            end
            
            FOUND_TIE: begin
                next_state = FINISH;
            end
            
            NO_TIE: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                // Stay in finish state
                next_state = FINISH;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule