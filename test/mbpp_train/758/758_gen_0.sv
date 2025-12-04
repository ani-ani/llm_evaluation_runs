module list_histogram(
    input  logic                    clk,
    input  logic                    rst_n,
    input  logic                    start,
    input  logic [3:0][7:0]         sublists [0:3],
    output logic [3:0][7:0]         unique_lists [0:3],
    output logic [2:0]              counts       [0:3],
    output logic                    done
);

    // Internal state
    typedef enum logic [1:0] {
        IDLE  = 2'b00,
        BUSY  = 2'b01,
        HOLD  = 2'b10
    } state_t;

    state_t                 state, next_state;
    logic [2:0]             cycle_cnt, next_cycle_cnt;    // counts 0..4
    logic [3:0][7:0]        next_unique_lists [0:3];
    logic [2:0]             next_counts       [0:3];
    logic                   next_done;

    // Combinational control
    always_comb begin
        // Default pass-through
        next_state       = state;
        next_cycle_cnt   = cycle_cnt;
        next_done        = done;
        next_unique_lists = unique_lists;
        next_counts       = counts;

        case (state)
            IDLE: begin
                next_done = 1'b0;
                if (start) begin
                    // Start new processing: clear previous results
                    next_cycle_cnt = 3'd0;
                    next_done      = 1'b0;

                    // Clear histogram
                    for (int i = 0; i < 4; i++) begin
                        next_counts[i] = 3'd0;
                        next_unique_lists[i] = '{default:8'd0};
                    end

                    // Process all 4 sublists in parallel
                    // Local temporaries for matching and allocation
                    logic used_slot [0:3];
                    for (int i = 0; i < 4; i++) begin
                        used_slot[i] = (next_counts[i] != 3'd0);
                    end

                    for (int s = 0; s < 4; s++) begin
                        logic [3:0] match_vec;
                        logic       found_match;
                        int         match_idx;
                        int         empty_idx;

                        match_vec    = 4'b0000;
                        found_match  = 1'b0;
                        match_idx    = -1;
                        empty_idx    = -1;

                        // Find first matching used slot
                        for (int u = 0; u < 4; u++) begin
                            if (used_slot[u]) begin
                                if (sublists[s][0] == next_unique_lists[u][0] &&
                                    sublists[s][1] == next_unique_lists[u][1] &&
                                    sublists[s][2] == next_unique_lists[u][2] &&
                                    sublists[s][3] == next_unique_lists[u][3]) begin
                                    if (!found_match) begin
                                        found_match = 1'b1;
                                        match_idx   = u;
                                    end
                                end
                            end
                        end

                        if (found_match) begin
                            // Increment count up to max 4 (3'd4)
                            if (next_counts[match_idx] < 3'd4) begin
                                next_counts[match_idx] = next_counts[match_idx] + 3'd1;
                            end
                        end else begin
                            // No match: find first empty slot
                            for (int u = 0; u < 4; u++) begin
                                if (!used_slot[u] && empty_idx == -1) begin
                                    empty_idx = u;
                                end
                            end
                            if (empty_idx != -1) begin
                                next_unique_lists[empty_idx] = sublists[s];
                                next_counts[empty_idx]       = 3'd1;
                                used_slot[empty_idx]         = 1'b1;
                            end
                        end
                    end

                    next_state = BUSY;
                end
            end

            BUSY: begin
                // Advance cycle counter; done asserted after 4 cycles
                if (cycle_cnt < 3'd4) begin
                    next_cycle_cnt = cycle_cnt + 3'd1;
                    next_done      = 1'b0;
                    if (next_cycle_cnt == 3'd4) begin
                        next_done  = 1'b1; // done on 5th cycle boundary
                        next_state = HOLD;
                    end
                end else begin
                    next_done  = 1'b1;
                    next_state = HOLD;
                end
            end

            HOLD: begin
                // Hold results until next start or reset
                next_done = 1'b1;
                if (start) begin
                    // Restart histogram on new start pulse
                    next_cycle_cnt = 3'd0;
                    next_done      = 1'b0;

                    for (int i = 0; i < 4; i++) begin
                        next_counts[i]       = 3'd0;
                        next_unique_lists[i] = '{default:8'd0};
                    end

                    logic used_slot [0:3];
                    for (int i = 0; i < 4; i++) begin
                        used_slot[i] = 1'b0;
                    end

                    for (int s = 0; s < 4; s++) begin
                        logic       found_match;
                        int         match_idx;
                        int         empty_idx;

                        found_match = 1'b0;
                        match_idx   = -1;
                        empty_idx   = -1;

                        for (int u = 0; u < 4; u++) begin
                            if (used_slot[u]) begin
                                if (sublists[s][0] == next_unique_lists[u][0] &&
                                    sublists[s][1] == next_unique_lists[u][1] &&
                                    sublists[s][2] == next_unique_lists[u][2] &&
                                    sublists[s][3] == next_unique_lists[u][3]) begin
                                    if (!found_match) begin
                                        found_match = 1'b1;
                                        match_idx   = u;
                                    end
                                end
                            end
                        end

                        if (found_match) begin
                            if (next_counts[match_idx] < 3'd4) begin
                                next_counts[match_idx] = next_counts[match_idx] + 3'd1;
                            end
                        end else begin
                            for (int u = 0; u < 4; u++) begin
                                if (!used_slot[u] && empty_idx == -1) begin
                                    empty_idx = u;
                                end
                            end
                            if (empty_idx != -1) begin
                                next_unique_lists[empty_idx] = sublists[s];
                                next_counts[empty_idx]       = 3'd1;
                                used_slot[empty_idx]         = 1'b1;
                            end
                        end
                    end

                    next_state = BUSY;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Sequential update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state      <= IDLE;
            cycle_cnt  <= 3'd0;
            done       <= 1'b0;
            for (int i = 0; i < 4; i++) begin
                counts[i]       <= 3'd0;
                unique_lists[i] <= '{default:8'd0};
            end
        end else begin
            state        <= next_state;
            cycle_cnt    <= next_cycle_cnt;
            done         <= next_done;
            for (int i = 0; i < 4; i++) begin
                counts[i]       <= next_counts[i];
                unique_lists[i] <= next_unique_lists[i];
            end
        end
    end

endmodule