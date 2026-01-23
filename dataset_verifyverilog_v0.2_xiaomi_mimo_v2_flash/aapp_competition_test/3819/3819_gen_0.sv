module card_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] hand [0:7],
    input [7:0] pile [0:7],
    output reg [7:0] result,
    output reg done
);

    // State definition
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK_SEQ = 3'b010;
    localparam CALCULATE_COST = 3'b011;
    localparam DONE = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal storage for inputs
    reg [7:0] reg_hand [0:7];
    reg [7:0] reg_pile [0:7];

    // Helper registers
    reg [7:0] pile_idx; // Counter for various loops
    reg [7:0] v; // Card value iteration
    reg [7:0] pos_v; // Position of card v
    reg signed [9:0] cost_candidate; // Temp calculation
    reg signed [9:0] max_cost; // Max cost found so far
    reg found_in_hand; // Flag
    reg is_direct_win; // Flag
    reg [7:0] direct_win_cost; // Cost if direct win
    reg [7:0] sequence_end_val; // Value at end of sequence
    reg [7:0] missing_card; // First missing card in sequence

    integer i;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: next_state = CHECK_SEQ;
            CHECK_SEQ: next_state = (pile_idx >= 8) ? CALCULATE_COST : CHECK_SEQ;
            CALCULATE_COST: begin
                // Logic: 5 cycles for hand check + 8 cycles for cost calc = 13 cycles.
                // pile_idx 0-4: Hand check
                // v 1-8: Cost calc
                // We track progress via v (1..8). 
                // If v > 8, we are done.
                if (v > 8) next_state = DONE;
                else next_state = CALCULATE_COST;
            end
            DONE: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            pile_idx <= 0;
            v <= 0;
            max_cost <= 0;
            is_direct_win <= 0;
        end else begin
            case (state)
                IDLE: done <= 0;

                LOAD: begin
                    // Register inputs
                    for (i = 0; i < 8; i = i + 1) begin
                        reg_hand[i] <= hand[i];
                        reg_pile[i] <= pile[i];
                    end
                    // Reset counters
                    pile_idx <= 0;
                    v <= 0; // Will be 1 in first calc cycle
                    max_cost <= -1024;
                    is_direct_win <= 1; // Assume true initially
                    sequence_end_val <= 0;
                    missing_card <= 0;
                    direct_win_cost <= 0;
                end

                CHECK_SEQ: begin
                    // Iterate pile to find sequence 1, 2, ...
                    if (pile_idx < 8) begin
                        // Determine card we are looking for
                        // If pile_idx=0, we look for 1.
                        // If we found 1 at idx 0, next we look for 2 at idx 1.
                        // The logic implies checking if pile[pile_idx] == expected_card.
                        // Expected card = pile_idx - start_index + 1 is not enough if sequence starts at 2.
                        // We need to track the 'expected' card. Let's use 'v' as 'expected_card' here.
                        // But 'v' is used for cost calc later. Let's use 'pos_v' as 'expected_card' temporarily.
                        // No, 'pos_v' is used later. Let's use 'pile_idx' logic carefully.

                        // Refined: We look for card 1. Once found, we expect 2 at next index, etc.
                        // We can use 'pile_idx' as the index and 'v' as the expected value.
                        // Let's reuse 'v' for expected value in CHECK_SEQ.
                        // Init: v=1.

                        // We need to initialize v=1 at LOAD.
                        // So we need to check if v is 0.
                        // Actually, let's put initialization of v=1 at LOAD.

                        if (reg_pile[pile_idx] == v) begin
                            v <= v + 1; // Next expected
                            sequence_end_val <= reg_pile[pile_idx];
                            if (pile_idx == 0 && reg_pile[0] == 1) direct_win_cost <= 0;
                            else if (pile_idx == 1 && reg_pile[1] == 1) direct_win_cost <= 1;
                            else if (pile_idx == 2 && reg_pile[2] == 1) direct_win_cost <= 2;
                            else if (pile_idx == 3 && reg_pile[3] == 1) direct_win_cost <= 3;
                            else if (pile_idx == 4 && reg_pile[4] == 1) direct_win_cost <= 4;
                            else if (pile_idx == 5 && reg_pile[5] == 1) direct_win_cost <= 5;
                            else if (pile_idx == 6 && reg_pile[6] == 1) direct_win_cost <= 6;
                            else if (pile_idx == 7 && reg_pile[7] == 1) direct_win_cost <= 7;
                        end else begin
                            // Mismatch
                            // If we haven't found 1 yet, we ignore mismatch (keep expecting 1)
                            // If we found 1 (v > 1), this is a break.
                            if (v > 1 && missing_card == 0) missing_card <= v;
                            // If we haven't found 1 (v==1), we just continue.
                        end

                        pile_idx <= pile_idx + 1;
                    end

                    // Edge case: 1 not in pile
                    if (pile_idx == 7 && v == 1) is_direct_win <= 0;
                    // If break found (missing_card != 0), invalidate direct win at end of loop
                    if (pile_idx == 7 && missing_card != 0) is_direct_win <= 0;

                    // Reset v for cost calc phase (CALCULATE_COST)
                    // We will reset v=1 in CALCULATE_COST state entry or handle the phase transition.
                end

                CALCULATE_COST: begin
                    // Phase 1: Hand Check (runs 5 cycles)
                    // We use 'pile_idx' counter. In CHECK_SEQ it reached 8. Let's reset it to 0 at start of CALCULATE.
                    // But CHECK_SEQ ends when pile_idx >= 8. So pile_idx is 8 entering CALCULATE.
                    // We need a separate counter or reset pile_idx.
                    // Let's use 'pile_idx' as the cycle counter for CALCULATE.
                    // To reset it, we can check state transition.
                    // If we are just entering CALCULATE, pile_idx might be 8.
                    // Let's rely on the fact that we can just use 'pile_idx' and it will go 8, 9, 10...
                    // Hand check needs 0..4. We can map 8..12 to 0..4.
                    // Or simply use 'pile_idx - 8' for hand check.
                    // Let's stick to 'pile_idx - 8' for simplicity.

                    // Check if we are in Hand Check phase (pile_idx 8 to 12)
                    if (pile_idx < 13) begin
                        if (pile_idx < 8) begin
                            // Safety: if pile_idx is somehow < 8, just increment.
                            pile_idx <= pile_idx + 1;
                        end else begin
                            // Hand check phase (pile_idx 8..12)
                            // Offset for logic: cycle = pile_idx - 8 (0..4)
                            if (missing_card == 0 && is_direct_win) begin
                                // Target card = sequence_end_val + 1 + (pile_idx - 8)
                                // We can calculate this in a reg to use in comparison.
                                // Let's use 'v' to hold the target card value.
                                v <= sequence_end_val + 1 + (pile_idx - 8);

                                // Check hand
                                found_in_hand <= 0;
                                if (reg_hand[0] == v || reg_hand[1] == v || reg_hand[2] == v || reg_hand[3] == v ||
                                    reg_hand[4] == v || reg_hand[5] == v || reg_hand[6] == v || reg_hand[7] == v) begin
                                    found_in_hand <= 1;
                                end

                                // If not found and value <= 8, fail
                                if (!found_in_hand && v <= 8) is_direct_win <= 0;

                                // If last cycle (pile_idx 12), finalize direct win result
                                if (pile_idx == 12) begin
                                    if (is_direct_win) result <= direct_win_cost;
                                end
                            end

                            // Switch to Cost Calc phase
                            if (pile_idx == 12) v <= 1; // Reset v for cost loop
                            pile_idx <= pile_idx + 1;
                        end
                    end
                    // Phase 2: Cost Calculation (v = 1 to 8)
                    else if (v <= 8) begin
                        // v is already set to 1 (or incremented from prev)
                        // Find pos[v] in pile
                        pos_v <= 0; // Default 0 (in hand)
                        if (reg_pile[0] == v) pos_v <= 0;
                        else if (reg_pile[1] == v) pos_v <= 1;
                        else if (reg_pile[2] == v) pos_v <= 2;
                        else if (reg_pile[3] == v) pos_v <= 3;
                        else if (reg_pile[4] == v) pos_v <= 4;
                        else if (reg_pile[5] == v) pos_v <= 5;
                        else if (reg_pile[6] == v) pos_v <= 6;
                        else if (reg_pile[7] == v) pos_v <= 7;

                        // Calculate candidate: pos[v] - v + 1 + 8
                        cost_candidate <= pos_v - v + 9;

                        // Update max
                        if (cost_candidate > max_cost) max_cost <= cost_candidate;

                        // Increment v
                        v <= v + 1;

                        // If last value (v=8 being processed), we need to decide result in next cycle
                        // We will do final update when v becomes 9.
                    end else if (v == 9) begin
                        // Finalize
                        if (!is_direct_win) result <= max_cost[7:0];
                        v <= v + 1; // v = 10 to exit loop
                    end
                end

                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule