module pizza_solver (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_friends,   // Number of friends (1-4)
    input [2:0] num_toppings,  // Number of unique toppings (1-8)
    input [31:0] wishes [0:3], // Wishes for 4 friends, 4 wishes each.
    output reg found,
    output reg [7:0] selection  // Bitmask of selected toppings (1 = include, 0 = exclude)
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CHECK = 2'b01;
    localparam UPDATE = 2'b10;
    localparam DONE = 2'b11;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] subset_reg;       // Current subset being checked
    reg [7:0] next_subset;      // Next subset value
    reg [2:0] friend_idx;       // Current friend being evaluated
    reg [1:0] wish_idx;         // Current wish within the friend (0 to 3)
    reg [2:0] satisfied_count;  // Count of satisfied wishes for current friend
    reg friend_happy;           // Is current friend happy with current subset?
    reg all_friends_happy;      // OR reduction of friend_happy status across all friends
    
    // Combinational logic for wish decoding and checking
    wire [7:0] current_wish;    // The 8-bit wish vector for current friend/wish
    wire [2:0] wish_top_idx;    // Topping index from wish
    wire wish_type;             // Type from wish (1=wants, 0=doesn't want)
    wire topping_selected;      // Is the topping in the current subset?
    wire wish_satisfied;        // Is this specific wish satisfied?

    // Extract current wish from the 2D input array
    // wishes[friend_idx] is 32 bits containing 4 wishes.
    // We need to select the correct 8-bit chunk.
    // Wish 0: bits [7:0], Wish 1: bits [15:8], Wish 2: bits [23:16], Wish 3: bits [31:24]
    assign current_wish = wishes[friend_idx][(wish_idx * 8) +: 8];

    // Decode Wish
    assign wish_top_idx = current_wish[7:5];
    assign wish_type = current_wish[4];

    // Check Topping in Subset
    assign topping_selected = subset_reg[wish_top_idx];

    // Check Satisfaction
    // Type 1 ('+') wants topping selected. Type 0 ('-') wants topping NOT selected.
    assign wish_satisfied = (wish_type && topping_selected) || (!wish_type && !topping_selected);

    // State Transition Logic
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_reg <= 8'h00;
            friend_idx <= 3'b000;
            wish_idx <= 2'b00;
            satisfied_count <= 3'b000;
            all_friends_happy <= 1'b0;
            found <= 1'b0;
            selection <= 8'h00;
        end else begin
            state <= next_state;
            
            // Registers Updates based on state
            case (state)
                IDLE: begin
                    if (start) begin
                        subset_reg <= 8'h00;
                        friend_idx <= 3'b000;
                        wish_idx <= 2'b00;
                        satisfied_count <= 3'b000;
                        all_friends_happy <= 1'b0;
                        found <= 1'b0;
                    end
                end

                CHECK: begin
                    // Update satisfaction count
                    if (wish_satisfied) begin
                        satisfied_count <= satisfied_count + 1;
                    end
                    // Advance wish counter
                    if (wish_idx == 2'b11) begin
                        wish_idx <= 2'b00;
                        // Calculate if friend is happy (Strictly more than 1.33 means >= 2)
                        // satisfied_count will be finalized in next cycle (UPDATE)
                    end else begin
                        wish_idx <= wish_idx + 1;
                    end
                end

                UPDATE: begin
                    // Determine if friend was happy based on count from CHECK
                    // satisfied_count is the count of 4 wishes just processed.
                    // We need to know if satisfied_count >= 2.
                    // However, satisfied_count was incremented in CHECK.
                    // The logic for friend_happy is combinational, but let's store the OR result.
                    
                    if (satisfied_count >= 2) begin
                        // Friend happy, keep OR high
                        all_friends_happy <= 1'b1;
                    end
                    
                    // Move to next friend
                    friend_idx <= friend_idx + 1;
                    
                    // Reset count for next friend
                    satisfied_count <= 3'b000;
                end

                DONE: begin
                    // Latch result
                    if (!found) begin
                        found <= 1'b1;
                        selection <= subset_reg;
                    end
                end
            endcase
        end
    end

    // Next State Logic
    always @ (*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end

            CHECK: begin
                // Process 4 wishes per friend
                if (wish_idx == 2'b11) begin
                    next_state = UPDATE; // Finished 4 wishes for this friend
                end else begin
                    next_state = CHECK;
                end
            end

            UPDATE: begin
                // Check if we processed all friends
                // friend_idx was incremented in previous UPDATE or initialized to 0
                // We need to check if friend_idx (before increment or after) reached num_friends
                // Wait, in UPDATE state we just incremented friend_idx.
                // So check if (friend_idx == num_friends) means we just finished the last friend.
                // Actually, friend_idx increments at the end of UPDATE.
                // If we were at friend 0, it becomes 1. If num_friends=1, 1==1 is true.
                
                if (friend_idx + 1 == num_friends) begin
                    // We just finished the last friend.
                    // Check result of all_friends_happy
                    if (all_friends_happy) begin
                        next_state = DONE;
                    end else begin
                        // Move to next subset
                        if (subset_reg == 8'hFF) begin // Should not happen per spec, but safety
                            next_state = DONE; 
                        end else begin
                            next_state = CHECK;
                        end
                    end
                end else begin
                    // More friends to check
                    next_state = CHECK;
                end
            end

            DONE: begin
                next_state = DONE; // Sticky state
            end

            default: next_state = IDLE;
        endcase
    end

    // Combinational Logic for friend_happy check in UPDATE logic
    // We need to know inside UPDATE if satisfied_count >= 2.
    // Since satisfied_count is updated in CHECK, by the time we enter UPDATE, it holds the count for the previous friend.
    // Wait, cycle analysis:
    // 1. CHECK (Wish 3): wish_satisfied calculated. satisfied_count updates to total.
    // 2. State switches to UPDATE. satisfied_count is correct.
    // 3. Logic inside UPDATE uses satisfied_count.
    
    // However, inside the combinational always block for next_state, we reference friend_idx.
    // friend_idx increments in the sequential block at the end of UPDATE.
    // So inside UPDATE state, friend_idx is still the index of the friend we JUST finished.
    
    // Let's fix the UPDATE sequential logic to handle the set/reset of all_friends_happy correctly.
    // Actually, `all_friends_happy` acts as an accumulator.
    
    // Logic for subset iteration in UPDATE state when moving to next subset:
    // We need to increment subset_reg if all_friends_happy was low.
    // Since subset_reg is a register, we need to drive it from an always block or use a continuous assignment for next value.
    // Let's update subset_reg in the sequential block.

    // Revising the sequential block for subset_reg increment:
    always @ (posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // handled above
        end else if (state == UPDATE && friend_idx + 1 == num_friends && !all_friends_happy) begin
            // If we are at the end of checking friends for current subset, and not happy, increment subset
            subset_reg <= subset_reg + 1;
            friend_idx <= 3'b000; // Reset friend index for new subset
            wish_idx <= 2'b00;
            satisfied_count <= 3'b000;
            all_friends_happy <= 1'b0; // Reset accumulator
        end else if (state == UPDATE && friend_idx + 1 == num_friends && all_friends_happy) begin
            // Found solution, go to DONE (handled by next_state logic)
            // Keep values stable
        end
    end

    // Correction: The logic for `all_friends_happy` accumulation needs to be precise.
    // When transitioning from CHECK to UPDATE (end of a friend's wishes):
    // The sequential block inside UPDATE updates friend_idx and resets satisfied_count.
    // It sets all_friends_happy if satisfied_count >= 2.
    // But if friend_idx was 0, it becomes 1. If friend_idx was 1, it becomes 2.
    
    // Let's rewrite the sequential block more cleanly to separate concerns.
    // We need a flag to signal "End of Friends for this Subset" to trigger subset increment.
    // Let's use a wire for that.
    wire end_of_friends;
    assign end_of_friends = (friend_idx == num_friends - 1);
    // Note: friend_idx is the current index being processed in CHECK/UPDATE.
    // In UPDATE state, we are finishing friend_idx.
    
    // Let's restart the sequential logic to be more explicit and avoid race conditions.
    
    // RE-WRITTEN SEQUENTIAL BLOCK FOR CORRECTNESS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            subset_reg <= 8'h00;
            friend_idx <= 3'b0;
            wish_idx <= 2'b0;
            satisfied_count <= 3'b0;
            all_friends_happy <= 1'b0;
            found <= 1'b0;
            selection <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= CHECK;
                        subset_reg <= 8'h00;
                        friend_idx <= 3'b0;
                        wish_idx <= 2'b0;
                        satisfied_count <= 3'b0;
                        all_friends_happy <= 1'b0;
                        found <= 1'b0;
                    end
                end

                CHECK: begin
                    // Process wish
                    if (wish_satisfied) satisfied_count <= satisfied_count + 1;

                    if (wish_idx == 2'b11) begin
                        // This was the 4th wish (index 3).
                        // Transition to UPDATE in next cycle.
                        state <= UPDATE;
                        wish_idx <= 2'b00; // Reset for next friend
                    end else begin
                        // Continue checking wishes
                        wish_idx <= wish_idx + 1;
                    end
                end

                UPDATE: begin
                    // satisfied_count holds the total for the friend just checked (friend_idx)
                    // Check friend happiness
                    if (satisfied_count >= 2) begin
                        // Accumulate happiness
                        all_friends_happy <= all_friends_happy | 1'b1;
                    end

                    // Check if this was the last friend
                    if (friend_idx == num_friends - 1) begin
                        // Last friend processed
                        if (all_friends_happy && satisfied_count >= 2) begin
                            // All happy
                            state <= DONE;
                            found <= 1'b1;
                            selection <= subset_reg;
                        end else begin
                            // Not all happy
                            // Try next subset
                            if (subset_reg == 8'hFF) begin
                                // Overflow, just stop (should not happen)
                                state <= DONE;
                                found <= 1'b0;
                            end else begin
                                subset_reg <= subset_reg + 1;
                                friend_idx <= 3'b0;
                                satisfied_count <= 3'b0;
                                all_friends_happy <= 1'b0;
                                state <= CHECK;
                            end
                        end
                    end else begin
                        // More friends to check
                        friend_idx <= friend_idx + 1;
                        satisfied_count <= 3'b0;
                        state <= CHECK;
                    end
                end

                DONE: begin
                    // Stay in done state
                end
            endcase
        end
    end

endmodule
