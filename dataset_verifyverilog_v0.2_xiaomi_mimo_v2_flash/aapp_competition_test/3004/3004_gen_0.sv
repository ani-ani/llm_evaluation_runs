module fence_painter(
    input clk,
    input rst_n,
    input start,
    input [1:0] offer_color,
    input [4:0] offer_start,
    input [4:0] offer_end,
    input [1:0] offer_index,
    input offer_valid,
    output reg [2:0] result,
    output reg done,
    output reg possible
);

    // State Encoding
    localparam S_IDLE = 3'b000;
    localparam S_LOAD = 3'b001;
    localparam S_SORT = 3'b010;
    localparam S_PROCESS = 3'b011;
    localparam S_DONE = 3'b100;
    localparam S_FAIL = 3'b101;

    // Internal Registers
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Offers storage: 4 entries, 11 bits (2 color + 5 start + 5 end)
    reg [10:0] offers [0:3];
    reg [10:0] sorted [0:3];
    
    // Sorting registers
    reg [1:0] sort_pass;
    reg [1:0] sort_idx;
    reg [10:0] temp_offer;
    reg sort_swap;
    reg sort_init;
    
    // Greedy Algorithm Registers
    reg [4:0] curr_pos;
    reg [3:0] used_colors;
    reg [2:0] offer_count;
    reg [1:0] scan_idx;
    reg [4:0] best_end;
    reg [1:0] best_idx;
    reg [3:0] process_limit;
    
    // Load Counter
    reg [1:0] load_cnt;

    // State Transition Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= S_IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            S_IDLE: begin
                if (start) next_state = S_LOAD;
                else next_state = S_IDLE;
            end
            
            S_LOAD: begin
                // Wait for 4 valid offers
                if (load_cnt == 2'b11 && offer_valid)
                    next_state = S_SORT;
                else
                    next_state = S_LOAD;
            end
            
            S_SORT: begin
                // Bubble sort logic: 
                // 4 elements, 3 passes. Each pass scans the array.
                // We use a multi-cycle approach within this state.
                // If sort_pass reaches 3, we are done.
                if (sort_pass == 2'b11) // 3 passes completed
                    next_state = S_PROCESS;
                else
                    next_state = S_SORT;
            end
            
            S_PROCESS: begin
                // Greedy loop
                // Check termination conditions
                if (curr_pos > 16) begin
                    next_state = S_DONE;
                end else if (process_limit > 4'd12) begin
                    // Safety timeout: Max 4 offers * 3 colors + buffer
                    next_state = S_FAIL;
                end else if (scan_idx == 2'b10 && best_end < curr_pos) begin
                    // Scanned all 4 offers (index 0,1,2,3) -> scan_idx wraps to 0 after 3, so check scan_idx == 0 logic
                    // Actually, scan_idx increments 0,1,2,3. When it returns to 0, we evaluate.
                    // Let's use a flag or specific state for evaluation.
                    next_state = S_PROCESS;
                end else begin
                    next_state = S_PROCESS;
                end
                // Refined logic for transitions handled inside Process State logic
            end
            
            S_DONE, S_FAIL: begin
                if (start) next_state = S_IDLE;
                else next_state = S_DONE;
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            possible <= 0;
            load_cnt <= 0;
            sort_pass <= 0;
            sort_idx <= 0;
            offer_count <= 0;
            curr_pos <= 5'd1;
            used_colors <= 0;
            best_end <= 0;
            process_limit <= 0;
            scan_idx <= 0;
        end else begin
            case (current_state)
                S_IDLE: begin
                    if (start) begin
                        load_cnt <= 0;
                        result <= 0;
                        done <= 0;
                        possible <= 0;
                        offer_count <= 0;
                        curr_pos <= 5'd1;
                        used_colors <= 0;
                        sort_pass <= 0;
                        sort_idx <= 0;
                        process_limit <= 0;
                        scan_idx <= 0;
                    end
                end

                S_LOAD: begin
                    if (offer_valid) begin
                        offers[offer_index] <= {offer_color, offer_start, offer_end};
                        if (load_cnt < 3)
                            load_cnt <= load_cnt + 1;
                    end
                end

                S_SORT: begin
                    // Bubble Sort Implementation
                    // Step 1: Copy raw to sorted on first entry into state (if needed)
                    // Since we are sequential, we handle initialization via flags or check sort_pass == 0 && sort_idx == 0
                    // However, it's safer to just copy in previous state or use a separate init cycle.
                    // Let's rely on 'sort_init' flag.
                    
                    if (sort_pass == 0 && sort_idx == 0 && !sort_init) begin
                        sorted[0] <= offers[0];
                        sorted[1] <= offers[1];
                        sorted[2] <= offers[2];
                        sorted[3] <= offers[3];
                        sort_init <= 1;
                    end else begin
                        // Perform swap logic
                        // Inner loop index 'sort_idx' goes from 0 to 2 - sort_pass
                        if (sort_idx < 3 - sort_pass) begin
                            // Compare start positions (bits [9:5])
                            if (sorted[sort_idx][9:5] > sorted[sort_idx+1][9:5]) begin
                                temp_offer <= sorted[sort_idx];
                                sorted[sort_idx] <= sorted[sort_idx+1];
                                sorted[sort_idx+1] <= temp_offer;
                            end
                            sort_idx <= sort_idx + 1;
                        end else begin
                            // End of inner loop
                            sort_idx <= 0;
                            sort_pass <= sort_pass + 1;
                        end
                    end
                end

                S_PROCESS: begin
                    process_limit <= process_limit + 1;
                    
                    // State machine within S_PROCESS
                    // Mode A: Scan offers (scan_idx 0 to 3)
                    // Mode B: Apply best offer
                    
                    if (scan_idx < 4) begin
                        // Scanning Phase
                        // Logic: Check if offer covers curr_pos, and color fits budget
                        
                        // Optimization: Register the checks to avoid combinational loops
                        reg covers;
                        reg color_ok;
                        reg [3:0] col_bit;
                        
                        col_bit = 1'b1 << sorted[scan_idx][10:9];
                        covers = (sorted[scan_idx][9:5] <= curr_pos) && (sorted[scan_idx][4:0] >= curr_pos);
                        
                        // Check Color Budget
                        if (used_colors == 0) color_ok = 1;
                        else begin
                            // If color is already used, ok. If new, check count.
                            if (used_colors & col_bit) color_ok = 1;
                            else begin
                                // Count bits
                                if ((used_colors[0]+used_colors[1]+used_colors[2]+used_colors[3]) < 3)
                                    color_ok = 1;
                                else
                                    color_ok = 0;
                            end
                        end
                        
                        // On first scan (scan_idx 0), reset best_end
                        if (scan_idx == 0) best_end <= 0;
                        
                        if (covers && color_ok) begin
                            if (sorted[scan_idx][4:0] > best_end) begin
                                best_end <= sorted[scan_idx][4:0];
                                best_idx <= scan_idx;
                            end
                        end
                        
                        scan_idx <= scan_idx + 1;
                    end else begin
                        // Apply Phase (scan_idx == 4)
                        scan_idx <= 0; // Reset for next iteration
                        
                        if (best_end >= curr_pos) begin
                            // Valid offer found
                            curr_pos <= best_end + 1;
                            offer_count <= offer_count + 1;
                            used_colors <= used_colors | (1 << sorted[best_idx][10:9]);
                        end else begin
                            // No offer found, Fail
                            // We can force transition or just let it sit. 
                            // The next_state logic will catch (curr_pos <= 16) and (best_end < curr_pos)
                            // We need to ensure 'best_end' is preserved for the next_state check.
                            // If we reset it here, it might fail. 
                            // So we do NOT reset best_end here, we keep it for the check.
                            // However, to move to S_FAIL, the next_state logic needs to see the failure condition.
                            // Current next_state logic: 
                            // if (curr_pos > 16) -> DONE
                            // else if (process_limit > 12) -> FAIL
                            // else if (scan_idx == 2'b10 && best_end < curr_pos) -> FAIL (This condition is iffy)
                            // 
                            // Let's fix next_state logic in S_PROCESS.
                            // Since we are in the else branch (scan_idx==4), we have just finished scanning.
                            // The best_end value is valid.
                            // If best_end < curr_pos, we failed.
                            // We can't change state from inside the always block directly based on next_state logic.
                            // We rely on next_state logic to transition out.
                            // We need to ensure next_state logic checks this condition.
                        end
                    end
                end

                S_DONE: begin
                    done <= 1;
                    possible <= 1;
                    result <= offer_count;
                end

                S_FAIL: begin
                    done <= 1;
                    possible <= 0;
                    result <= offer_count;
                end
            endcase
        end
    end

    // Combinational update for S_PROCESS transition conditions
    // We need to fix the next_state logic for S_PROCESS to correctly detect end of scan and failure.
    // Since the verilog module is block-oriented, I will correct the next_state block logic by 
    // modifying the logic within the provided structure.
    
    // Re-defining next_state logic for S_PROCESS to be robust:
    // - If curr_pos > 16: DONE
    // - If we just finished scanning (scan_idx == 4 in current cycle logic):
    //   - If best_end < curr_pos: FAIL
    //   - Else: Continue (stay in S_PROCESS, which resets scan_idx to 0 in the datapath)
    // - If scanning (scan_idx < 4): Stay
    
    // Note: In Verilog, always blocks are evaluated concurrently. 
    // The 'next_state' logic I wrote earlier is combinational and sees the *current* values of registers.
    // Let's refine the S_PROCESS case in next_state logic:
    
    /* 
       We need to know if we are in 'scan' phase or 'apply' phase. 
       But we don't have a flag for that in registers.
       We can infer it from scan_idx.
       Logic: 
       If (curr_pos > 16) -> DONE
       Else If (scan_idx < 4) -> Stay in S_PROCESS (Scanning)
       Else (scan_idx == 4) -> 
            If (best_end < curr_pos) -> FAIL
            Else -> Stay in S_PROCESS (This will trigger the Datapath to reset scan_idx to 0 and update position)
    */

endmodule

module fence_painter_v2(
    input clk,
    input rst_n,
    input start,
    input [1:0] offer_color,
    input [4:0] offer_start,
    input [4:0] offer_end,
    input [1:0] offer_index,
    input offer_valid,
    output reg [2:0] result,
    output reg done,
    output reg possible
);

    // State Encoding
    localparam S_IDLE = 3'b000;
    localparam S_LOAD = 3'b001;
    localparam S_SORT = 3'b010;
    localparam S_PROCESS_FIND = 3'b011; // Scans offers
    localparam S_PROCESS_APPLY = 3'b100; // Updates state
    localparam S_DONE = 3'b101;
    localparam S_FAIL = 3'b110;

    // Internal Registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Offers storage: 4x11 bits (Color(2), Start(5), End(5))
    reg [10:0] offers [0:3];
    reg [10:0] sorted [0:3];
    
    // Sorting registers
    reg [1:0] sort_i;
    reg [1:0] sort_j;
    reg [10:0] temp_reg;
    reg sorting_done_flag;
    
    // Process registers
    reg [4:0] curr_pos;
    reg [3:0] used_colors;
    reg [2:0] offer_cnt;
    reg [1:0] scan_idx;
    reg [4:0] best_end;
    reg [2:0] best_idx_reg; // Register to store index of best offer
    reg [2:0] cycles; // Generic counter for delays
    
    // Load counter
    reg [1:0] load_cnt;

    // Combinational Next State Logic
    always @(*) begin
        case (state)
            S_IDLE: next_state = start ? S_LOAD : S_IDLE;
            
            S_LOAD: begin
                // Wait for 4 valid offers
                if (load_cnt == 2'b11 && offer_valid)
                    next_state = S_SORT;
                else
                    next_state = S_LOAD;
            end
            
            S_SORT: begin
                // Bubble sort: 4 elements requires ~6 comparisons total if optimized,
                // but we do 1 comparison per cycle to keep it simple and sequential.
                // Algorithm: iterate i=0 to 3, j=0 to 3-i-1.
                // If sorting_done_flag is set, move to process.
                if (sorting_done_flag)
                    next_state = S_PROCESS_FIND;
                else
                    next_state = S_SORT;
            end

            S_PROCESS_FIND: begin
                // Scan all 4 offers (takes 4 cycles)
                if (scan_idx == 2'b11) // After scanning 4th offer
                    next_state = S_PROCESS_APPLY;
                else
                    next_state = S_PROCESS_FIND;
            end

            S_PROCESS_APPLY: begin
                // Apply results of scan
                if (curr_pos > 16) begin
                    next_state = S_DONE;
                end else if (best_end < curr_pos) begin
                    // No offer covered current position
                    next_state = S_FAIL;
                end else begin
                    // Next iteration
                    next_state = S_PROCESS_FIND;
                end
            end
            
            S_DONE, S_FAIL: begin
                // Stay here until reset or start
                if (start) next_state = S_IDLE;
                else next_state = S_DONE; // Stay in DONE (or FAIL acts like DONE)
            end
            
            default: next_state = S_IDLE;
        endcase
    end

    // Sequential Logic (Datapath)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            load_cnt <= 0;
            result <= 0;
            done <= 0;
            possible <= 0;
            sorting_done_flag <= 0;
            sort_i <= 0;
            sort_j <= 0;
            curr_pos <= 5'd1;
            offer_cnt <= 0;
            used_colors <= 0;
            scan_idx <= 0;
            best_end <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    if (start) begin
                        load_cnt <= 0;
                        result <= 0;
                        done <= 0;
                        possible <= 0;
                        curr_pos <= 5'd1;
                        offer_cnt <= 0;
                        used_colors <= 0;
                        sorting_done_flag <= 0;
                        sort_i <= 0;
                        sort_j <= 0;
                    end
                end

                S_LOAD: begin
                    if (offer_valid) begin
                        offers[offer_index] <= {offer_color, offer_start, offer_end};
                        if (load_cnt < 3)
                            load_cnt <= load_cnt + 1;
                    end
                end

                S_SORT: begin
                    // Bubble sort step
                    if (!sorting_done_flag) begin
                        // Initialize sorted array from offers on first entry or check state transition
                        // To ensure fresh copy, we can do this on the transition from LOAD to SORT
                        // but since it's sequential, let's do it implicitly or handle first cycle.
                        // Simple approach: assume 'offers' is static in this state.
                        // We need to copy 'offers' to 'sorted' first.
                        
                        if (sort_i == 0 && sort_j == 0) begin
                            sorted[0] <= offers[0];
                            sorted[1] <= offers[1];
                            sorted[2] <= offers[2];
                            sorted[3] <= offers[3];
                        end

                        if (sort_i < 3) begin // Outer loop 0..2
                            if (sort_j < 3 - sort_i) begin // Inner loop 0..(2-sort_i)
                                // Compare start positions (bits [9:5])
                                if (sorted[sort_j][9:5] > sorted[sort_j+1][9:5]) begin
                                    temp_reg <= sorted[sort_j];
                                    sorted[sort_j] <= sorted[sort_j+1];
                                    sorted[sort_j+1] <= temp_reg;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 0;
                                sort_i <= sort_i + 1;
                            end
                        end else begin
                            sorting_done_flag <= 1;
                        end
                    end
                end

                S_PROCESS_FIND: begin
                    // Reset best_end at start of scan (cycle 0)
                    if (scan_idx == 0) begin
                        best_end <= 0;
                        best_idx_reg <= 0;
                    end

                    // Check current offer
                    // Index is scan_idx
                    // Logic: 
                    // 1. Cover check: start <= curr_pos && end >= curr_pos
                    // 2. Color check: 
                    //    - Count used colors. If < 3, any color is fine.
                    //    - If == 3, must be one of used colors.
                    //    - If > 3, should not happen if logic is correct, but we constrain.
                    
                    if (sorted[scan_idx][9:5] <= curr_pos && sorted[scan_idx][4:0] >= curr_pos) begin
                        // It covers. Check color allowance.
                        reg [3:0] col_bit;
                        reg allowed;
                        col_bit = 1'b1 << sorted[scan_idx][10:9];
                        
                        // Check used colors count
                        if (used_colors == 0) allowed = 1;
                        else if (used_colors[3] && !used_colors[2] && !used_colors[1] && !used_colors[0]) allowed = 0;
                        else if (used_colors[3] && used_colors[2]) allowed = 0;
                        else if (used_colors[3] && used_colors[1]) allowed = 0;
                        else if (used_colors[3] && used_colors[0]) allowed = 0;
                        else if (used_colors[2] && used_colors[1] && used_colors[0]) allowed = 0;
                        else allowed = 1;

                        // Or simpler: Check if adding this color exceeds 3
                        reg [3:0] temp_used;
                        temp_used = used_colors | col_bit;
                        if (temp_used[0] + temp_used[1] + temp_used[2] + temp_used[3] <= 3) allowed = 1;
                        else allowed = 0;

                        if (allowed) begin
                            if (sorted[scan_idx][4:0] > best_end) begin
                                best_end <= sorted[scan_idx][4:0];
                                best_idx_reg <= {1'b0, scan_idx}; // Store index 0-3
                            end
                        end
                    end
                    
                    scan_idx <= scan_idx + 1;
                end

                S_PROCESS_APPLY: begin
                    // Reset scan index for next time
                    scan_idx <= 0;
                    
                    // Update if valid offer found
                    if (best_end >= curr_pos) begin
                        curr_pos <= best_end + 1;
                        offer_cnt <= offer_cnt + 1;
                        // Update colors
                        // best_idx_reg holds the index of best offer in sorted array
                        // We need to access sorted[best_idx_reg] but since best_idx_reg is logic output, 
                        // we need to be careful. 
                        // However, we stored best_end and best_idx_reg in previous cycle.
                        // The value of sorted[best_idx_reg] is valid.
                        used_colors <= used_colors | (1 << sorted[best_idx_reg][10:9]);
                    end
                end

                S_DONE: begin
                    done <= 1;
                    possible <= 1;
                    result <= offer_cnt;
                end

                S_FAIL: begin
                    done <= 1;
                    possible <= 0;
                    result <= offer_cnt;
                end
            endcase
        end
    end

endmodule