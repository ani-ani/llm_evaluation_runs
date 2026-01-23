module rating_equalizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] r0,
    input [3:0] r1,
    input [3:0] r2,
    input [3:0] r3,
    output reg [3:0] final_rating,
    output reg [5:0] match_count,
    output reg [3:0] match_friend0,
    output reg [3:0] match_friend1,
    output reg [3:0] match_friend2,
    output reg [3:0] match_friend3,
    output reg done
);

    // State Encoding
    localparam IDLE  = 2'b00;
    localparam CHECK = 2'b01;
    localparam UPDATE = 2'b10;
    localparam DONE  = 2'b11;

    // Registers
    reg [1:0] current_state;
    reg [1:0] next_state;
    reg [3:0] ratings [0:3]; // Current ratings: r0, r1, r2, r3
    reg [3:0] max_val;
    reg [3:0] next_max_val;
    reg [5:0] counter;
    reg [5:0] next_counter;
    reg [3:0] friend0_next, friend1_next, friend2_next, friend3_next;
    reg done_next;
    reg [3:0] final_rating_next;

    // Helper signals for max detection
    reg [3:0] max_temp1_0, max_temp1_1, max_temp1_2, max_temp1_3;
    reg [3:0] max_temp2_0, max_temp2_1;
    reg [3:0] final_max;

    // --- Next State Logic ---
    always @(*) begin
        next_state = current_state;
        next_counter = counter;
        done_next = 1'b0;
        final_rating_next = final_rating;
        friend0_next = match_friend0;
        friend1_next = match_friend1;
        friend2_next = match_friend2;
        friend3_next = match_friend3;
        next_max_val = max_val;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                    next_counter = 6'd0;
                    done_next = 1'b0;
                end
            end

            CHECK: begin
                // Check if all equal
                if (ratings[0] == ratings[1] && ratings[1] == ratings[2] && ratings[2] == ratings[3]) begin
                    next_state = DONE;
                    done_next = 1'b1;
                    final_rating_next = ratings[0];
                end else if (counter >= 64) begin
                    next_state = DONE;
                    done_next = 1'b1;
                    // Final rating is the average (or min) of remaining
                    // In this algorithm, it's simply the value at step limit
                    // If unequal at step limit, we take the min to be conservative or max? 
                    // Let's take the minimum of the ratings as the guaranteed equal level if not perfectly equal.
                    // Or just assign the current min rating.
                    // The prompt says "The result (final_rating and match_count) is valid when done is high".
                    // Let's report the minimum value present, as that is the base level reached.
                    if (ratings[0] <= ratings[1] && ratings[0] <= ratings[2] && ratings[0] <= ratings[3]) final_rating_next = ratings[0];
                    else if (ratings[1] <= ratings[2] && ratings[1] <= ratings[3]) final_rating_next = ratings[1];
                    else if (ratings[2] <= ratings[3]) final_rating_next = ratings[2];
                    else final_rating_next = ratings[3];
                end else begin
                    next_state = UPDATE;
                    // Logic to determine friends to update (needs to be combinatorial based on current ratings)
                    // We calculate this here to feed into the update state
                    
                    // Find Max logic
                    // Step 1: Compare pairs
                    max_temp1_0 = (ratings[0] >= ratings[1]) ? ratings[0] : ratings[1];
                    max_temp1_1 = (ratings[2] >= ratings[3]) ? ratings[2] : ratings[3];
                    max_temp1_2 = (ratings[0] >= ratings[1]) ? ratings[1] : ratings[0]; // 2nd max of first pair (or tie)
                    // Actually, we need to be careful with ties. 
                    // To strictly follow "3 or more share max", we need to identify all.
                    
                    // Let's refine the max finding logic for the match determination
                    // Determine max value first
                    max_temp2_0 = (ratings[0] >= ratings[1]) ? ratings[0] : ratings[1];
                    max_temp2_1 = (ratings[2] >= ratings[3]) ? ratings[2] : ratings[3];
                    final_max = (max_temp2_0 >= max_temp2_1) ? max_temp2_0 : max_temp2_1;
                    next_max_val = final_max;

                    // Determine friends involved
                    // Count how many have max_val
                    // If 3 or 4 have it -> reduce all who have it
                    // If 1 or 2 have it -> reduce top 2 (need to find second max if only 1 has it)
                    
                    // This logic determines the match bitmap
                    // It assumes next_max_val is set to the current max of ratings
                    
                    // Count occurrences of next_max_val
                    // If count >= 3 -> friends = all with next_max_val
                    // Else -> friends = all with next_max_val + the next highest one(s) to make 2
                    
                    // Let's just implement the selection logic inside the UPDATE state comb logic
                    // but doing it here implies we need to latch the intent or compute it in UPDATE.
                    // Computing it in UPDATE (based on inputs from CHECK) is safer for the latch inference.
                end
            end

            UPDATE: begin
                // Perform reduction and increment
                next_state = CHECK;
                next_counter = counter + 1;

                // The match selection was effectively determined at the transition from CHECK.
                // We need to derive it again or assume it was passed through combinational logic.
                // Given the constraint of Verilog, let's re-calculate who needs to be decremented.
                // This logic inside UPDATE will be combinational based on 'ratings' register.
                
                // Note: To avoid re-calculating everywhere, the specific bitmap generation logic 
                // is placed in the combinational block below this sequential block.
                // Here we just update the ratings array.
                
                // We will use the local updated rating values derived in the comb block.
                // But since we can't call a task easily in synthesis, we do it explicitly.
            end
            
            DONE: begin
                if (start) begin // Stay done or reset? Usually stay done until reset
                    next_state = IDLE;
                    done_next = 1'b0;
                end else begin
                    next_state = DONE;
                    done_next = 1'b1;
                end
            end
        endcase
    end

    // --- Sequential Logic (State Update & Registers) ---
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            match_count <= 6'd0;
            done <= 1'b0;
            final_rating <= 4'd0;
            match_friend0 <= 4'b0;
            match_friend1 <= 4'b0;
            match_friend2 <= 4'b0;
            match_friend3 <= 4'b0;
            // Reset ratings don't matter in IDLE until start
            ratings[0] <= 4'd0;
            ratings[1] <= 4'd0;
            ratings[2] <= 4'd0;
            ratings[3] <= 4'd0;
            max_val <= 4'd0;
            counter <= 6'd0;
        end else begin
            current_state <= next_state;
            match_count <= next_counter;
            done <= done_next;
            final_rating <= final_rating_next;
            counter <= next_counter;
            max_val <= next_max_val;
            
            // Update friends bitmap in UPDATE state (or capture it in CHECK->UPDATE transition)
            // We need to capture the match info when we enter UPDATE or perform the match.
            // Let's update the output registers in the UPDATE state.
            if (current_state == UPDATE) begin
                 match_friend0 <= friend0_next;
                 match_friend1 <= friend1_next;
                 match_friend2 <= friend2_next;
                 match_friend3 <= friend3_next;
            end

            if (current_state == IDLE && start) begin
                ratings[0] <= r0;
                ratings[1] <= r1;
                ratings[2] <= r2;
                ratings[3] <= r3;
            end else if (current_state == UPDATE) begin
                // Apply the decrements based on the decision logic
                if (friend0_next[0]) ratings[0] <= (ratings[0] > 0) ? ratings[0] - 1 : 0;
                if (friend0_next[1]) ratings[1] <= (ratings[1] > 0) ? ratings[1] - 1 : 0;
                if (friend0_next[2]) ratings[2] <= (ratings[2] > 0) ? ratings[2] - 1 : 0;
                if (friend0_next[3]) ratings[3] <= (ratings[3] > 0) ? ratings[3] - 1 : 0;
            end
        end
    end

    // --- Combinational Logic for Match Selection & Update Calculation ---
    always @(*) begin
        // Defaults
        friend0_next = 4'b1111; // Invalid index
        friend1_next = 4'b1111;
        friend2_next = 4'b1111;
        friend3_next = 4'b1111;
        
        // Recalculate Max for the current ratings in CHECK state
        // We need this to decide who to update in UPDATE state
        // Note: This logic is active whenever we are about to enter UPDATE or in UPDATE logic calculation.
        
        // Determine Max Value
        max_temp1_0 = (ratings[0] >= ratings[1]) ? ratings[0] : ratings[1];
        max_temp1_1 = (ratings[2] >= ratings[3]) ? ratings[2] : ratings[3];
        max_temp1_2 = (ratings[0] >= ratings[1]) ? ratings[1] : ratings[0]; // Min of pair 0
        max_temp1_3 = (ratings[2] >= ratings[3]) ? ratings[3] : ratings[2]; // Min of pair 1
        
        reg [3:0] max_val_local;
        reg [3:0] second_max_val_local;

        // Max of pairs
        reg [3:0] pair0_max = max_temp1_0;
        reg [3:0] pair1_max = max_temp1_1;
        
        // Global max
        if (pair0_max >= pair1_max) max_val_local = pair0_max;
        else max_val_local = pair1_max;

        // Second Max logic is complex. 
        // If pair0_max > pair1_max, 2nd max is max(pair0_min, pair1_max)
        // If pair1_max > pair0_max, 2nd max is max(pair1_min, pair0_max)
        // If equal, 2nd max is max(pair0_min, pair1_min) 
        
        if (pair0_max > pair1_max) begin
            second_max_val_local = (max_temp1_2 >= pair1_max) ? max_temp1_2 : pair1_max;
        end else if (pair1_max > pair0_max) begin
            second_max_val_local = (max_temp1_3 >= pair0_max) ? max_temp1_3 : pair0_max;
        end else begin
            // Tie for max
            second_max_val_local = (max_temp1_2 >= max_temp1_3) ? max_temp1_2 : max_temp1_3;
        end

        // Now, identify friends with max_val and second_max_val
        // We need to count how many friends have max_val
        integer i;
        reg [1:0] max_count;
        reg [1:0] sec_max_count;
        max_count = 0;
        sec_max_count = 0;
        
        // Arrays to hold indices
        reg [3:0] max_friends [0:3];
        reg [3:0] sec_friends [0:3];
        
        for (i=0; i<4; i=i+1) begin
            max_friends[i] = 4'b1111;
            sec_friends[i] = 4'b1111;
        end

        for (i=0; i<4; i=i+1) begin
            if (ratings[i] == max_val_local) begin
                if (max_count < 4) max_friends[max_count] = i;
                max_count = max_count + 1;
            end else if (ratings[i] == second_max_val_local) begin
                if (sec_max_count < 4) sec_friends[sec_max_count] = i;
                sec_max_count = sec_max_count + 1;
            end
        end

        // Determine match friends based on algorithm
        // If 3 or more friends share the max rating, reduce all of them.
        // Otherwise, reduce the top 2 friends.
        
        if (max_count >= 3) begin
            // Reduce all max friends
            // If max_count == 3, we fill friend0, friend1, friend2
            // If max_count == 4, we fill all 4
            friend0_next = max_friends[0];
            friend1_next = max_friends[1];
            friend2_next = max_friends[2];
            friend3_next = max_friends[3];
        end else begin
            // Reduce top 2.
            // If max_count == 1, we need 1 max friend + 1 second max friend (or more if ties in second)
            // If max_count == 2, we need 2 max friends.
            
            if (max_count == 2) begin
                friend0_next = max_friends[0];
                friend1_next = max_friends[1];
                // If we need to fill up to 4? No, "Reduce the top 2 friends".
                // The phrasing "reduce the top 2" implies exactly 2 friends.
            end else if (max_count == 1) begin
                // One max, need one more.
                // We need to pick the second highest.
                // If there are multiple second highest, pick 1? Or pick all?
                // "Reduce the top 2 friends". 
                // 1 max + 1 second max. 
                // If multiple second max exist, we might want to pick all to equalize fastest?
                // But the prompt doesn't specify. Let's pick one (the first found) or all?
                // If we pick all, we might end up with >2 friends, which conflicts with "top 2".
                // However, "top 2 friends" usually means the two highest individuals.
                // If there are ties for the second spot, we usually reduce all tied to avoid bias.
                // But let's stick to "top 2" literally, or maybe "the highest rated players" (plural).
                // Let's interpret "top 2 friends" as the top 2 ranks. 
                // Rank 1: Max. Rank 2: Second Max.
                // If multiple in Rank 2, it's ambiguous.
                // Let's reduce 2 friends: The max one, and one of the second max ones (arbitrary, say the lowest index).
                // Wait, "Reduce the top 2 friends". 
                // Let's assume if 1 max and 3 second max, we just reduce the 1 max and 1 second max to keep it to 2.
                // Or maybe the prompt implies we should just reduce the top 2 individuals, and if there are ties we handle it.
                // Let's look at the objective: "To maximize the final rating".
                // Reducing more people increases the final rating. 
                // So I should actually reduce ALL friends who are in the top 2 tiers.
                // BUT, the prompt says "If 3 or more share max... reduce all. Otherwise reduce top 2."
                // This implies a distinct switch. 
                // If 1 max, 3 second max: 
                //   Case A: Reduce 2 (max + one second). 
                //   Case B: Reduce 4 (all).
                //   Case C: Reduce 2 (two seconds)? No, max is highest.
                //   Let's go with Case A: Reduce exactly 2 friends to be safe with "top 2".
                
                friend0_next = max_friends[0];
                // Need one more. 
                // If there are second max friends, pick the first one.
                if (sec_max_count > 0) friend1_next = sec_friends[0];
                else friend1_next = 4'b1111; // Should not happen if not equal
            end
        end
    end

endmodule