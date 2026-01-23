module mad_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] grid_data,
    input wire grid_valid,
    output reg [31:0] result,
    output reg done,
    output reg [5:0] state_out
);

    // Parameters
    parameter GRID_SIZE = 4;
    parameter MAX_AREA = 8;
    parameter MAX_DENSITIES = 64; // Safe upper bound for 4x4 grid
    parameter Q16_SHIFT = 16;
    
    // State definitions
    localparam IDLE = 6'd0;
    localparam LOAD = 6'd1;
    localparam CALC_DENSITIES = 6'd2;
    localparam SORT = 6'd3;
    localparam MEDIAN = 6'd4;
    localparam DONE = 6'd5;
    
    // Registers and Wires
    reg [5:0] current_state, next_state;
    reg [15:0] grid [0:15]; // Flattened 4x4 grid
    reg [3:0] load_cnt;     // Counter for loading 16 values
    
    // Density Calculation Variables
    reg [2:0] r1, c1, r2, c2; // Rectangle coordinates
    reg [31:0] rect_sum;      // Sum of values in current rectangle
    reg [3:0] rect_area;      // Area of current rectangle (max 16)
    reg [5:0] density_cnt;    // Count of valid densities stored
    
    // Density Storage
    reg [31:0] densities [0:MAX_DENSITIES-1]; // Stores fixed-point densities
    reg [31:0] temp_density;                  // Calculated density temp storage
    
    // Sorting Variables
    reg [5:0] sort_i, sort_j;
    reg [31:0] sort_val1, sort_val2;
    reg sort_swap;
    
    // Median Variables
    reg [5:0] med_idx1, med_idx2;
    reg [31:0] med_val1, med_val2;
    reg [63:0] med_sum; // 64-bit to handle addition overflow
    
    // Integer loop variables
    integer i, j;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            current_state <= IDLE;
        else
            current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        case (current_state)
            IDLE: begin
                if (start)
                    next_state = LOAD;
                else
                    next_state = IDLE;
            end
            LOAD: begin
                if (load_cnt == 16 && grid_valid) // Wait for 16th valid pulse
                    next_state = CALC_DENSITIES;
                else
                    next_state = LOAD;
            end
            CALC_DENSITIES: begin
                // Iterate through all rectangles. 
                // r1: 0-3, c1: 0-3, r2: r1-3, c2: c1-3
                // Complex logic: we proceed when inner loops finish
                // Handled inside the sequential block logic
                if (r1 == 3 && c1 == 3 && r2 == 3 && c2 == 3) begin
                    // Check if last one was valid? No, we update state after finishing all loops
                    // To simplify, we stay here until loops complete, then switch in sequential block
                    next_state = SORT; 
                end else begin
                    next_state = CALC_DENSITIES;
                end
            end
            SORT: begin
                // Bubble sort runs for a fixed duration or until swap flag logic is done
                // We will implement a counter-based sort loop control
                if (sort_i >= density_cnt) // Simple check, actual logic handled inside
                    next_state = MEDIAN;
                else
                    next_state = SORT;
            end
            MEDIAN: begin
                next_state = DONE;
            end
            DONE: begin
                if (start) // Stay done until start goes low (optional, or wait for reset)
                    next_state = DONE;
                else
                    next_state = IDLE; 
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset logic
            result <= 0;
            done <= 0;
            state_out <= IDLE;
            load_cnt <= 0;
            density_cnt <= 0;
            r1 <= 0; c1 <= 0; r2 <= 0; c2 <= 0;
            rect_sum <= 0;
            rect_area <= 0;
            sort_i <= 0; sort_j <= 0;
            // Clear grid (optional but good practice)
            for (i = 0; i < 16; i = i + 1) grid[i] <= 0;
            for (i = 0; i < MAX_DENSITIES; i = i + 1) densities[i] <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    load_cnt <= 0;
                    density_cnt <= 0;
                    r1 <= 0; c1 <= 0; r2 <= 0; c2 <= 0;
                    rect_sum <= 0;
                    sort_i <= 0; sort_j <= 0;
                end

                LOAD: begin
                    if (grid_valid && load_cnt < 16) begin
                        grid[load_cnt] <= grid_data;
                        load_cnt <= load_cnt + 1;
                    end
                end

                CALC_DENSITIES: begin
                    // We need a multi-cycle process per rectangle
                    // 1. Calculate area
                    // 2. Check area
                    // 3. Calculate sum (requires iteration over rectangle bounds)
                    // 4. Calculate density
                    // 5. Store if valid
                    // 6. Increment coordinates
                    
                    // To implement efficiently in hardware without nested loops in FSM:
                    // We use a helper counter 'rect_state' or reuse the main state but with sequential increments.
                    // Given the strict requirements, let's add internal states or use the existing state with sequential logic.
                    
                    // To keep the module simple without adding more top-level states, we use a small sub-FSM logic or sequential steps.
                    // Let's define an internal step counter (using existing registers to save space).
                    // We can repurpose 'sort_j' as a step counter for CALC_DENSITIES state temporarily.
                    // sort_j logic: 0=calc area, 1=calc sum, 2=save density, 3=increment coords.
                    
                    // Let's use 'rect_area' upper bits or a new register. 
                    // To be clean, let's add a 'step' logic variable or just increment r1/c1 logic carefully.
                    // Re-reading instructions: "return Verilog code". I should avoid changing interface.
                    // I will add localparam steps logic inside the always block.
                    
                    // Let's use 'density_cnt' as a state machine for the calculation loop.
                    // Actually, let's use 'sort_i' to track the calculation step.
                    // step 0: load coords to calculate area
                    // step 1: calculate sum
                    // step 2: store density
                    // step 3: update coords
                    
                    // We need to reset sort_i when entering state? No, let's use a dedicated step register.
                    // Let's add 'calc_step' using bits of unused registers or define it locally in logic.
                    // Actually, to keep strictly to the requirements and avoid adding too many regs, I will use 'sort_j' for step control.
                    // BUT, sort_j is needed for sorting. So I must reset it before SORT state.
                    // Let's add a temporary register or bit. Let's use 'sort_swap' for step control (it's a flag).
                    
                    if (!sort_swap) begin // sort_swap = 0 means we are setting up the rectangle
                        // Calculate Area
                        rect_area <= (r2 - r1 + 1) * (c2 - c1 + 1);
                        sort_swap <= 1; // Next cycle we calc sum
                        rect_sum <= 0;  // Reset sum
                    end else if (sort_swap && rect_sum == 0) begin // Step 2: Calculate Sum
                        // We need to iterate over the rectangle to sum up values.
                        // Since we can't do a loop in one cycle, we need to wait or iterate.
                        // To iterate, we need indices (ir, ic). Let's use 'sort_i' and 'sort_j' for row/col indices of the sum loop.
                        // Actually, 'sort_swap' is being used. Let's use 'sort_swap' to denote we are in the summation phase.
                        // And 'sort_j' (re-purposed) as row index, 'sort_i' as col index?
                        
                        // Let's use a cleaner approach: Unroll the sum calculation over multiple cycles using 'sort_i' as the step counter.
                        // Because standard 4x4 is small, we can calculate sum in one cycle using a parallel reduction tree (adder tree).
                        // This is much faster and valid Verilog.
                        
                        // Summation Logic (Single Cycle Combinational logic pushed into register update)
                        // Wait, we need to update registers. Let's calculate sum combinationally and latch it.
                        // But we need to sum specific values. 
                        // Let's define a combinational block for sum.
                        
                        // For the sake of this sequential implementation, let's use a pure combinational sum logic triggered by coordinates.
                        // But to stick to the "sequential verilog module" request, let's do it step-by-step if possible, or just do it in one go if latency is acceptable.
                        // Given 1000 cycles is allowed, doing sum in 1 cycle is fine.
                        
                        // Combinational sum calculation:
                        // We are inside a sequential block. We can't easily define a variable that sums without assigned delay.
                        // However, we can assign rect_sum based on the grid values at the current r1..c2.
                        // This creates a massive combinational path but is correct for single-cycle logic.
                        
                        // Calculate Sum Combinationally:
                        rect_sum <= 0;
                        if (rect_area <= 8) begin
                            for (i = 0; i < 4; i = i + 1) begin
                                for (j = 0; j < 4; j = j + 1) begin
                                    if (i >= r1 && i <= r2 && j >= c1 && j <= c2)
                                        rect_sum <= rect_sum + grid[i*4 + j];
                                end
                            end
                        end
                        
                        sort_swap <= 2; // State to check and store
                    end else if (sort_swap == 2) begin // Step 3: Store and Update
                        if (rect_area >= 1 && rect_area <= 8) begin
                            // Calculate Density = (Sum / Area) * 65536
                            // Integer division: (Sum * 65536) / Area
                            if (rect_area > 0) begin
                                densities[density_cnt] <= (rect_sum * 65536) / rect_area;
                                density_cnt <= density_cnt + 1;
                            end
                        end
                        
                        // Update Coordinates (r2, c2, then c1, r1)
                        if (c2 < 3) begin
                            c2 <= c2 + 1;
                        end else begin
                            c2 <= c1; // Reset column end to start column
                            if (r2 < 3) begin
                                r2 <= r2 + 1;
                            end else begin
                                // End of (r2, c2) loop
                                r2 <= r1;
                                if (c1 < 3) begin
                                    c1 <= c1 + 1;
                                end else begin
                                    c1 <= 0;
                                    if (r1 < 3) begin
                                        r1 <= r1 + 1;
                                    end else begin
                                        // r1 = 3, c1 = 3 done. 
                                        // Logic for state transition handled in Next State logic
                                        // We need to ensure we don't keep looping. 
                                        // The next_state logic checks r1==3 && c1==3 && r2==3 && c2==3.
                                        // We just set a flag or rely on the next clock cycle.
                                    end
                                end
                            end
                        end
                        
                        sort_swap <= 0; // Back to step 0 for next rectangle
                    end
                end

                SORT: begin
                    // Bubble Sort Implementation
                    // We need to iterate.
                    // Let's use 'sort_i' for the outer loop (0 to density_cnt-1)
                    // 'sort_j' for inner loop (0 to density_cnt - i - 1)
                    // 'sort_swap' as a flag to check if we finished a pass or need reset.
                    
                    // Initialization for sort
                    if (sort_swap == 0) begin
                        sort_i <= 0;
                        sort_j <= 0;
                        sort_swap <= 1; // Start sorting
                    end else if (sort_swap == 1) begin
                        if (sort_i < density_cnt - 1) begin
                            if (sort_j < density_cnt - 1 - sort_i) begin
                                // Compare and Swap
                                sort_val1 <= densities[sort_j];
                                sort_val2 <= densities[sort_j + 1];
                                if (densities[sort_j] > densities[sort_j + 1]) begin
                                    // Swap needed. Because this is a sequential block, we must handle the swap carefully.
                                    // The comparison is on the old values (from the block inputs), but we need to write back.
                                    // However, reading and writing the same array in the same cycle is not allowed (write takes precedence on next cycle).
                                    // So we need a registered comparison result or handle swap next cycle.
                                    // Let's use a 'swap_needed' flag.
                                    sort_swap <= 2; // Swap state
                                end else begin
                                    sort_j <= sort_j + 1;
                                end
                            end else begin
                                // End of inner loop
                                sort_j <= 0;
                                sort_i <= sort_i + 1;
                            end
                        end else begin
                            // Sort complete
                            sort_swap <= 3; // Done state for SORT state
                        end
                    end else if (sort_swap == 2) begin // Swap State
                        // Perform swap: densities[sort_j] <= sort_val2 (which was densities[j+1])
                        // densities[sort_j+1] <= sort_val1 (which was densities[j])
                        // Wait, we stored 'sort_val1' as the smaller (or larger) one? 
                        // We compared densities[j] > densities[j+1]. So swap is needed.
                        // sort_val1 = densities[j], sort_val2 = densities[j+1].
                        densities[sort_j] <= sort_val2;
                        densities[sort_j + 1] <= sort_val1;
                        sort_j <= sort_j + 1;
                        sort_swap <= 1; // Back to compare
                    end else if (sort_swap == 3) begin // Finished Sort
                        // Transition to MEDIAN state handled by next_state logic
                        // We need to set sort_i >= density_cnt to trigger next state transition in Next Logic? 
                        // Actually, next_state checks `if (sort_i >= density_cnt)`. 
                        // Let's set sort_i to density_cnt to satisfy that condition.
                        sort_i <= density_cnt;
                    end
                end

                MEDIAN: begin
                    // Calculate Median
                    // density_cnt is the number of valid densities
                    if (density_cnt == 0) begin
                        result <= 0;
                    end else if (density_cnt[0] == 1) begin // Odd count
                        med_idx1 <= density_cnt >> 1;
                        result <= densities[density_cnt >> 1];
                    end else begin // Even count
                        med_idx1 <= (density_cnt >> 1) - 1;
                        med_idx2 <= (density_cnt >> 1);
                        med_sum <= densities[(density_cnt >> 1) - 1] + densities[(density_cnt >> 1)];
                        // Result is average. 
                        // med_sum is 64-bit to prevent overflow (Max density ~10000*65536 ~ 655M. Sum ~ 1.3B. Fits in 32-bit? No, fits in 32-bit actually. 10000*65536 = 655,360,000 < 2^32.
                        // But let's be safe with 64-bit intermediate or 33-bit.
                        // Division by 2.
                        result <= (densities[(density_cnt >> 1) - 1] + densities[(density_cnt >> 1)]) >> 1;
                    end
                    // Transition to DONE handled by next_state
                end

                DONE: begin
                    done <= 1;
                    state_out <= current_state;
                    // Reset start condition handling
                    if (!start) begin
                        // Keep done high until start goes high again? 
                        // Or reset on next start? Usually done stays high until reset or new start.
                        // Let's clear done when entering IDLE (which happens when start goes low).
                        // Actually, we stay in DONE state while start is high.
                    end
                end
            endcase
        end
    end

    // Output State Debug
    always @(posedge clk) begin
        if (!rst_n) state_out <= 0;
        else state_out <= current_state;
    end

endmodule