module untileable_cells (
    input clk,
    input rst_n,
    input start,
    input [5:0] N_valid,
    input [5:0] M_valid,
    input [7:0] street_char_0, street_char_1, street_char_2, street_char_3, street_char_4, street_char_5, street_char_6, street_char_7, street_char_8, street_char_9, street_char_10, street_char_11, street_char_12, street_char_13, street_char_14, street_char_15,
    input [5:0] pattern_len_0, pattern_len_1, pattern_len_2, pattern_len_3, pattern_len_4, pattern_len_5, pattern_len_6, pattern_len_7,
    input [7:0] pattern_0_char_0, pattern_0_char_1, pattern_0_char_2, pattern_0_char_3, pattern_0_char_4, pattern_0_char_5, pattern_0_char_6, pattern_0_char_7, pattern_0_char_8, pattern_0_char_9, pattern_0_char_10, pattern_0_char_11, pattern_0_char_12, pattern_0_char_13, pattern_0_char_14, pattern_0_char_15,
    input [7:0] pattern_1_char_0, pattern_1_char_1, pattern_1_char_2, pattern_1_char_3, pattern_1_char_4, pattern_1_char_5, pattern_1_char_6, pattern_1_char_7, pattern_1_char_8, pattern_1_char_9, pattern_1_char_10, pattern_1_char_11, pattern_1_char_12, pattern_1_char_13, pattern_1_char_14, pattern_1_char_15,
    input [7:0] pattern_2_char_0, pattern_2_char_1, pattern_2_char_2, pattern_2_char_3, pattern_2_char_4, pattern_2_char_5, pattern_2_char_6, pattern_2_char_7, pattern_2_char_8, pattern_2_char_9, pattern_2_char_10, pattern_2_char_11, pattern_2_char_12, pattern_2_char_13, pattern_2_char_14, pattern_2_char_15,
    input [7:0] pattern_3_char_0, pattern_3_char_1, pattern_3_char_2, pattern_3_char_3, pattern_3_char_4, pattern_3_char_5, pattern_3_char_6, pattern_3_char_7, pattern_3_char_8, pattern_3_char_9, pattern_3_char_10, pattern_3_char_11, pattern_3_char_12, pattern_3_char_13, pattern_3_char_14, pattern_3_char_15,
    input [7:0] pattern_4_char_0, pattern_4_char_1, pattern_4_char_2, pattern_4_char_3, pattern_4_char_4, pattern_4_char_5, pattern_4_char_6, pattern_4_char_7, pattern_4_char_8, pattern_4_char_9, pattern_4_char_10, pattern_4_char_11, pattern_4_char_12, pattern_4_char_13, pattern_4_char_14, pattern_4_char_15,
    input [7:0] pattern_5_char_0, pattern_5_char_1, pattern_5_char_2, pattern_5_char_3, pattern_5_char_4, pattern_5_char_5, pattern_5_char_6, pattern_5_char_7, pattern_5_char_8, pattern_5_char_9, pattern_5_char_10, pattern_5_char_11, pattern_5_char_12, pattern_5_char_13, pattern_5_char_14, pattern_5_char_15,
    input [7:0] pattern_6_char_0, pattern_6_char_1, pattern_6_char_2, pattern_6_char_3, pattern_6_char_4, pattern_6_char_5, pattern_6_char_6, pattern_6_char_7, pattern_6_char_8, pattern_6_char_9, pattern_6_char_10, pattern_6_char_11, pattern_6_char_12, pattern_6_char_13, pattern_6_char_14, pattern_6_char_15,
    input [7:0] pattern_7_char_0, pattern_7_char_1, pattern_7_char_2, pattern_7_char_3, pattern_7_char_4, pattern_7_char_5, pattern_7_char_6, pattern_7_char_7, pattern_7_char_8, pattern_7_char_9, pattern_7_char_10, pattern_7_char_11, pattern_7_char_12, pattern_7_char_13, pattern_7_char_14, pattern_7_char_15,
    output reg [5:0] result,
    output reg done
);

    // Internal registers for pattern data storage (ROM-style logic inference)
    reg [5:0] plen [0:7];
    reg [7:0] pchar [0:7][0:15];
    reg [7:0] street [0:15];

    // State Encoding
    localparam IDLE = 3'b000;
    localparam CHECK_PATTERN = 3'b001;
    localparam CHECK_POSITION = 3'b010;
    localparam MATCH_CHECK = 3'b011;
    localparam COUNT = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [3:0] p_idx;      // Pattern index (0-7)
    reg [3:0] s_idx;      // Street start position (0-15)
    reg [3:0] c_idx;      // Character index for match check (0-15)
    reg [15:0] covered;   // Bitmask for covered cells
    reg match_flag;       // Flag if current pattern matches at current position
    reg [3:0] bit_idx;    // Index for counting zeros

    integer i;

    // Load inputs into internal arrays on startup/reset to ensure data availability
    // This is necessary because input ports are volatile
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset internal arrays
            for (i = 0; i < 8; i = i + 1) begin
                plen[i] <= 0;
                for (int j = 0; j < 16; j = j + 1) begin
                    pchar[i][j] <= 0;
                end
            end
            for (i = 0; i < 16; i = i + 1) begin
                street[i] <= 0;
            end
        end else if (start && state == IDLE) begin
            // Load Street
            street[0] <= street_char_0; street[1] <= street_char_1; street[2] <= street_char_2; street[3] <= street_char_3;
            street[4] <= street_char_4; street[5] <= street_char_5; street[6] <= street_char_6; street[7] <= street_char_7;
            street[8] <= street_char_8; street[9] <= street_char_9; street[10] <= street_char_10; street[11] <= street_char_11;
            street[12] <= street_char_12; street[13] <= street_char_13; street[14] <= street_char_14; street[15] <= street_char_15;
            
            // Load Pattern Lengths
            plen[0] <= pattern_len_0; plen[1] <= pattern_len_1; plen[2] <= pattern_len_2; plen[3] <= pattern_len_3;
            plen[4] <= pattern_len_4; plen[5] <= pattern_len_5; plen[6] <= pattern_len_6; plen[7] <= pattern_len_7;

            // Load Pattern 0
            pchar[0][0] <= pattern_0_char_0; pchar[0][1] <= pattern_0_char_1; pchar[0][2] <= pattern_0_char_2; pchar[0][3] <= pattern_0_char_3;
            pchar[0][4] <= pattern_0_char_4; pchar[0][5] <= pattern_0_char_5; pchar[0][6] <= pattern_0_char_6; pchar[0][7] <= pattern_0_char_7;
            pchar[0][8] <= pattern_0_char_8; pchar[0][9] <= pattern_0_char_9; pchar[0][10] <= pattern_0_char_10; pchar[0][11] <= pattern_0_char_11;
            pchar[0][12] <= pattern_0_char_12; pchar[0][13] <= pattern_0_char_13; pchar[0][14] <= pattern_0_char_14; pchar[0][15] <= pattern_0_char_15;
            // Load Pattern 1
            pchar[1][0] <= pattern_1_char_0; pchar[1][1] <= pattern_1_char_1; pchar[1][2] <= pattern_1_char_2; pchar[1][3] <= pattern_1_char_3;
            pchar[1][4] <= pattern_1_char_4; pchar[1][5] <= pattern_1_char_5; pchar[1][6] <= pattern_1_char_6; pchar[1][7] <= pattern_1_char_7;
            pchar[1][8] <= pattern_1_char_8; pchar[1][9] <= pattern_1_char_9; pchar[1][10] <= pattern_1_char_10; pchar[1][11] <= pattern_1_char_11;
            pchar[1][12] <= pattern_1_char_12; pchar[1][13] <= pattern_1_char_13; pchar[1][14] <= pattern_1_char_14; pchar[1][15] <= pattern_1_char_15;
            // Load Pattern 2
            pchar[2][0] <= pattern_2_char_0; pchar[2][1] <= pattern_2_char_1; pchar[2][2] <= pattern_2_char_2; pchar[2][3] <= pattern_2_char_3;
            pchar[2][4] <= pattern_2_char_4; pchar[2][5] <= pattern_2_char_5; pchar[2][6] <= pattern_2_char_6; pchar[2][7] <= pattern_2_char_7;
            pchar[2][8] <= pattern_2_char_8; pchar[2][9] <= pattern_2_char_9; pchar[2][10] <= pattern_2_char_10; pchar[2][11] <= pattern_2_char_11;
            pchar[2][12] <= pattern_2_char_12; pchar[2][13] <= pattern_2_char_13; pchar[2][14] <= pattern_2_char_14; pchar[2][15] <= pattern_2_char_15;
            // Load Pattern 3
            pchar[3][0] <= pattern_3_char_0; pchar[3][1] <= pattern_3_char_1; pchar[3][2] <= pattern_3_char_2; pchar[3][3] <= pattern_3_char_3;
            pchar[3][4] <= pattern_3_char_4; pchar[3][5] <= pattern_3_char_5; pchar[3][6] <= pattern_3_char_6; pchar[3][7] <= pattern_3_char_7;
            pchar[3][8] <= pattern_3_char_8; pchar[3][9] <= pattern_3_char_9; pchar[3][10] <= pattern_3_char_10; pchar[3][11] <= pattern_3_char_11;
            pchar[3][12] <= pattern_3_char_12; pchar[3][13] <= pattern_3_char_13; pchar[3][14] <= pattern_3_char_14; pchar[3][15] <= pattern_3_char_15;
            // Load Pattern 4
            pchar[4][0] <= pattern_4_char_0; pchar[4][1] <= pattern_4_char_1; pchar[4][2] <= pattern_4_char_2; pchar[4][3] <= pattern_4_char_3;
            pchar[4][4] <= pattern_4_char_4; pchar[4][5] <= pattern_4_char_5; pchar[4][6] <= pattern_4_char_6; pchar[4][7] <= pattern_4_char_7;
            pchar[4][8] <= pattern_4_char_8; pchar[4][9] <= pattern_4_char_9; pchar[4][10] <= pattern_4_char_10; pchar[4][11] <= pattern_4_char_11;
            pchar[4][12] <= pattern_4_char_12; pchar[4][13] <= pattern_4_char_13; pchar[4][14] <= pattern_4_char_14; pchar[4][15] <= pattern_4_char_15;
            // Load Pattern 5
            pchar[5][0] <= pattern_5_char_0; pchar[5][1] <= pattern_5_char_1; pchar[5][2] <= pattern_5_char_2; pchar[5][3] <= pattern_5_char_3;
            pchar[5][4] <= pattern_5_char_4; pchar[5][5] <= pattern_5_char_5; pchar[5][6] <= pattern_5_char_6; pchar[5][7] <= pattern_5_char_7;
            pchar[5][8] <= pattern_5_char_8; pchar[5][9] <= pattern_5_char_9; pchar[5][10] <= pattern_5_char_10; pchar[5][11] <= pattern_5_char_11;
            pchar[5][12] <= pattern_5_char_12; pchar[5][13] <= pattern_5_char_13; pchar[5][14] <= pattern_5_char_14; pchar[5][15] <= pattern_5_char_15;
            // Load Pattern 6
            pchar[6][0] <= pattern_6_char_0; pchar[6][1] <= pattern_6_char_1; pchar[6][2] <= pattern_6_char_2; pchar[6][3] <= pattern_6_char_3;
            pchar[6][4] <= pattern_6_char_4; pchar[6][5] <= pattern_6_char_5; pchar[6][6] <= pattern_6_char_6; pchar[6][7] <= pattern_6_char_7;
            pchar[6][8] <= pattern_6_char_8; pchar[6][9] <= pattern_6_char_9; pchar[6][10] <= pattern_6_char_10; pchar[6][11] <= pattern_6_char_11;
            pchar[6][12] <= pattern_6_char_12; pchar[6][13] <= pattern_6_char_13; pchar[6][14] <= pattern_6_char_14; pchar[6][15] <= pattern_6_char_15;
            // Load Pattern 7
            pchar[7][0] <= pattern_7_char_0; pchar[7][1] <= pattern_7_char_1; pchar[7][2] <= pattern_7_char_2; pchar[7][3] <= pattern_7_char_3;
            pchar[7][4] <= pattern_7_char_4; pchar[7][5] <= pattern_7_char_5; pchar[7][6] <= pattern_7_char_6; pchar[7][7] <= pattern_7_char_7;
            pchar[7][8] <= pattern_7_char_8; pchar[7][9] <= pattern_7_char_9; pchar[7][10] <= pattern_7_char_10; pchar[7][11] <= pattern_7_char_11;
            pchar[7][12] <= pattern_7_char_12; pchar[7][13] <= pattern_7_char_13; pchar[7][14] <= pattern_7_char_14; pchar[7][15] <= pattern_7_char_15;
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            covered <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        covered <= 0;
                        p_idx <= 0;
                        state <= CHECK_PATTERN;
                    end
                end

                CHECK_PATTERN: begin
                    if (p_idx < M_valid) begin
                        s_idx <= 0;
                        state <= CHECK_POSITION;
                    end else begin
                        // Done with all patterns, start counting
                        bit_idx <= 0;
                        result <= 0;
                        state <= COUNT;
                    end
                end

                CHECK_POSITION: begin
                    if (s_idx <= (N_valid - plen[p_idx])) begin
                        c_idx <= 0;
                        match_flag <= 1;
                        state <= MATCH_CHECK;
                    end else begin
                        // Next pattern
                        p_idx <= p_idx + 1;
                        state <= CHECK_PATTERN;
                    end
                end

                MATCH_CHECK: begin
                    if (c_idx < plen[p_idx]) begin
                        if (street[s_idx + c_idx] != pchar[p_idx][c_idx]) begin
                            match_flag <= 0;
                            // Mismatch found, no need to check further chars for this position
                            // Wait for next cycle to move to next position logic (or jump)
                            // Optimization: jump immediately to next position logic next cycle
                            // To keep single cycle per step logic, we use next state
                            // But we need to skip remaining chars. 
                            // Actually, let's complete the loop conceptually but just set flag to 0.
                            // We can skip setting flag again.
                        end
                        c_idx <= c_idx + 1;
                    end else begin
                        // Finished checking all chars for this position
                        if (match_flag) begin
                            // Set covered bits
                            for (int i = 0; i < 16; i = i + 1) begin
                                if (i >= s_idx && i < (s_idx + plen[p_idx])) begin
                                    covered[i] <= 1;
                                end
                            end
                        end
                        // Move to next position
                        s_idx <= s_idx + 1;
                        state <= CHECK_POSITION;
                    end
                end

                COUNT: begin
                    if (bit_idx < N_valid) begin
                        if (!covered[bit_idx]) begin
                            result <= result + 1;
                        end
                        bit_idx <= bit_idx + 1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule
