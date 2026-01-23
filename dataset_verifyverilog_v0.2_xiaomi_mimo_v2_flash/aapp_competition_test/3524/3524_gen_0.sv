module interleaving_verifier (
    input clk,
    input rst_n,
    input start,
    input [5:0] len_s,
    input [5:0] len_s1,
    input [5:0] len_s2,
    input [7:0] s [15:0],
    input [7:0] s1 [7:0],
    input [7:0] s2 [7:0],
    output reg result,
    output reg done
);

    // State Encoding
    localparam IDLE          = 3'b000;
    localparam INIT          = 3'b001;
    localparam PROCESSING_ROW = 3'b010;
    localparam PROCESSING_COL = 3'b011;
    localparam DONE_STATE    = 3'b100;

    // Registers for DP table state[0..8][0..8]
    // 9x9 array of 1-bit
    reg state [8:0][8:0];
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Counters for iteration
    reg [3:0] i_cnt;
    reg [3:0] j_cnt;
    reg [3:0] i_cnt_next;
    reg [3:0] j_cnt_next;

    // Temporary storage for update logic to ensure synthesis works with standard Verilog
    reg update_row_flag;
    reg update_col_flag;

    // Helper wires to look up s characters
    wire [7:0] current_s_char;
    wire [7:0] current_s1_char;
    wire [7:0] current_s2_char;

    // Index safety clamping (logic determines indices)
    // Actual indices used in logic: s_idx = i_cnt + j_cnt
    // s1_idx = i_cnt
    // s2_idx = j_cnt

    assign current_s_char = s[i_cnt + j_cnt];
    assign current_s1_char = s1[i_cnt];
    assign current_s2_char = s2[j_cnt];

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
            // Reset state table
            for (int r = 0; r < 9; r++) begin
                for (int c = 0; c < 9; c++) begin
                    state[r][c] <= 1'b0;
                end
            end
        end else begin
            current_state <= next_state;
            i_cnt <= i_cnt_next;
            j_cnt <= j_cnt_next;

            // State Table Updates
            // We perform updates based on the flags set during state transition logic
            // However, since we are in the sequential block, we can use the current state
            // to decide updates. To be safe and avoid multiple drivers, we separate the
            // update logic into specific phases or use if-else chains.

            // Reset specific cells or perform updates based on current_state
            if (current_state == INIT) begin
                state[0][0] <= 1'b1;
                // Clear the rest
                for (int r = 0; r < 9; r++) begin
                    for (int c = 0; c < 9; c++) begin
                        if (r != 0 || c != 0) state[r][c] <= 1'b0;
                    end
                end
            end
            else if (current_state == PROCESSING_ROW) begin
                // Update state[i+1][j] based on state[i][j] and char match
                // i_cnt and j_cnt are the CURRENT indices being processed
                // We need to update state[i_cnt+1][j_cnt]
                if (state[i_cnt][j_cnt] && (i_cnt < len_s1) && (current_s_char == current_s1_char)) begin
                    state[i_cnt + 1][j_cnt] <= 1'b1;
                end
            end
            else if (current_state == PROCESSING_COL) begin
                // Update state[i][j+1] based on state[i][j] and char match
                if (state[i_cnt][j_cnt] && (j_cnt < len_s2) && (current_s_char == current_s2_char)) begin
                    state[i_cnt][j_cnt + 1] <= 1'b1;
                end
            end

            // Output latching
            if (current_state == DONE_STATE) begin
                done <= 1'b1;
                result <= state[len_s1][len_s2];
            end else if (current_state == IDLE) begin
                done <= 1'b0;
            end
        end
    end

    // Combinational Logic for Next State and Counters
    always @(*) begin
        next_state = current_state;
        i_cnt_next = i_cnt;
        j_cnt_next = j_cnt;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                    i_cnt_next = 4'd0;
                    j_cnt_next = 4'd0;
                end
            end

            INIT: begin
                // Start processing from (0,0)
                i_cnt_next = 4'd0;
                j_cnt_next = 4'd0;
                // We need to handle the base case (0,0) transitions immediately or in first processing step.
                // The algorithm says: iterate i, j. For each state[i][j]==1, update neighbors.
                // Since we update neighbors in sequential logic, we can move to processing.
                // Note: state[0][0] is set in INIT seq block. We need to check it for transitions.
                // However, we need to process (0,0) to set (1,0) and (0,1).
                // Let's go to PROCESSING_ROW for (0,0).
                next_state = PROCESSING_ROW;
            end

            PROCESSING_ROW: begin
                // Current (i, j). Check s1 transition.
                // We perform the check and update sequentially. 
                // Next step: Check s2 transition (COL state).
                // If (i,j) is valid, we might update (i+1,j). 
                // But we also need to check (i,j+1).
                // The structure requested: STATE MACHINE with IDLE, INIT, PROCESSING_ROW, PROCESSING_COL, DONE.
                // This suggests a loop: Row Process -> Col Process -> Increment -> ...
                
                next_state = PROCESSING_COL;
            end

            PROCESSING_COL: begin
                // Current (i, j). Check s2 transition.
                // After checking both, we need to advance pointers.
                // We need to traverse the DP table. 
                // Convention: iterate i from 0 to len_s1, j from 0 to len_s2.
                // We are at (i_cnt, j_cnt).

                // Advance indices logic:
                // j_cnt increments until len_s2. When j_cnt hits len_s2, reset j_cnt and inc i_cnt.
                if (j_cnt < len_s2) begin
                    j_cnt_next = j_cnt + 1;
                    next_state = PROCESSING_ROW; // Go back to Row state to process new (i, j)
                end else begin
                    // End of column
                    j_cnt_next = 0;
                    if (i_cnt < len_s1) begin
                        i_cnt_next = i_cnt + 1;
                        next_state = PROCESSING_ROW; // Next row, start col 0
                    end else begin
                        // Finished all rows and cols
                        next_state = DONE_STATE;
                    end
                end
            end

            DONE_STATE: begin
                // Wait for start to go low or stay here until reset
                // To allow re-triggering:
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule
