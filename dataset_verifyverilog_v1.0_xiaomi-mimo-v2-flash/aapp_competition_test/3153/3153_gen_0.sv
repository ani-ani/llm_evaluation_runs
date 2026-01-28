module card_collection_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,
    input [7:0] M,
    input [7:0] targets [0:15],
    input [15:0] purchases [0:7],
    output reg out_valid,
    output reg [1:0] out_type,
    output reg [63:0] out_data,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] RESET_COUNTS = 3'd1;
    localparam [2:0] PROCESS_INPUTS = 3'd2;
    localparam [2:0] FIX_DEFICITS  = 3'd3;
    localparam [2:0] OUTPUT_COUNT = 3'd4;
    localparam [2:0] OUTPUT_TRANSACTIONS = 3'd5;
    localparam [2:0] OUTPUT_END  = 3'd6;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [7:0] current_counts [0:15];
    reg [7:0] final_targets [0:15];
    reg [15:0] input_purchases [0:7];
    
    // Transaction buffer: 512 entries of 24 bits
    // Packed as 32-bit words for efficiency, only lower 24 bits used
    reg [31:0] trans_buffer [0:511];
    reg [8:0] trans_idx; // 0-511
    reg [8:0] trans_count;
    reg [8:0] output_idx;
    
    // Helper registers
    reg [7:0] i, j;
    reg [7:0] m_idx;
    reg [3:0] n_idx;
    reg [7:0] temp_count;
    reg [7:0] temp_target;
    reg [7:0] rich_idx;
    reg [7:0] poor_idx;
    reg [7:0] donor_idx;
    reg [7:0] receiver_idx;
    reg [7:0] found_rich;
    reg [7:0] found_poor;
    reg [7:0] child_a, child_b, child_winner;
    reg [7:0] cards_a, cards_b;
    reg [15:0] purchase_raw;
    reg [7:0] total_cards;
    reg [7:0] a_target, b_target;
    reg [7:0] a_current, b_current;
    reg needs_a, needs_b;
    
    // Output control
    reg out_done;
    reg [8:0] out_trans_remain;
    reg [63:0] temp_out_data;
    reg [1:0] temp_out_type;
    reg temp_out_valid;
    
    integer k;

    // Sequential logic for state transitions and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            out_valid <= 1'b0;
            out_type <= 2'd0;
            out_data <= 64'd0;
            done <= 1'b0;
            trans_idx <= 9'd0;
            trans_count <= 9'd0;
            m_idx <= 8'd0;
            i <= 8'd0;
            total_cards <= 8'd0;
            out_trans_remain <= 9'd0;
            output_idx <= 9'd0;
            // Initialize arrays
            for (k = 0; k < 16; k = k + 1) begin
                current_counts[k] <= 8'd0;
                final_targets[k] <= 8'd0;
            end
            for (k = 0; k < 8; k = k + 1) begin
                input_purchases[k] <= 16'd0;
            end
            for (k = 0; k < 512; k = k + 1) begin
                trans_buffer[k] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    out_valid <= 1'b0;
                    if (start) begin
                        // Capture inputs
                        for (k = 0; k < 16; k = k + 1) begin
                            final_targets[k] <= targets[k];
                        end
                        for (k = 0; k < 8; k = k + 1) begin
                            input_purchases[k] <= purchases[k];
                        end
                        m_idx <= 8'd0;
                        trans_idx <= 9'd0;
                        i <= 8'd0;
                        state <= RESET_COUNTS;
                    end
                end

                RESET_COUNTS: begin
                    // Reset current counts to 0
                    if (i < N) begin
                        current_counts[i] <= 8'd0;
                        i <= i + 8'd1;
                    end else begin
                        i <= 8'd0;
                        state <= PROCESS_INPUTS;
                    end
                end

                PROCESS_INPUTS: begin
                    if (m_idx < M) begin
                        // Process one input purchase
                        purchase_raw = input_purchases[m_idx];
                        child_a = purchase_raw[7:0];
                        child_b = purchase_raw[15:8];
                        
                        // Only process if within valid range 1..N
                        if (child_a >= 8'd1 && child_a <= N && child_b >= 8'd1 && child_b <= N) begin
                            a_current = current_counts[child_a - 8'd1];
                            b_current = current_counts[child_b - 8'd1];
                            a_target = final_targets[child_a - 8'd1];
                            b_target = final_targets[child_b - 8'd1];
                            
                            needs_a = (a_current < a_target);
                            needs_b = (b_current < b_target);
                            
                            cards_a = 8'd0;
                            cards_b = 8'd0;
                            child_winner = 8'd0;
                            
                            if (needs_a && !needs_b) begin
                                cards_a = 8'd2;
                                child_winner = child_a;
                            end else if (!needs_a && needs_b) begin
                                cards_b = 8'd2;
                                child_winner = child_b;
                            end else if (needs_a && needs_b) begin
                                cards_a = 8'd1;
                                cards_b = 8'd1;
                                child_winner = 8'd0; // Tie
                            end else begin
                                // Neither needs, give 1 to A (arbitrary)
                                cards_a = 8'd1;
                                child_winner = child_a;
                            end
                            
                            // Update counts
                            current_counts[child_a - 8'd1] <= a_current + cards_a;
                            current_counts[child_b - 8'd1] <= b_current + cards_b;
                            
                            // Store transaction
                            if (trans_idx < 512) begin
                                trans_buffer[trans_idx] <= {8'd0, child_winner, child_b, child_a}; // [31:24]=padding, [23:16]=winner, [15:8]=b, [7:0]=a
                                trans_idx <= trans_idx + 9'd1;
                            end
                        end
                        m_idx <= m_idx + 8'd1;
                    end else begin
                        // Done with inputs, move to fix deficits
                        i <= 8'd0; // Reset for checking
                        state <= FIX_DEFICITS;
                    end
                end

                FIX_DEFICITS: begin
                    // Check if any child has deficit
                    if (i < N) begin
                        if (current_counts[i] < final_targets[i]) begin
                            // Found poor child, find rich child
                            poor_idx = i + 8'd1;
                            found_rich = 8'd0;
                            for (j = 0; j < N; j = j + 1) begin
                                if (j != i && current_counts[j] > final_targets[j]) begin
                                    found_rich = 8'd1;
                                    rich_idx = j + 8'd1;
                                end
                            end
                            
                            // Prepare transfer
                            if (found_rich) begin
                                donor_idx = rich_idx;
                                receiver_idx = poor_idx;
                                // Update counts immediately
                                current_counts[rich_idx - 8'd1] <= current_counts[rich_idx - 8'd1] - 8'd1;
                                current_counts[i] <= current_counts[i] + 8'd1;
                            end else begin
                                // No rich child found, use dummy (1, 2) or (1, N)
                                // We need to create cards out of thin air or use a fixed donor
                                // Specification says "use a dummy donor" or "adjust counts".
                                // Let's assume we can add cards to a deficient child from a dummy source (e.g. child 1) if N > 1
                                // Or strictly follow "transfer 1 from donor". If no donor, we must add cards.
                                // To be deterministic and simple: Target (1, 2). If 1 is deficient, give to 1. If 1 is full, give to 1 from 2.
                                // Since we must match targets, if total sum of targets > total cards, we need to add.
                                // But "Transfer 1 card from donor" implies we need a donor.
                                // Let's find a child who has count >= target (not necessarily >, to maintain stability).
                                // Actually, if all are at target except one, and sum matches, there is a rich one.
                                // If sum of targets > sum of current, we are adding cards (dummy transaction).
                                // Let's simply use child 1 as donor if possible, else child 1 gets the card.
                                donor_idx = 8'd1;
                                receiver_idx = poor_idx;
                                if (current_counts[0] > final_targets[0]) begin
                                    current_counts[0] <= current_counts[0] - 8'd1;
                                    current_counts[i] <= current_counts[i] + 8'd1;
                                end else begin
                                    // Add card to receiver (dummy)
                                    current_counts[i] <= current_counts[i] + 8'd1;
                                end
                            end
                            
                            // Store transaction
                            if (trans_idx < 512) begin
                                // Spec says "create a purchase (1, 2)"
                                // We use donor_idx, receiver_idx, winner is receiver
                                trans_buffer[trans_idx] <= {8'd0, receiver_idx, donor_idx, 8'd1}; // {winner, b, a} with a=1, b=donor (or vice versa)
                                // Re-reading spec: "Transfer 1 card from donor to receiver"
                                // Transaction: {a, b, winner}. Usually winner receives.
                                // Let's output {1, donor_idx, receiver_idx} assuming receiver wins.
                                trans_buffer[trans_idx] <= {8'd0, receiver_idx, donor_idx, 8'd1};
                                trans_idx <= trans_idx + 9'd1;
                            end
                            
                            // Stay in this state to re-check the same i after update, or move to next?
                            // If we incremented count, it might still be deficient. Loop until satisfied.
                            // To prevent infinite loop, we assume we can eventually fix.
                            // Check again for same i.
                        end else begin
                            i <= i + 8'd1;
                        end
                    end else begin
                        // All children checked, move to output
                        trans_count <= trans_idx;
                        output_idx <= 9'd0;
                        state <= OUTPUT_COUNT;
                    end
                end

                OUTPUT_COUNT: begin
                    out_valid <= 1'b1;
                    out_type <= 2'd0; // Start
                    out_data <= {48'd0, 16'd0, trans_count[7:0]}; // Just lower 8 bits for count usually, but 16 bits allowed
                    out_data[15:0] <= trans_count; // Total purchases
                    done <= 1'b0;
                    state <= OUTPUT_TRANSACTIONS;
                end

                OUTPUT_TRANSACTIONS: begin
                    if (output_idx < trans_count) begin
                        out_valid <= 1'b1;
                        out_type <= 2'd1; // Transaction line
                        // Format: {a[7:0], b[7:0], winner[1:0]} (bits 23:0)
                        // We stored: {padding, winner[7:0], b[7:0], a[7:0]}
                        out_data <= {40'd0, trans_buffer[output_idx][23:0]};
                        output_idx <= output_idx + 9'd1;
                    end else begin
                        state <= OUTPUT_END;
                    end
                end

                OUTPUT_END: begin
                    out_valid <= 1'b1;
                    out_type <= 2'd2; // End
                    out_data <= 64'd0;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule