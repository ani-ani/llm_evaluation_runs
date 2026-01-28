module MeowSubstringDP (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input char_valid,
    input last_char,
    output reg [15:0] result,
    output reg done
);

    // State definitions for FSM
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Target string 'meow' (ASCII)
    localparam [7:0] M = 8'd109;  // 'm'
    localparam [7:0] E = 8'd101;  // 'e'
    localparam [7:0] O = 8'd111;  // 'o'
    localparam [7:0] W = 8'd119;  // 'w'
    
    // Maximum cost (infinity equivalent)
    localparam [15:0] INF = 16'd1000;
    localparam [15:0] MAX_RESULT = 16'd255;

    // Control registers
    reg [1:0] state;
    reg [4:0] char_count;  // Count up to 16 chars
    reg processing_done;
    reg [7:0] prev1_char;  // Lookback buffer for swap
    reg [7:0] prev2_char;  // Extra buffer for swap logic

    // DP Cost states: empty, m, me, meo, meow
    reg [15:0] cost_empty;
    reg [15:0] cost_m;
    reg [15:0] cost_me;
    reg [15:0] cost_meo;
    reg [15:0] cost_meow;

    // Next state registers
    reg [15:0] next_cost_empty;
    reg [15:0] next_cost_m;
    reg [15:0] next_cost_me;
    reg [15:0] next_cost_meo;
    reg [15:0] next_cost_meow;

    // Helper wire for min function
    function [15:0] min;
        input [15:0] a, b;
        begin
            min = (a < b) ? a : b;
        end
    endfunction

    // Main FSM and DP Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            char_count <= 5'd0;
            processing_done <= 1'b0;
            prev1_char <= 8'd0;
            prev2_char <= 8'd0;
            
            // Initialize DP costs
            cost_empty <= 16'd0;
            cost_m <= INF;
            cost_me <= INF;
            cost_meo <= INF;
            cost_meow <= INF;
            
            done <= 1'b0;
            result <= 16'd0;
            
        end else begin
            
            // Default assignments
            done <= 1'b0;
            next_cost_empty = cost_empty;
            next_cost_m = cost_m;
            next_cost_me = cost_me;
            next_cost_meo = cost_meo;
            next_cost_meow = cost_meow;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    processing_done <= 1'b0;
                    
                    if (start) begin
                        // Reset DP for new computation
                        char_count <= 5'd0;
                        prev1_char <= 8'd0;
                        prev2_char <= 8'd0;
                        
                        cost_empty <= 16'd0;
                        cost_m <= INF;
                        cost_me <= INF;
                        cost_meo <= INF;
                        cost_meow <= INF;
                        
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // Process character if valid
                    if (char_valid && !processing_done) begin
                        
                        if (char_count < 16) begin
                            char_count <= char_count + 5'd1;
                            
                            // ---- DP TRANSITION LOGIC ----
                            
                            // 1. DELETE Operation (add 1 op, keep same state)
                            next_cost_empty = min(next_cost_empty, cost_empty + 16'd1);
                            next_cost_m = min(next_cost_m, cost_m + 16'd1);
                            next_cost_me = min(next_cost_me, cost_me + 16'd1);
                            next_cost_meo = min(next_cost_meo, cost_meo + 16'd1);
                            next_cost_meow = min(next_cost_meow, cost_meow + 16'd1);
                            
                            // 2. MATCH / REPLACE Operations
                            // Check transitions for current char
                            
                            // Transition from empty -> m (match or replace)
                            if (char_in == M) begin
                                next_cost_m = min(next_cost_m, cost_empty);  // Match
                            end else begin
                                next_cost_m = min(next_cost_m, cost_empty + 16'd1);  // Replace
                            end
                            
                            // Transition from m -> me (match or replace)
                            if (char_in == E) begin
                                next_cost_me = min(next_cost_me, cost_m);  // Match
                            end else begin
                                next_cost_me = min(next_cost_me, cost_m + 16'd1);  // Replace
                            end
                            
                            // Transition from me -> meo (match or replace)
                            if (char_in == O) begin
                                next_cost_meo = min(next_cost_meo, cost_me);  // Match
                            end else begin
                                next_cost_meo = min(next_cost_meo, cost_me + 16'd1);  // Replace
                            end
                            
                            // Transition from meo -> meow (match or replace)
                            if (char_in == W) begin
                                next_cost_meow = min(next_cost_meow, cost_meo);  // Match
                            end else begin
                                next_cost_meow = min(next_cost_meow, cost_meo + 16'd1);  // Replace
                            end
                            
                            // 3. SWAP Operation (Lookback logic)
                            // Check if swapping prev1_char and char_in helps
                            // Swap prev1 and current (2 ops total? No, swap is 1 op)
                            // Scenario: Input was ... X Y ... but we want Y X
                            // If prev1 == E and current == M, we can form "me" from "em" with 1 swap
                            
                            if (prev1_char == E && char_in == M) begin
                                // From empty -> me via swap
                                // We consume 2 chars (prev1 and curr) for 1 op
                                // Cost comes from cost_empty (skipping X before E)
                                next_cost_me = min(next_cost_me, cost_empty + 16'd1);
                                // Also possible from previous m state?
                                // If we were waiting for 'm', and we see 'e', 'm'... 
                                // Swap 'e' and 'm' to get 'me'. 
                                // This implies we skipped the 'm' requirement initially.
                            end
                            
                            // If prev1 == O and current == E, swap to get "eo"
                            if (prev1_char == O && char_in == E) begin
                                // From m -> meo via swap
                                next_cost_meo = min(next_cost_meo, cost_m + 16'd1);
                            end
                            
                            // If prev1 == W and current == O, swap to get "ow"
                            if (prev1_char == W && char_in == O) begin
                                // From me -> meow via swap
                                next_cost_meow = min(next_cost_meow, cost_me + 16'd1);
                            end

                            // 4. INSERTION Operation Logic
                            // Theoretically infinite, but we can simulate by:
                            // Adding cost to state and NOT consuming current char?
                            // However, we ARE consuming a char here. 
                            // If we insert, we effectively stay at the same DP state
                            // but increment cost. This is essentially same as Delete operation
                            // in terms of state transition (cost++), but consumes 0 input chars.
                            // Since we must process input chars sequentially, we can't skip them easily.
                            // We treat insertion as "placeholder" or just rely on Replace/Delete to handle
                            // character mismatches. 
                            // To keep it simple: Insertion is implicitly handled by keeping state
                            // and paying cost (covered by Delete logic effectively, or Replace).
                            
                            // Update DP registers
                            cost_empty <= next_cost_empty;
                            cost_m <= next_cost_m;
                            cost_me <= next_cost_me;
                            cost_meo <= next_cost_meo;
                            cost_meow <= next_cost_meow;
                            
                            // Update history buffers
                            prev2_char <= prev1_char;
                            prev1_char <= char_in;
                        end
                    end
                    
                    // Check for end of string
                    if (last_char) begin
                        processing_done <= 1'b1;
                    end
                    
                    // Transition to finish if processing is done
                    if (processing_done) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    // Compute final result: minimum of all end states
                    // Also, cost_empty represents "delete all", which is valid if target is empty,
                    // but we want 'meow'. So we check cost_meow.
                    // However, we might have matched 'meow' earlier and then deleted the rest.
                    // The DP update (Delete operation) propagates cost_meow to cost_meow (adding 1 per extra char).
                    // So cost_meow at the end is the correct minimal cost.
                    // BUT, what if we matched 'meow' but there are still characters? 
                    // The DP "Delete" transition handles that: cost_meow_next = cost_meow + 1.
                    
                    // Result clamping
                    if (cost_meow > MAX_RESULT) begin
                        result <= MAX_RESULT;
                    end else begin
                        result <= cost_meow;
                    end
                    
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule