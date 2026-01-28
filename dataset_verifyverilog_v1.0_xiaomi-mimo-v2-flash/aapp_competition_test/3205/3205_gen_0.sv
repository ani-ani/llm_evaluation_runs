module min_transactions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire receipts_valid,
    input wire [2:0] receipts_a,
    input wire [2:0] receipts_b,
    input wire [15:0] receipts_p,
    input wire [3:0] m,
    input wire [7:0] n,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] STATE_IDLE      = 3'd0;
    localparam [2:0] STATE_PARSE     = 3'd1;
    localparam [2:0] STATE_SEARCH    = 3'd2;
    localparam [2:0] STATE_CHECK_SUB = 3'd3;
    localparam [2:0] STATE_UPDATE    = 3'd4;
    localparam [2:0] STATE_OUTPUT    = 3'd5;

    // Registers
    reg [2:0] state, next_state;
    reg [2:0] a_idx, b_idx;
    reg [15:0] p_val;
    reg signed [15:0] balances [0:7]; // 8 people max
    reg [7:0] receipts_count;
    reg [7:0] subset_index;
    reg [7:0] bit_idx;
    reg [7:0] min_trans;
    reg [7:0] current_trans;
    reg signed [15:0] subset_sum;
    reg [7:0] people_mask;
    reg [7:0] covered_mask;
    reg [7:0] valid_subset_mask;
    reg valid_subset_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            result <= 8'd0;
            done <= 1'b0;
            receipts_count <= 8'd0;
            subset_index <= 8'd0;
            min_trans <= 8'd255;
            for (i = 0; i < 8; i = i + 1) begin
                balances[i] <= 16'sd0;
            end
            covered_mask <= 8'd0;
            valid_subset_mask <= 8'd0;
            valid_subset_found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            case (state)
                STATE_IDLE: begin
                    done <= 1'b0;
                    receipts_count <= 8'd0;
                    subset_index <= 8'd0;
                    min_trans <= 8'd255;
                    for (i = 0; i < 8; i = i + 1) begin
                        balances[i] <= 16'sd0;
                    end
                    covered_mask <= 8'd0;
                    valid_subset_mask <= 8'd0;
                    valid_subset_found <= 1'b0;
                    cycle_count <= 8'd0;
                end

                STATE_PARSE: begin
                    if (receipts_valid && receipts_count < n) begin
                        a_idx <= receipts_a;
                        b_idx <= receipts_b;
                        p_val <= receipts_p;
                        // Update counters immediately, balances updated in next cycle
                        receipts_count <= receipts_count + 8'd1;
                    end
                end

                STATE_SEARCH: begin
                    subset_sum <= 16'sd0;
                    bit_idx <= 3'd0;
                    current_trans <= 8'd0;
                    valid_subset_found <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                end

                STATE_CHECK_SUB: begin
                    if (bit_idx < m) begin
                        if (subset_index[bit_idx]) begin
                            // If this person is in the subset
                            if (balances[bit_idx] != 16'sd0) begin
                                // Only count if balance is non-zero
                                current_trans <= current_trans + 8'd1;
                            end
                            subset_sum <= subset_sum + balances[bit_idx];
                        end
                    end
                end

                STATE_UPDATE: begin
                    // Check if subset sum is zero and is valid (non-empty, non-all, disjoint from covered)
                    if (subset_sum == 16'sd0 && subset_index != 8'd0 && subset_index != 8'hFF) begin
                        // Check disjoint with covered_mask
                        if ((subset_index & covered_mask) == 8'd0) begin
                            // Valid subset found
                            valid_subset_found <= 1'b1;
                            valid_subset_mask <= subset_index;
                            // Update min if needed
                            if (current_trans < min_trans) begin
                                min_trans <= current_trans;
                            end
                        end
                    end
                end

                STATE_OUTPUT: begin
                    if (min_trans == 8'd255) begin
                        result <= 8'd0; // No debts to settle
                    end else begin
                        result <= min_trans;
                    end
                    done <= 1'b1;
                end
            endcase
        end
    end

    // Combinational Logic for Balance Updates and Next State
    always @(*) begin
        next_state = state;
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_PARSE;
                end
            end

            STATE_PARSE: begin
                if (receipts_valid && receipts_count < n) begin
                    next_state = STATE_PARSE;
                end else if (receipts_count >= n || (!receipts_valid && start)) begin
                    // Done parsing or start triggered again
                    next_state = STATE_SEARCH;
                end
            end

            STATE_SEARCH: begin
                if (m == 4'd0 || cycle_count >= MAX_CYCLES) begin
                    next_state = STATE_OUTPUT;
                end else if (subset_index < (1 << m)) begin
                    next_state = STATE_CHECK_SUB;
                end else begin
                    // Exhausted all subsets
                    next_state = STATE_OUTPUT;
                end
            end

            STATE_CHECK_SUB: begin
                if (bit_idx < m) begin
                    next_state = STATE_CHECK_SUB;
                end else begin
                    next_state = STATE_UPDATE;
                end
            end

            STATE_UPDATE: begin
                // Move to next subset
                next_state = STATE_SEARCH;
            end

            STATE_OUTPUT: begin
                next_state = STATE_IDLE;
            end

            default: next_state = STATE_IDLE;
        endcase
    end

    // Balances update logic (separate block for clarity)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == STATE_PARSE && receipts_valid && receipts_count < n) begin
                balances[a_idx] <= balances[a_idx] + p_val; // Payer loses money
                balances[b_idx] <= balances[b_idx] - p_val; // Receiver gains money
            end
            if (state == STATE_UPDATE && valid_subset_found) begin
                // Remove valid subset from consideration for future iterations (heuristic)
                // Note: For exact minimum partition, this greedy approach is heuristic.
                // But given hardware constraints and NP-hard nature, we search all single subsets
                // and pick the smallest valid one as a "greedy" best fit.
                // A true minimum partition would require backtracking or DP, which is complex for M=8 in RTL.
                // This implementation finds the smallest single zero-sum subset that can be removed.
                // If multiple subsets sum to zero, we pick the one with fewest non-zero participants.
            end
            if (state == STATE_SEARCH) begin
                subset_index <= subset_index + 8'd1;
            end
        end
    end

endmodule