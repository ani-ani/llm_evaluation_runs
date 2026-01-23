module clock_setter(
    input clk,
    input rst_n,
    input start,
    input [7:0] start_hh,
    input [7:0] start_mm,
    input [7:0] target_hh,
    input [7:0] target_mm,
    output reg [7:0] current_hh,
    output reg [7:0] current_mm,
    output reg done,
    output reg [3:0] count
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam SETUP_MIN_ONES = 4'd1;
    localparam SETUP_MIN_TENS = 4'd2;
    localparam SETUP_MIN_ONES2 = 4'd3;
    localparam SETUP_HR_ONES = 4'd4;
    localparam SETUP_HR_TENS = 4'd5;
    localparam SETUP_HR_ONES2 = 4'd6;
    localparam DONE = 4'd7;

    reg [3:0] state, next_state;
    
    // Internal registers to store start and target times
    reg [7:0] start_hh_reg, start_mm_reg, target_hh_reg, target_mm_reg;
    
    // Helper wires for BCD digits
    wire [3:0] curr_mm_tens = current_mm[7:4];
    wire [3:0] curr_mm_ones = current_mm[3:0];
    wire [3:0] curr_hh_tens = current_hh[7:4];
    wire [3:0] curr_hh_ones = current_hh[3:0];
    
    wire [3:0] target_mm_tens = target_mm_reg[7:4];
    wire [3:0] target_mm_ones = target_mm_reg[3:0];
    wire [3:0] target_hh_tens = target_hh_reg[7:4];
    wire [3:0] target_hh_ones = target_hh_reg[3:0];
    
    // Direction flags (1: increment, 0: decrement)
    reg dir_mm_ones, dir_mm_tens, dir_hh_ones, dir_hh_tens;
    reg needs_mm_ones_change, needs_mm_tens_change;
    reg needs_hh_ones_change, needs_hh_tens_change;
    
    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_hh <= 8'h00;
            current_mm <= 8'h00;
            done <= 1'b0;
            count <= 4'd0;
            start_hh_reg <= 8'h00;
            start_mm_reg <= 8'h00;
            target_hh_reg <= 8'h00;
            target_mm_reg <= 8'h00;
            dir_mm_ones <= 1'b0;
            dir_mm_tens <= 1'b0;
            dir_hh_ones <= 1'b0;
            dir_hh_tens <= 1'b0;
            needs_mm_ones_change <= 1'b0;
            needs_mm_tens_change <= 1'b0;
            needs_hh_ones_change <= 1'b0;
            needs_hh_tens_change <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    if (start) begin
                        start_hh_reg <= start_hh;
                        start_mm_reg <= start_mm;
                        target_hh_reg <= target_hh;
                        target_mm_reg <= target_mm;
                        current_hh <= start_hh;
                        current_mm <= start_mm;
                        
                        // Calculate directions and needs for minutes
                        // Minutes ones
                        if (start_mm[3:0] != target_mm[3:0]) begin
                            needs_mm_ones_change <= 1'b1;
                            // Determine shortest path for ones (0-9 wrap)
                            if (start_mm[3:0] < target_mm[3:0]) begin
                                // Calculate direct vs wrap
                                if ((target_mm[3:0] - start_mm[3:0]) <= 4'd5)
                                    dir_mm_ones <= 1'b1; // increment
                                else
                                    dir_mm_ones <= 1'b0; // decrement (wrap)
                            end else begin
                                // start > target
                                if ((start_mm[3:0] - target_mm[3:0]) < 4'd5)
                                    dir_mm_ones <= 1'b0; // decrement
                                else
                                    dir_mm_ones <= 1'b1; // increment (wrap)
                            end
                        end else begin
                            needs_mm_ones_change <= 1'b0;
                        end
                        
                        // Minutes tens
                        if (start_mm[7:4] != target_mm[7:4]) begin
                            needs_mm_tens_change <= 1'b1;
                            if (start_mm[7:4] < target_mm[7:4])
                                dir_mm_tens <= 1'b1; // increment
                            else
                                dir_mm_tens <= 1'b0; // decrement
                        end else begin
                            needs_mm_tens_change <= 1'b0;
                        end
                        
                        // Calculate directions and needs for hours
                        // Hours ones
                        if (start_hh[3:0] != target_hh[3:0]) begin
                            needs_hh_ones_change <= 1'b1;
                            // Determine shortest path for ones (0-9 wrap)
                            if (start_hh[3:0] < target_hh[3:0]) begin
                                if ((target_hh[3:0] - start_hh[3:0]) <= 4'd5)
                                    dir_hh_ones <= 1'b1;
                                else
                                    dir_hh_ones <= 1'b0;
                            end else begin
                                if ((start_hh[3:0] - target_hh[3:0]) < 4'd5)
                                    dir_hh_ones <= 1'b0;
                                else
                                    dir_hh_ones <= 1'b1;
                            end
                        end else begin
                            needs_hh_ones_change <= 1'b0;
                        end
                        
                        // Hours tens
                        if (start_hh[7:4] != target_hh[7:4]) begin
                            needs_hh_tens_change <= 1'b1;
                            if (start_hh[7:4] < target_hh[7:4])
                                dir_hh_tens <= 1'b1;
                            else
                                dir_hh_tens <= 1'b0;
                        end else begin
                            needs_hh_tens_change <= 1'b0;
                        end
                        
                        state <= SETUP_MIN_ONES;
                    end
                end
                
                SETUP_MIN_ONES: begin
                    if (needs_mm_ones_change) begin
                        // Change ones digit
                        if (dir_mm_ones) begin
                            if (curr_mm_ones == 4'd9) begin
                                current_mm[3:0] <= 4'd0;
                                state <= SETUP_MIN_ONES; // Continue to 0
                            end else if (curr_mm_ones == target_mm_ones - 1) begin
                                current_mm[3:0] <= target_mm_ones;
                                count <= count + 1;
                                // Done with ones, check if need tens
                                if (needs_mm_tens_change)
                                    state <= SETUP_MIN_TENS;
                                else if (needs_hh_ones_change || needs_hh_tens_change)
                                    state <= SETUP_HR_ONES;
                                else
                                    state <= DONE;
                            end else begin
                                current_mm[3:0] <= curr_mm_ones + 1;
                                count <= count + 1;
                                state <= SETUP_MIN_ONES;
                            end
                        end else begin
                            if (curr_mm_ones == 4'd0) begin
                                current_mm[3:0] <= 4'd9;
                                state <= SETUP_MIN_ONES; // Continue to 9
                            end else if (curr_mm_ones == target_mm_ones + 1) begin
                                current_mm[3:0] <= target_mm_ones;
                                count <= count + 1;
                                if (needs_mm_tens_change)
                                    state <= SETUP_MIN_TENS;
                                else if (needs_hh_ones_change || needs_hh_tens_change)
                                    state <= SETUP_HR_ONES;
                                else
                                    state <= DONE;
                            end else begin
                                current_mm[3:0] <= curr_mm_ones - 1;
                                count <= count + 1;
                                state <= SETUP_MIN_ONES;
                            end
                        end
                    end else begin
                        // Skip to tens if needed, otherwise to hours
                        if (needs_mm_tens_change)
                            state <= SETUP_MIN_TENS;
                        else if (needs_hh_ones_change || needs_hh_tens_change)
                            state <= SETUP_HR_ONES;
                        else
                            state <= DONE;
                    end
                end
                
                SETUP_MIN_TENS: begin
                    if (needs_mm_tens_change) begin
                        // Change tens digit (linear, 0-5)
                        if (dir_mm_tens) begin
                            if (curr_mm_tens < target_mm_tens) begin
                                current_mm[7:4] <= curr_mm_tens + 1;
                                count <= count + 1;
                                state <= SETUP_MIN_TENS;
                            end else begin
                                // Done
                                state <= SETUP_MIN_ONES2;
                            end
                        end else begin
                            if (curr_mm_tens > target_mm_tens) begin
                                current_mm[7:4] <= curr_mm_tens - 1;
                                count <= count + 1;
                                state <= SETUP_MIN_TENS;
                            end else begin
                                state <= SETUP_MIN_ONES2;
                            end
                        end
                    end else begin
                        state <= SETUP_MIN_ONES2;
                    end
                end
                
                SETUP_MIN_ONES2: begin
                    // After tens change, adjust ones to target if needed
                    // But algorithm says: ones to 0, then tens, then ones to target
                    // So if we are here, tens are done, now check if ones need to go from 0 to target
                    // Wait - if we came here, we already did ones in SETUP_MIN_ONES (to 0 or target if no tens)
                    // Let's re-read: Change ones to 0, tens to target, ones to target
                    
                    // Actually, if needs_mm_ones_change was true, SETUP_MIN_ONES would have taken us to target
                    // unless we needed to go through 0 first.
                    // Logic correction: The states handle the flow.
                    // SETUP_MIN_ONES: if both need change, go to 0 (or 9)
                    // SETUP_MIN_TENS: handle tens
                    // SETUP_MIN_ONES2: handle ones final
                    
                    // Wait, looking at example 09:09 -> 09:00 -> ...
                    // 09:09 (start). If target is 20:10.
                    // Minutes: start 09, target 10. 
                    // Ones: 9->0 (path 9,8... or 9,0). Shortest is 9->0 (inc 1 step wrap).
                    // Tens: 0->1 (inc).
                    // Ones: 0->1 (inc).
                    // Sequence: 09:09 -> 09:00 (ones dec 9->0? No, 9->0 is inc 1 in BCD wrap) -> 09:10 (tens 0->1, ones 0->1? No)
                    // Let's trace algorithm strictly.
                    
                    // 1. Process Minutes.
                    //    If both digits change:
                    //       a. Ones -> 0 (shortest)
                    //       b. Tens -> Target Tens
                    //       c. Ones -> Target Ones
                    
                    // In SETUP_MIN_ONES, if we detect BOTH change, we must go to 0 first.
                    // In SETUP_MIN_ONES, if ONLY ones change, go to target.
                    
                    // Refined logic for SETUP_MIN_ONES:
                    // If (needs_mm_ones_change) {
                    //    If (needs_mm_tens_change) {
                    //       // Must go to 0 first
                    //       // Move towards 0
                    //       // When 0 reached -> SETUP_MIN_TENS
                    //    } else {
                    //       // Go to target
                    //       // When target reached -> NEXT (hours)
                    //    }
                    // } else {
                    //    // Just go to tens or hours
                    // }
                    
                    // Refined logic for SETUP_MIN_ONES2:
                    // This happens after tens are done.
                    // If needs_mm_ones_change AND needs_mm_tens_change, we are at 0. Go to target.
                    
                    if (needs_mm_ones_change && needs_mm_tens_change) begin
                        if (curr_mm_ones != target_mm_ones) begin
                            // Move towards target_mm_ones from 0
                            // We know direction from dir_mm_ones
                            if (dir_mm_ones) begin
                                if (curr_mm_ones < target_mm_ones) begin
                                    current_mm[3:0] <= curr_mm_ones + 1;
                                    count <= count + 1;
                                    state <= SETUP_MIN_ONES2;
                                end else begin
                                    // Done
                                    if (needs_hh_ones_change || needs_hh_tens_change)
                                        state <= SETUP_HR_ONES;
                                    else
                                        state <= DONE;
                                end
                            end else begin
                                if (curr_mm_ones > target_mm_ones) begin
                                    current_mm[3:0] <= curr_mm_ones - 1;
                                    count <= count + 1;
                                    state <= SETUP_MIN_ONES2;
                                end else begin
                                    if (needs_hh_ones_change || needs_hh_tens_change)
                                        state <= SETUP_HR_ONES;
                                    else
                                        state <= DONE;
                                end
                            end
                        end else begin
                            if (needs_hh_ones_change || needs_hh_tens_change)
                                state <= SETUP_HR_ONES;
                            else
                                state <= DONE;
                        end
                    end else begin
                        // Should not be here if no tens change, but for safety
                        if (needs_hh_ones_change || needs_hh_tens_change)
                            state <= SETUP_HR_ONES;
                        else
                            state <= DONE;
                    end
                end
                
                SETUP_HR_ONES: begin
                    // Process Hours
                    // Algorithm: Same logic as minutes
                    if (needs_hh_ones_change) begin
                        // Check if we need to go via 0
                        if (needs_hh_tens_change) begin
                            // Must go to 0 first
                            if (dir_hh_ones) begin
                                if (curr_hh_ones == 4'd9) begin
                                    current_hh[3:0] <= 4'd0;
                                    state <= SETUP_HR_ONES; // Stay here to finish to 0
                                end else if (curr_hh_ones == 4'd0) begin
                                    // Reached 0
                                    count <= count + 1; // Last step to 0 (if not already 0)
                                    state <= SETUP_HR_TENS;
                                end else begin
                                    current_hh[3:0] <= curr_hh_ones + 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES;
                                end
                            end else begin
                                if (curr_hh_ones == 4'd0) begin
                                    current_hh[3:0] <= 4'd9;
                                    state <= SETUP_HR_ONES;
                                end else if (curr_hh_ones == 4'd9) begin
                                    count <= count + 1; // Actually wait, 9->0 is 1 step inc. 9->9 is 0.
                                    // Let's redo the 0 logic.
                                    // We want to reach 0.
                                    // If current is 0, we are done with this phase (to 0).
                                    state <= SETUP_HR_TENS;
                                end else begin
                                    current_hh[3:0] <= curr_hh_ones - 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES;
                                end
                            end
                        end else begin
                            // Only ones change, go to target
                            if (dir_hh_ones) begin
                                if (curr_hh_ones < target_hh_ones) begin
                                    current_hh[3:0] <= curr_hh_ones + 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES;
                                end else begin
                                    state <= SETUP_HR_TENS; // Check for tens
                                end
                            end else begin
                                if (curr_hh_ones > target_hh_ones) begin
                                    current_hh[3:0] <= curr_hh_ones - 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES;
                                end else begin
                                    state <= SETUP_HR_TENS;
                                end
                            end
                        end
                    end else begin
                        state <= SETUP_HR_TENS;
                    end
                end
                
                SETUP_HR_TENS: begin
                    if (needs_hh_tens_change) begin
                        // Linear change
                        if (dir_hh_tens) begin
                            if (curr_hh_tens < target_hh_tens) begin
                                current_hh[7:4] <= curr_hh_tens + 1;
                                count <= count + 1;
                                state <= SETUP_HR_TENS;
                            end else begin
                                state <= SETUP_HR_ONES2;
                            end
                        end else begin
                            if (curr_hh_tens > target_hh_tens) begin
                                current_hh[7:4] <= curr_hh_tens - 1;
                                count <= count + 1;
                                state <= SETUP_HR_TENS;
                            end else begin
                                state <= SETUP_HR_ONES2;
                            end
                        end
                    end else begin
                        state <= SETUP_HR_ONES2;
                    end
                end
                
                SETUP_HR_ONES2: begin
                    // Final ones adjustment for hours
                    if (needs_hh_ones_change && needs_hh_tens_change) begin
                        if (curr_hh_ones != target_hh_ones) begin
                            if (dir_hh_ones) begin
                                if (curr_hh_ones < target_hh_ones) begin
                                    current_hh[3:0] <= curr_hh_ones + 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES2;
                                end else begin
                                    state <= DONE;
                                end
                            end else begin
                                if (curr_hh_ones > target_hh_ones) begin
                                    current_hh[3:0] <= curr_hh_ones - 1;
                                    count <= count + 1;
                                    state <= SETUP_HR_ONES2;
                                end else begin
                                    state <= DONE;
                                end
                            end
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Wait for start to go low or reset
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

    // Logic fix for SETUP_MIN_ONES to handle 0 reaching correctly
    // The code above in SETUP_MIN_ONES handles the "both change" case.
    // If both change, it tries to go to 0.
    // But "current = 0" check is tricky because we start at start_mm.
    // Let's simplify SETUP_MIN_ONES logic for the "both change" scenario:
    // We need to increment/decrement until we hit 0.
    // If current is already 0, we are done.
    // If current is 9 and we need to decrement, 9->8...->0.
    // If current is 9 and we need to increment (wrap), 9->0.
    
    // Let's rewrite the state logic block to be cleaner regarding the "to 0" and "from 0" phases.
    // I will add a flag to indicate if we are in the "reset to zero" phase or "to target" phase.
    // Actually, the state names SETUP_MIN_ONES and SETUP_MIN_ONES2 imply this separation.
    // In SETUP_MIN_ONES (first time):
    //   If BOTH changes: Move to 0.
    //   If ONLY ones: Move to target.
    // In SETUP_MIN_TENS: Move tens.
    // In SETUP_MIN_ONES2: Move ones to target (only if BOTH changes happened).
    
    // Refining SETUP_MIN_ONES logic for the "Both Change" case:
    // We must ensure it loops until curr_mm_ones is 0.
    // If curr_mm_ones is 0, we advance to SETUP_MIN_TENS.
    
    // Refining SETUP_HR_ONES logic for the "Both Change" case:
    // We must ensure it loops until curr_hh_ones is 0.
    
    // The code in SETUP_MIN_ONES block above has a flaw in the "Both Change" check.
    // It checks `if (curr_mm_ones == target_mm_ones - 1)` which assumes we are going to target.
    // If we are going to 0, we should check `curr_mm_ones == 0`.
    
    // Let's patch the specific logic inside SETUP_MIN_ONES and SETUP_HR_ONES.
    // 
    // Since I am generating code, I will ensure the logic is robust.
    // The provided logic in SETUP_MIN_ONES:
    //      if (dir_mm_ones) ...
    //      if (curr_mm_ones == 4'd9) ... (loop)
    //      else if (curr_mm_ones == target_mm_ones - 1) ... (stop condition for target)
    // This fails if we need to stop at 0.
    
    // CORRECTIVE ACTION: The provided solution in the thought trace should be checked.
    // I will provide a version where the logic handles the "go to 0" vs "go to target" explicitly.
    
    // The code block below replaces the main always block logic with a cleaner version.
    // 
    // 
    // RE-CODE BLOCK START (Embedded in the JSON)
    // 
    // Since I cannot edit the previous output, I will rely on the fact that the prompt asked for the code.
    // I will regenerate the `always` block logic to be 100% correct based on the description.
    // 
    // Actually, looking at the state machine flow:
    // SETUP_MIN_ONES -> (loop) -> SETUP_MIN_TENS (if both) OR DONE (if only ones)
    // SETUP_MIN_TENS -> SETUP_MIN_ONES2 (if both) OR NEXT
    // SETUP_MIN_ONES2 -> NEXT
    // 
    // I will output the code with the corrected logic in the `always` block.
    // The previous code had a flaw in handling the "To 0" termination in SETUP_MIN_ONES.
    
    // Let's write the final correct module code.
    // 
    // I will replace the always block in the final output with this:
    // (Checking constraints: no newlines in output string).

endmodule

module clock_setter(
    input clk,
    input rst_n,
    input start,
    input [7:0] start_hh,
    input [7:0] start_mm,
    input [7:0] target_hh,
    input [7:0] target_mm,
    output reg [7:0] current_hh,
    output reg [7:0] current_mm,
    output reg done,
    output reg [3:0] count
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam SETUP_MIN_ONES = 4'd1;
    localparam SETUP_MIN_TENS = 4'd2;
    localparam SETUP_MIN_ONES2 = 4'd3;
    localparam SETUP_HR_ONES = 4'd4;
    localparam SETUP_HR_TENS = 4'd5;
    localparam SETUP_HR_ONES2 = 4'd6;
    localparam DONE = 4'd7;

    reg [3:0] state, next_state;
    reg [7:0] start_hh_reg, start_mm_reg, target_hh_reg, target_mm_reg;
    reg dir_mm_ones, dir_mm_tens, dir_hh_ones, dir_hh_tens;
    reg needs_mm_ones, needs_mm_tens, needs_hh_ones, needs_hh_tens;
    
    // Helper wires
    wire [3:0] curr_mm_t = current_mm[7:4];
    wire [3:0] curr_mm_o = current_mm[3:0];
    wire [3:0] curr_hh_t = current_hh[7:4];
    wire [3:0] curr_hh_o = current_hh[3:0];
    
    wire [3:0] tgt_mm_t = target_mm_reg[7:4];
    wire [3:0] tgt_mm_o = target_mm_reg[3:0];
    wire [3:0] tgt_hh_t = target_hh_reg[7:4];
    wire [3:0] tgt_hh_o = target_hh_reg[3:0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_hh <= 8'h00;
            current_mm <= 8'h00;
            done <= 1'b0;
            count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    if (start) begin
                        start_hh_reg <= start_hh;
                        start_mm_reg <= start_mm;
                        target_hh_reg <= target_hh;
                        target_mm_reg <= target_mm;
                        current_hh <= start_hh;
                        current_mm <= start_mm;
                        
                        // Calculate Needs and Directions
                        // Minutes Ones
                        if (start_mm[3:0] != tgt_mm_o) begin
                            needs_mm_ones <= 1'b1;
                            // Shortest path logic
                            if (start_mm[3:0] < tgt_mm_o) begin
                                if ((tgt_mm_o - start_mm[3:0]) <= 4'd5) dir_mm_ones <= 1'b1;
                                else dir_mm_ones <= 1'b0;
                            end else begin
                                if ((start_mm[3:0] - tgt_mm_o) < 4'd5) dir_mm_ones <= 1'b0;
                                else dir_mm_ones <= 1'b1;
                            end
                        end else needs_mm_ones <= 1'b0;
                        
                        // Minutes Tens
                        if (start_mm[7:4] != tgt_mm_t) begin
                            needs_mm_tens <= 1'b1;
                            dir_mm_tens <= (start_mm[7:4] < tgt_mm_t) ? 1'b1 : 1'b0;
                        end else needs_mm_tens <= 1'b0;
                        
                        // Hours Ones
                        if (start_hh[3:0] != tgt_hh_o) begin
                            needs_hh_ones <= 1'b1;
                            if (start_hh[3:0] < tgt_hh_o) begin
                                if ((tgt_hh_o - start_hh[3:0]) <= 4'd5) dir_hh_ones <= 1'b1;
                                else dir_hh_ones <= 1'b0;
                            end else begin
                                if ((start_hh[3:0] - tgt_hh_o) < 4'd5) dir_hh_ones <= 1'b0;
                                else dir_hh_ones <= 1'b1;
                            end
                        end else needs_hh_ones <= 1'b0;
                        
                        // Hours Tens
                        if (start_hh[7:4] != tgt_hh_t) begin
                            needs_hh_tens <= 1'b1;
                            dir_hh_tens <= (start_hh[7:4] < tgt_hh_t) ? 1'b1 : 1'b0;
                        end else needs_hh_tens <= 1'b0;
                        
                        state <= SETUP_MIN_ONES;
                    end
                end
                
                SETUP_MIN_ONES: begin
                    if (needs_mm_ones) begin
                        if (needs_mm_tens) begin
                            // Path: Go to 0
                            if (curr_mm_o != 4'd0) begin
                                if (dir_mm_ones) begin
                                    // Increment to 0 (wrap)
                                    if (curr_mm_o == 4'd9) current_mm[3:0] <= 4'd0;
                                    else current_mm[3:0] <= curr_mm_o + 1;
                                end else begin
                                    // Decrement to 0
                                    if (curr_mm_o == 4'd0) current_mm[3:0] <= 4'd9; // Should not happen due to condition
                                    else current_mm[3:0] <= curr_mm_o - 1;
                                end
                                count <= count + 1;
                                state <= SETUP_MIN_ONES;
                            end else begin
                                state <= SETUP_MIN_TENS;
                            end
                        end else begin
                            // Path: Go to Target
                            if (curr_mm_o != tgt_mm_o) begin
                                if (dir_mm_ones) current_mm[3:0] <= curr_mm_o + 1;
                                else current_mm[3:0] <= curr_mm_o - 1;
                                count <= count + 1;
                                state <= SETUP_MIN_ONES;
                            end else begin
                                // Done with mins
                                if (needs_hh_ones || needs_hh_tens) state <= SETUP_HR_ONES;
                                else state <= DONE;
                            end
                        end
                    end else begin
                        // No ones change
                        if (needs_mm_tens) state <= SETUP_MIN_TENS;
                        else if (needs_hh_ones || needs_hh_tens) state <= SETUP_HR_ONES;
                        else state <= DONE;
                    end
                end
                
                SETUP_MIN_TENS: begin
                    if (curr_mm_t != tgt_mm_t) begin
                        if (dir_mm_tens) current_mm[7:4] <= curr_mm_t + 1;
                        else current_mm[7:4] <= curr_mm_t - 1;
                        count <= count + 1;
                        state <= SETUP_MIN_TENS;
                    end else begin
                        state <= SETUP_MIN_ONES2;
                    end
                end
                
                SETUP_MIN_ONES2: begin
                    // Only reached if both needs were true
                    if (curr_mm_o != tgt_mm_o) begin
                        if (dir_mm_ones) current_mm[3:0] <= curr_mm_o + 1;
                        else current_mm[3:0] <= curr_mm_o - 1;
                        count <= count + 1;
                        state <= SETUP_MIN_ONES2;
                    end else begin
                        if (needs_hh_ones || needs_hh_tens) state <= SETUP_HR_ONES;
                        else state <= DONE;
                    end
                end
                
                SETUP_HR_ONES: begin
                    if (needs_hh_ones) begin
                        if (needs_hh_tens) begin
                            // Path: Go to 0
                            if (curr_hh_o != 4'd0) begin
                                if (dir_hh_ones) begin
                                    if (curr_hh_o == 4'd9) current_hh[3:0] <= 4'd0;
                                    else current_hh[3:0] <= curr_hh_o + 1;
                                end else begin
                                    current_hh[3:0] <= curr_hh_o - 1;
                                end
                                count <= count + 1;
                                state <= SETUP_HR_ONES;
                            end else begin
                                state <= SETUP_HR_TENS;
                            end
                        end else begin
                            // Path: Go to Target
                            if (curr_hh_o != tgt_hh_o) begin
                                if (dir_hh_ones) current_hh[3:0] <= curr_hh_o + 1;
                                else current_hh[3:0] <= curr_hh_o - 1;
                                count <= count + 1;
                                state <= SETUP_HR_ONES;
                            end else begin
                                state <= SETUP_HR_TENS; // Check tens anyway
                            end
                        end
                    end else begin
                        state <= SETUP_HR_TENS;
                    end
                end
                
                SETUP_HR_TENS: begin
                    if (curr_hh_t != tgt_hh_t) begin
                        if (dir_hh_tens) current_hh[7:4] <= curr_hh_t + 1;
                        else current_hh[7:4] <= curr_hh_t - 1;
                        count <= count + 1;
                        state <= SETUP_HR_TENS;
                    end else begin
                        state <= SETUP_HR_ONES2;
                    end
                end
                
                SETUP_HR_ONES2: begin
                    if (needs_hh_ones && needs_hh_tens) begin
                        if (curr_hh_o != tgt_hh_o) begin
                            if (dir_hh_ones) current_hh[3:0] <= curr_hh_o + 1;
                            else current_hh[3:0] <= curr_hh_o - 1;
                            count <= count + 1;
                            state <= SETUP_HR_ONES2;
                        end else begin
                            state <= DONE;
                        end
                    end else begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                        done <= 1'b0;
                    end
                end
            endcase
        end
    end
endmodule