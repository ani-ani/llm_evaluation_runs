module sticker_solver(
    input clk,
    input rst_n,
    input start,
    input [7:0] message_len,
    input [15:0][7:0] message_chars,
    input [7:0] num_stickers,
    input [7:0] sticker_len [0:7],
    input [19:0][7:0] sticker_chars [0:7],
    input [19:0] sticker_price [0:7],
    output reg [31:0] result,
    output reg done
);

    // States
    localparam IDLE = 4'd0;
    localparam CHECK_EMPTY = 4'd1;
    localparam INITIALIZE = 4'd2;
    localparam DP_LOOP = 4'd3;
    localparam FIND_RESULT = 4'd4;
    localparam DONE_STATE = 4'd5;

    reg [3:0] state;
    reg [3:0] num_states;
    reg [3:0] next_num_states;
    reg [3:0] state_iter_idx;
    reg [7:0] sticker_iter_idx;
    reg [7:0] pos_iter_idx;
    reg [7:0] char_idx;
    reg [7:0] pass_count;
    reg [7:0] s_idx;
    reg [7:0] p_idx;
    reg [31:0] result;
    reg done;
    reg [31:0] current_cost;
    reg [31:0] new_cost;
    reg [15:0] temp_mask;
    reg [15:0] temp_overlap;
    reg [15:0] current_mask;
    reg [15:0] current_overlap;
    reg [63:0] state_list [0:15];
    reg [63:0] next_state_list [0:15];
    reg [63:0] current_state;
    reg [63:0] next_state;
    reg [15:0] temp_mask_gen;
    reg [31:0] temp_cost;
    reg match_ok;
    reg overlap_ok;

    // Synthesis helper for reading/writing DP memory
    always @(posedge clk) begin
        if (state == DP_LOOP && match_ok && overlap_ok) begin
            // Write new state
            next_state_list[next_num_states] <= next_state;
            next_num_states <= next_num_states + 1;
        end
    end

    // Combinational Logic for Overlap and Mask Calculation
    always @(*) begin
        match_ok = 0;
        overlap_ok = 0;
        temp_mask_gen = 0;
        next_state = 0;

        if (state == DP_LOOP && state_iter_idx < num_states && sticker_iter_idx < num_stickers && pos_iter_idx < message_len) begin
            // 1. Check Sticker Match
            bit mismatch;
            mismatch = 0;
            for (int i = 0; i < 20; i++) begin
                if (i < sticker_len[sticker_iter_idx]) begin
                    if (sticker_chars[sticker_iter_idx][i] != message_chars[pos_iter_idx + i]) begin
                        mismatch = 1;
                    end
                end
            end
            if (!mismatch) match_ok = 1;

            // 2. Check Overlap and Calculate New State
            if (match_ok) begin
                // Calculate Sticker Coverage Mask
                bit [15:0] raw_mask;
                raw_mask = (1 << sticker_len[sticker_iter_idx]) - 1;
                temp_mask_gen = raw_mask << pos_iter_idx;

                // Check Overlap constraint
                if ((temp_mask_gen & current_state[63:48]) != 0) begin
                    overlap_ok = 0; // Would cause > 2
                end else begin
                    overlap_ok = 1;

                    // Calculate New State
                    next_state[47:32] = current_state[47:32] | temp_mask_gen;
                    next_state[63:48] = current_state[63:48] | (temp_mask_gen & current_state[47:32]);
                    next_state[31:0] = current_state[31:0] + sticker_price[sticker_iter_idx];
                end
            end
        end
    end

    // Sequential Logic for Counters in DP_LOOP
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            num_states <= 0;
            next_num_states <= 0;
            state_iter_idx <= 0;
            sticker_iter_idx <= 0;
            pos_iter_idx <= 0;
            char_idx <= 0;
            pass_count <= 0;
        end else if (state == DP_LOOP) begin
            // PHASE: GENERATION (sticker_iter_idx != 255)
            if (sticker_iter_idx != 8'hFF) begin
                if (pos_iter_idx < message_len - 1) begin
                    pos_iter_idx <= pos_iter_idx + 1;
                end else begin
                    // Finished positions for this sticker
                    pos_iter_idx <= 0;
                    if (sticker_iter_idx < num_stickers - 1) begin
                        sticker_iter_idx <= sticker_iter_idx + 1;
                    end else begin
                        // Finished all stickers for this state
                        // Move to next state or finish
                        if (state_iter_idx < num_states - 1) begin
                            state_iter_idx <= state_iter_idx + 1;
                            sticker_iter_idx <= 0;
                        end else begin
                            // Finished all states
                            // Switch to Merge
                            sticker_iter_idx <= 8'hFF;
                            pos_iter_idx <= 0; // Reset for merge iteration
                            char_idx <= 0;     // Reset for merge iteration
                        end
                    end
                end
            end
        end else if (state == FIND_RESULT) begin
            // Clear signal
            state_iter_idx <= 0;
        end
    end

    // Merge Logic
    always @(posedge clk) begin
        if (state == DP_LOOP && sticker_iter_idx == 8'hFF && pos_iter_idx < next_num_states) begin
            // We are processing next_state_list[pos_iter_idx]
            // We are scanning state_list[char_idx]

            // Read candidate
            next_state <= next_state_list[pos_iter_idx];

            // Read current state from state_list for comparison
            if (char_idx < num_states) begin
                current_state <= state_list[char_idx];
            end

            // Compare
            if (char_idx < num_states) begin
                if (current_state[47:32] == next_state[47:32] && current_state[63:48] == next_state[63:48]) begin
                    // Match found, update cost if cheaper
                    if (next_state[31:0] < current_state[31:0]) begin
                        state_list[char_idx] <= next_state;
                    end
                    // Done with this candidate, move to next
                    pos_iter_idx <= pos_iter_idx + 1;
                    char_idx <= 0;
                end else begin
                    // No match, check next
                    char_idx <= char_idx + 1;
                end
            end else begin
                // End of state_list reached, no match found -> Append
                if (num_states < 16) begin
                    state_list[num_states] <= next_state;
                    num_states <= num_states + 1;
                end
                // Move to next candidate
                pos_iter_idx <= pos_iter_idx + 1;
                char_idx <= 0;
            end
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            num_states <= 0;
            next_num_states <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) state <= CHECK_EMPTY;
                end

                CHECK_EMPTY: begin
                    if (message_len == 0) begin
                        result <= 0;
                        done <= 1;
                        state <= DONE_STATE;
                    end else begin
                        state <= INITIALIZE;
                    end
                end

                INITIALIZE: begin
                    // Setup start state: mask=0, overlap=0, cost=0
                    state_list[0] <= 64'h0;
                    num_states <= 1;
                    next_num_states <= 0;
                    // Initialize result to INF
                    result <= 32'hFFFFFFFF;
                    // Start Loop
                    state <= DP_LOOP;
                    // Reset Loop Counters
                    state_iter_idx <= 0;
                    sticker_iter_idx <= 0;
                    pos_iter_idx <= 0;
                end

                DP_LOOP: begin
                    if (sticker_iter_idx == 8'hFF) begin
                        // MERGE PHASE
                        // Handled by separate block.
                        // Check if finished
                        if (pos_iter_idx >= next_num_states) begin
                            // Finished
                            state <= FIND_RESULT;
                            state_iter_idx <= 0;
                        end
                    end else begin
                        // GENERATION PHASE

                        // 1. Counter Updates
                        // Increment pos_iter_idx
                        if (message_len > 0) begin
                            if (pos_iter_idx < message_len - 1) begin
                                pos_iter_idx <= pos_iter_idx + 1;
                            end else begin
                                // Finished positions for this sticker
                                pos_iter_idx <= 0;
                                if (sticker_iter_idx < num_stickers - 1) begin
                                    sticker_iter_idx <= sticker_iter_idx + 1;
                                end else begin
                                    // Finished all stickers for this state
                                    // Move to next state or finish
                                    if (state_iter_idx < num_states - 1) begin
                                        state_iter_idx <= state_iter_idx + 1;
                                        sticker_iter_idx <= 0;
                                    end else begin
                                        // Finished all states
                                        // Switch to Merge
                                        sticker_iter_idx <= 8'hFF;
                                        pos_iter_idx <= 0; // Reset for merge iteration
                                        char_idx <= 0;     // Reset for merge iteration
                                    end
                                end
                            end
                        end else begin
                            // message_len is 0, skip to merge
                            sticker_iter_idx <= 8'hFF;
                        end
                    end
                end

                FIND_RESULT: begin
                    // Scan state_list (and next_state_list if we didn't merge?)
                    // Assume we merged into state_list.
                    // state_iter_idx is the index.
                    if (state_iter_idx < num_states) begin
                        // Check mask
                        if (state_list[state_iter_idx][47:32] == ((1 << message_len) - 1)) begin
                            // Check cost
                            if (state_list[state_iter_idx][31:0] < result) begin
                                result <= state_list[state_iter_idx][31:0];
                            end
                        end
                        state_iter_idx <= state_iter_idx + 1;
                    end else begin
                        // Scan complete
                        if (result == 32'hFFFFFFFF) begin
                            // No solution found in this pass.
                            // Are there more passes?
                            // We need to loop DP again.
                            // But we finished DP_LOOP logic once.
                            // We need to trigger DP_LOOP again if num_states > 0.
                            // If num_states == 0 here, impossible.
                            // If num_states > 0 but result is INF, we need to run DP again.
                            // But num_states should be populated by DP_LOOP.
                            // Wait, DP_LOOP populates next_state_list.
                            // Then DP_LOOP (merge phase) populates state_list.
                            // So we are scanning state_list.
                            // If no full coverage, we need to run DP_LOOP again.
                            // We should go back to DP_LOOP.

                            // But we need a way to stop (max passes).
                            // Let's add a counter pass_count.
                            // In INITIALIZE, set pass_count = 0.
                            // In FIND_RESULT (when returning to DP_LOOP), increment pass_count.
                            // If pass_count > 16, stop (impossible).

                            // If num_states == 0, stop (impossible).
                            // If num_states > 0, go to DP_LOOP.

                            // Re-read DP_LOOP logic.
                            // DP_LOOP needs to know if it's starting a new pass or continuing.
                            // We can rely on num_states and next_num_states.
                            // DP_LOOP should iterate until state_iter_idx >= num_states.
                            // Then it should merge.
                            // Then it should go to FIND_RESULT.
                            // FIND_RESULT should check results.
                            // If no result, go back to DP_LOOP (for next pass).

                            // Let's add pass_count.
                            if (num_states == 0) begin
                                state <= DONE_STATE;
                                done <= 1;
                            end else if (pass_count > 16) begin
                                state <= DONE_STATE;
                                done <= 1;
                            end else begin
                                // Repeat DP
                                pass_count <= pass_count + 1;
                                state <= DP_LOOP;
                                // Reset loop vars
                                state_iter_idx <= 0;
                                sticker_iter_idx <= 0; // Represents phase: 0=Generate, 255=Merge
                                pos_iter_idx <= 0;
                                char_idx <= 0;
                            end
                        end else begin
                            // Result found
                            state <= DONE_STATE;
                            done <= 1;
                        end
                    end
                end

                DONE_STATE: begin
                    if (!start) state <= IDLE;
                end
            endcase
        end
    end
endmodule