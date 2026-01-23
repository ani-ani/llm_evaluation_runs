module lane_switch_safety(
    input clk,
    input rst_n,
    input start,
    input [3:0] total_cars_input,
    input [1:0] car_lane [0:15],
    input [7:0] car_length [0:15],
    input [17:0] car_distance [0:15],
    output reg [31:0] safety_factor_result,
    output reg result_valid,
    output reg impossible,
    output reg done
);

// Parameters
parameter NUM_LANES = 4;
parameter MAX_CARS_PER_LANE = 8;
parameter SENSOR_RANGE = 256;

// Fixed point constants (Q16.16)
localparam [31:0] FP_SENSOR_RANGE = 256 * 65536;
localparam [31:0] ACM_POS = 10 * 65536; // 0x000A0000
localparam [31:0] ACM_LEN = 10 * 65536;
localparam [31:0] FP_ONE = 65536;

// State definitions
localparam [2:0] IDLE = 3'b000;
localparam [2:0] READ_INPUT = 3'b001;
localparam [2:0] FIND_GAPS = 3'b010;
localparam [2:0] CHECK_SWITCH = 3'b011;
localparam [2:0] CALC_SAFETY = 3'b100;
localparam [2:0] DONE_STATE = 3'b101;

// Registers for state machine
reg [2:0] state;
reg [2:0] next_state;

// Registers for car data organization
reg [3:0] car_count_reg;
reg [1:0] organized_lane [0:15];
reg [7:0] organized_length [0:15];
reg [17:0] organized_distance [0:15];

// Lane sorting registers
reg [3:0] sort_idx;
reg [3:0] sort_jdx;
reg [2:0] cars_per_lane [0:3]; // count per lane
reg [3:0] lane_indices [0:3] [0:7]; // indices into organized arrays

// Gap computation registers
reg [2:0] gap_lane;
reg [3:0] gap_car_idx;
reg [31:0] gaps [0:3] [0:7]; // gaps per lane (max cars + 1)
reg [31:0] gap_sizes [0:3] [0:7];
reg [2:0] gap_count [0:3];

// Switch checking registers
reg [1:0] check_lane;
reg [31:0] min_safety;
reg [31:0] cur_safety;
reg path_found;

// Temp registers for calculations
reg [31:0] temp_gap_size;
reg [31:0] temp_safety;
reg signed [32:0] calc_temp; // signed for subtraction

// Helper variables
integer i, j, k;
reg [31:0] car_front;
reg [31:0] car_back;
reg [31:0] gap_before;
reg [31:0] gap_after;
reg [31:0] min_gap;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        safety_factor_result <= 0;
        result_valid <= 0;
        impossible <= 0;
        done <= 0;
        car_count_reg <= 0;
        sort_idx <= 0;
        sort_jdx <= 0;
        gap_lane <= 0;
        gap_car_idx <= 0;
        check_lane <= 0;
        min_safety <= 32'hFFFFFFFF; // Max value
        cur_safety <= 0;
        path_found <= 0;
        temp_gap_size <= 0;
        temp_safety <= 0;
        calc_temp <= 0;
        // Clear arrays
        for (i = 0; i < 16; i = i + 1) begin
            organized_lane[i] <= 0;
            organized_length[i] <= 0;
            organized_distance[i] <= 0;
        end
        for (i = 0; i < 4; i = i + 1) begin
            cars_per_lane[i] <= 0;
            gap_count[i] <= 0;
            for (j = 0; j < 8; j = j + 1) begin
                lane_indices[i][j] <= 0;
                gaps[i][j] <= 0;
                gap_sizes[i][j] <= 0;
            end
        end
    end else begin
        state <= next_state;
        
        case (state)
            IDLE: begin
                result_valid <= 0;
                impossible <= 0;
                done <= 0;
                if (start) begin
                    car_count_reg <= total_cars_input;
                    sort_idx <= 0;
                    sort_jdx <= 0;
                    check_lane <= 0;
                    gap_lane <= 0;
                    gap_car_idx <= 0;
                    min_safety <= 32'hFFFFFFFF;
                    path_found <= 0;
                    // Copy input data to internal regs
                    for (i = 0; i < 16; i = i + 1) begin
                        if (i < total_cars_input) begin
                            organized_lane[i] <= car_lane[i];
                            organized_length[i] <= car_length[i];
                            organized_distance[i] <= car_distance[i];
                        end else begin
                            organized_lane[i] <= 0;
                            organized_length[i] <= 0;
                            organized_distance[i] <= 0;
                        end
                    end
                    // Clear lane counts
                    for (i = 0; i < 4; i = i + 1) begin
                        cars_per_lane[i] <= 0;
                        gap_count[i] <= 0;
                    end
                end
            end
            
            READ_INPUT: begin
                // Simple load into lanes
                // We need to clear `cars_per_lane` first? No, done in IDLE.
                // We need to iterate `sort_idx` (0 to total_cars-1)
                // And distribute.
                
                if (sort_idx < car_count_reg) begin
                    // Distribute car sort_idx to its lane
                    if (car_lane[sort_idx] == 0) begin
                        if (cars_per_lane[0] < 8) begin
                            lane_indices[0][cars_per_lane[0]] <= sort_idx;
                            cars_per_lane[0] <= cars_per_lane[0] + 1;
                        end
                    end else if (car_lane[sort_idx] == 1) begin
                        if (cars_per_lane[1] < 8) begin
                            lane_indices[1][cars_per_lane[1]] <= sort_idx;
                            cars_per_lane[1] <= cars_per_lane[1] + 1;
                        end
                    end else if (car_lane[sort_idx] == 2) begin
                        if (cars_per_lane[2] < 8) begin
                            lane_indices[2][cars_per_lane[2]] <= sort_idx;
                            cars_per_lane[2] <= cars_per_lane[2] + 1;
                        end
                    end else begin
                        if (cars_per_lane[3] < 8) begin
                            lane_indices[3][cars_per_lane[3]] <= sort_idx;
                            cars_per_lane[3] <= cars_per_lane[3] + 1;
                        end
                    end
                    sort_idx <= sort_idx + 1;
                end else begin
                    // Finished loading, reset for sorting
                    sort_idx <= 0;
                    sort_jdx <= 0;
                    // We need a sub-state or flag to handle sorting here or move to next state.
                    // Let's use the next state `FIND_GAPS` to do sorting AND gap calc.
                    // Or better, add a `SORT_CARS` state.
                    // But prompt said: IDLE, READ_INPUT, FIND_GAPS, CHECK_SWITCH, CALC_SAFETY, DONE.
                    // I will assume `READ_INPUT` just loads. 
                    // `FIND_GAPS` will sort and calc.
                end
            end
            
            FIND_GAPS: begin
                // Need to sort cars in each lane, then calc gaps.
                // Bubble sort requires multiple cycles per lane.
                // We can use sort_idx for lane, sort_jdx for pass, gap_lane for item.
                // 
                // Strategy: 
                // 1. Sort Lane 0.
                // 2. Sort Lane 1.
                // 3. Sort Lane 2.
                // 4. Sort Lane 3.
                // 5. Calc Gaps.
                // 
                // Let's use `gap_lane` to select lane.
                // Let's use `gap_car_idx` to iterate.
                // Let's use a `temp` variable for swap.
                // 
                // This is getting complex for a single state. 
                // However, we can do sorting in a loop inside the state machine if we are careful with counters.
                // 
                // Let's do a Bubble Sort Pass logic:
                // We need to perform (N*(N-1)/2) comparisons/swaps.
                // For 8 items, max 28 swaps. 
                // 
                // Let's re-use `sort_idx` as the "swap count" or just iterate pairwise.
                // 
                // Let's try a simpler approach for `FIND_GAPS`:
                // We assume the cars are loaded.
                // We iterate `gap_lane` 0 to 3.
                // Inside, we need to sort `lane_indices[gap_lane]`.
                // 
                // We can do a simple selection sort or bubble sort over a few cycles.
                // Since we have plenty of cycles (1000), let's do it bit by bit.
                // 
                // Let's use `gap_car_idx` to represent the "pass" in bubble sort.
                // Bubble sort needs `N-1` passes.
                // In each pass, we compare adjacent items and swap if needed.
                // 
                // Let's define internal registers for sorting:
                `reg [3:0] sort_pass; // Current pass
                `reg [3:0] sort_pos;  // Position in lane
                
                // Okay, the `reg` inside always block isn't allowed in standard Verilog unless declared as temp vars.
                // Let's use existing registers or new ones defined at top.
                // I'll use `sort_jdx` for pass, `gap_car_idx` for position.
                
                // Bubble Sort Logic for `gap_lane`:
                // We need to sort `organized_distance[lane_indices[gap_lane][x]]`.
                // 
                // Current plan for FIND_GAPS:
                // 1. Sort current `gap_lane` using `sort_jdx` (pass) and `gap_car_idx` (pos).
                //    If `gap_car_idx` < `cars_per_lane[gap_lane] - sort_jdx`:
                //      Compare idx1 = lane_indices[gap_lane][gap_car_idx], idx2 = lane_indices[gap_lane][gap_car_idx+1]
                //      If dist[idx1] > dist[idx2], swap indices.
                //      Increment `gap_car_idx`.
                //    If done pass, increment `sort_jdx`, reset `gap_car_idx`.
                //    If all passes done, move to GAP CALC.
                // 2. GAP CALC:
                //    Iterate `gap_car_idx` from 0 to `cars_per_lane[gap_lane]` (inclusive for end gap).
                //    Compute gap size.
                //    Store in `gap_sizes`.
                //    
                // This takes too many lines. Let's condense.
                
                // Implementation of Bubble Sort in FIND_GAPS:
                // 
                // If we are sorting (before calc): 
                //   if (gap_car_idx < cars_per_lane[gap_lane] - sort_jdx) begin
                //     compare and swap
                //     gap_car_idx++
                //   end else begin
                //     sort_jdx++
                //     gap_car_idx = 0
                //     if (sort_jdx == cars_per_lane[gap_lane]) done sorting.
                //   end
                // 
                // If sorted (or no cars): Calc gaps.
                
                // Let's implement this logic.
                // We need a flag or check to know if sorting is done.
                // Let's use `sort_jdx` for pass. If `sort_jdx` >= `cars_per_lane[gap_lane]`, then sorted.
                
                // If `cars_per_lane[gap_lane] == 0`, skip sort, calc gap (just range).
                
                // Let's refine the logic in the code block below.
                
                if (gap_lane < NUM_LANES) begin
                    // Check if this lane has cars
                    if (cars_per_lane[gap_lane] > 0) begin
                        // Check if sorting is complete (pass count >= n-1)
                        if (sort_jdx < cars_per_lane[gap_lane] - 1) begin
 // Sort is sorting active?
                            // Perform one comparison/swap
                            if (gap_car_idx < cars_per_lane[gap_lane] - 1 - sort_jdx) begin
                                // Compare
                                // We need to access organized_distance using lane_indices
                                // lane_indices[gap_lane][gap_car_idx] gives index into organized arrays
                                if (organized_distance[lane_indices[gap_lane][gap_car_idx]] > organized_distance[lane_indices[gap_lane][gap_car_idx + 1]]) begin
                                    // Swap
                                    // We can't swap lane_indices directly in one step without temp
                                    // Use a temp register or manual swap
                                    // Since we are in clocked logic, we can do:
                                    // temp <= idxA; idxA <= idxB; idxB <= temp;
                                    // But we need a temp var. Let's use `sort_idx` as temp storage for this cycle if we are careful.
                                    // Actually, let's swap directly:
                                    // This is tricky in HW without temp. 
                                    // Let's assume we can do it in 2 steps or use a helper.
                                    // Or, just let the swap be:
                                    // We are updating `lane_indices`. 
                                    // Let's use `cur_safety` as a temp register for swapping indices? No, that's bad.
                                    // Let's rely on `calc_temp` or another unused register.
                                    // Or just declare a temp register at top: `reg [3:0] swap_temp;`
                                    // But instructions say "Assume all inputs are of type reg unless otherwise specified".
                                    // "Do not assume a clock signal unless explicitly given".
                                    // I will add a `swap_temp` if needed. 
                                    // Actually, I can use a single cycle swap if I am careful with order of assignments.
                                    // `lane_indices[gap_lane][gap_car_idx] <= lane_indices[gap_lane][gap_car_idx+1];`
                                    // `lane_indices[gap_lane][gap_car_idx+1] <= lane_indices[gap_lane][gap_car_idx];`
                                    // This sets both to the same value if not done carefully.
                                    // So I need a temp.
                                    // Let's repurpose `temp_safety` or similar if it's not used yet.
                                    // `temp_safety` is 32-bit. `lane_indices` is 4-bit.
                                    // I'll use `temp_safety[3:0]` to hold swap value.
                                    
                                    // Swap Logic:
                                    temp_safety[3:0] <= lane_indices[gap_lane][gap_car_idx];
                                    lane_indices[gap_lane][gap_car_idx] <= lane_indices[gap_lane][gap_car_idx + 1];
                                    lane_indices[gap_lane][gap_car_idx + 1] <= temp_safety[3:0];
                                end
                                gap_car_idx <= gap_car_idx + 1;
                            end else begin
                                // End of pass
                                gap_car_idx <= 0;
                                sort_jdx <= sort_jdx + 1;
                            end
                        end else begin
                            // Sorting done for this lane. Calculate Gaps.
                            // Use `gap_car_idx` to iterate through gaps.
                            // Gap 0 (before first car): Start at 0 to first car back.
                            // Gap i (between cars): Back of i-1 to Front of i.
                            // Gap N (after last): Back of last to 256.
                            
                            // We need a way to know we are done calculating gaps.
                            // Let's say we use `gap_car_idx` from 0 to `cars_per_lane[gap_lane]`.
                            // `cars_per_lane` is count. So gaps = count + 1.
                            
                            if (gap_car_idx <= cars_per_lane[gap_lane]) begin
                                // Compute gap `gap_car_idx`
                                // We need to access the sorted indices.
                                // Index in sorted list: gap_car_idx - 1 (prev), gap_car_idx (next)
                                
                                // This is pure combinational logic for gap calculation, or state-based.
                                // Let's do it step by step.
                                
                                // Calculate Gap Size
                                if (gap_car_idx == 0) begin
                                    // Gap before first car
                                    // Size = dist[0] - 0
                                    gap_sizes[gap_lane][0] <= organized_distance[lane_indices[gap_lane][0]];
                                end else if (gap_car_idx < cars_per_lane[gap_lane]) begin
                                    // Gap between cars
                                    // Size = dist[i] - (dist[i-1] + len[i-1])
                                    // Here gap_car_idx is the gap index.
                                    // Car i-1 is at sorted index i-1.
                                    // Car i is at sorted index i.
                                    // We need to convert Q16.16 length to standard format (left shift 16 is * 65536).
                                    // car_length is 8 bits. So {car_length, 16'b0} is Q16.16 value.
                                    gap_sizes[gap_lane][gap_car_idx] <= 
                                        organized_distance[lane_indices[gap_lane][gap_car_idx]] -
                                        (organized_distance[lane_indices[gap_lane][gap_car_idx - 1]] + 
                                         {organized_length[lane_indices[gap_lane][gap_car_idx - 1]], 16'b0});
                                end else begin
                                    // Gap after last car (gap_car_idx == cars_per_lane[gap_lane])
                                    // Size = 256 - (dist[last] + len[last])
                                    gap_sizes[gap_lane][cars_per_lane[gap_lane]] <= 
                                        FP_SENSOR_RANGE -
                                        (organized_distance[lane_indices[gap_lane][cars_per_lane[gap_lane] - 1]] + 
                                         {organized_length[lane_indices[gap_lane][cars_per_lane[gap_lane] - 1]], 16'b0});
                                end
                                
                                gap_car_idx <= gap_car_idx + 1;
                            end else begin
                                // Done with this lane
                                gap_car_idx <= 0;
                                sort_jdx <= 0; // Reset sort pass
                                gap_lane <= gap_lane + 1;
                            end
                        end
                    end else begin
                        // No cars in this lane. Gap is entire range.
                        gap_sizes[gap_lane][0] <= FP_SENSOR_RANGE;
                        gap_count[gap_lane] <= 1;
                        gap_lane <= gap_lane + 1;
                        gap_car_idx <= 0;
                        sort_jdx <= 0;
                    end
                end
                // If gap_lane >= 4, we are done with all lanes.
                // But how do we transition? 
                // We need to check `gap_lane` at the start of the block.
                // If `gap_lane` becomes 4, we need to move to next state.
                // The `if (gap_lane < NUM_LANES)` protects us.
                // When `gap_lane` hits 4, this block is skipped.
                // We need an else clause here or handle it after.
                // But we are in `else if (state == FIND_GAPS)`.
                // If `gap_lane` >= 4, we don't enter the inner block.
                // We should transition state.
            end
            
            CHECK_SWITCH: begin
                // Check lanes 1, 2, 3 (destination lanes)
                // `check_lane` is used. We should ensure it starts at 1.
                // In IDLE/START, we reset `check_lane` to 1? No, let's set it in IDLE or transition.
                // In IDLE we set it to 0. Let's set it to 1 when entering CHECK_SWITCH.
                // Wait, we need to handle transition. 
                // Let's assume `check_lane` is initialized to 1 at the end of FIND_GAPS (if we split states) or at start of CHECK_SWITCH.
                // Let's reset `check_lane` to 1 in `IDLE` if start? No, we need it preserved.
                // Let's reset it when entering `CHECK_SWITCH`.
                // But `next_state` logic handles the transition.
                // So in `CHECK_SWITCH` block:
                // if we just entered, `check_lane` might be 0.
                // We need a sub-state or flag.
                // Or we can just rely on `check_lane` being 0 from previous state and increment it.
                // Let's assume `check_lane` is 0 coming out of `FIND_GAPS`.
                // Wait, `FIND_GAPS` ends with `gap_lane` = 4. `check_lane` is untouched.
                // In IDLE, we reset `check_lane` to 0.
                // So `check_lane` is 0.
                // 
                // Logic:
                // If `check_lane` < 3:
                //   `check_lane` is index 0, 1, 2 (corresponding to lanes 1, 2, 3).
                //   We need to access gap_sizes for lane 1, 2, 3.
                //   TargetLane = check_lane + 1.
                //   
                //   Find max gap in `gap_sizes[TargetLane]`.
                //   Since gap sizes are stored, we can iterate.
                //   We need a loop. Let's use `gap_car_idx` to iterate gaps.
                //   `max_gap` temp variable.
                //   
                //   If `gap_car_idx` < `gap_count[TargetLane]`:
                //     If `gap_sizes[TargetLane][gap_car_idx] > max_gap` (and valid), update max_gap.
                //     gap_car_idx++.
                //   Else:
                //     // Done checking gaps for this lane.
                //     // Calculate Safety.
                //     // Safety = (max_gap - 10) / 2.
                //     // But wait, `max_gap` needs to be stored or processed.
                //     // Let's compute safety in this cycle.
                //     // `max_gap` is in a temp register.
                //     // 
                //     // Check if `max_gap` >= ACM_LEN.
                //     // If not, impossible.
                //     // 
                //     // Safety = (max_gap - ACM_LEN) >> 1.
                //     // Update `min_safety`.
                //     // 
                //     // Next lane: `check_lane`++. `gap_car_idx`=0.
                //     // 
                //     // If `check_lane` == 3 (done with lane 3), move to `CALC_SAFETY`.
                
                //    Wait, `max_gap` is not a register in my plan. 
                //    Let's add `reg [31:0] temp_max_gap`.
                //    And `reg [31:0] temp_calc`.
                
                //    Let's adjust the module header to include helper variables if needed, or use existing ones.
                //    I'll use `cur_safety` to store max_gap temporarily.
                //    And `temp_safety` to store result.
                
                //    Refined CHECK_SWITCH logic:
                //    TargetLane = check_lane + 1.
                //    
                //    If `gap_car_idx` < gap_count[TargetLane]:
                //      // Iteration
                //      if gap_sizes[TargetLane][gap_car_idx] > cur_safety (and > 0): cur_safety <= gap_sizes...
                //      gap_car_idx++.
                //    Else:
                //      // Processed all gaps.
                //      // cur_safety holds max gap.
                //      if cur_safety < ACM_LEN: impossible <= 1; next_state <= DONE.
                //      else:
                //        // Safety = (cur_safety - ACM_LEN) / 2.
                //        temp_safety <= (cur_safety - ACM_LEN) >> 1;
                //        // Update global min
                //        if (temp_safety < min_safety) min_safety <= temp_safety;
                //        // Next lane
                //        check_lane++;
                //        gap_car_idx <= 0;
                //        cur_safety <= 0;
                //        if (check_lane == 2): next_state <= CALC_SAFETY; // Done 1, 2, 3 (indices 0, 1, 2)
                //    
                //    This looks correct.
                //    We need to handle the "impossible" case carefully.
                //    If any lane is impossible, the whole path is impossible.
                
                //    Wait, `check_lane` is 0 coming out of `FIND_GAPS`.
                //    Let's reset `check_lane` to 1 in `CHECK_SWITCH`.
                //    
                if (check_lane == 0) begin
                    check_lane <= 1;
                end else begin
                    // TargetLane = check_lane + 1.
                    // If `gap_car_idx` < gap_count[TargetLane]:
                    //   // Iteration
                    //   if gap_sizes[TargetLane][gap_car_idx] > cur_safety (and > 0): cur_safety <= gap_sizes...
                    //   gap_car_idx++.
                    // Else:
                    //   // Processed all gaps.
                    //   // cur_safety holds max gap.
                    //   if cur_safety < ACM_LEN: impossible <= 1; next_state <= DONE.
                    //   else:
                    //     // Safety = (cur_safety - ACM_LEN) / 2.
                    //     temp_safety <= (cur_safety - ACM_LEN) >> 1;
                    //     // Update global min
                    //     if (temp_safety < min_safety) min_safety <= temp_safety;
                    //     // Next lane
                    //     check_lane++;
                    //     gap_car_idx <= 0;
                    //     cur_safety <= 0;
                    //     if (check_lane == 2): next_state <= CALC_SAFETY; // Done 1, 2, 3 (indices 0, 1, 2)
                    
                    if (gap_car_idx < gap_count[check_lane + 1]) begin
                        if (gap_sizes[check_lane + 1][gap_car_idx] > cur_safety && gap_sizes[check_lane + 1][gap_car_idx] > 0) begin
                            cur_safety <= gap_sizes[check_lane + 1][gap_car_idx];
                        end
                        gap_car_idx <= gap_car_idx + 1;
                    end else begin
                        // Processed all gaps.
                        if (cur_safety < ACM_LEN) begin
                            impossible <= 1;
                            next_state <= DONE_STATE;
                        end else begin
                            // Safety = (cur_safety - ACM_LEN) / 2.
                            temp_safety <= (cur_safety - ACM_LEN) >> 1;
                            // Update global min
                            if (temp_safety < min_safety) min_safety <= temp_safety;
                            // Next lane
                            check_lane <= check_lane + 1;
                            gap_car_idx <= 0;
                            cur_safety <= 0;
                            if (check_lane == 2) next_state <= CALC_SAFETY; // Done 1, 2, 3 (indices 0, 1, 2)
                        end
                    end
                end
            end
            
            CALC_SAFETY: begin
                // Calculate safety for Lane 0.
                // Car at pos 10.
                // We need to find cars before and after.
                // Iterate cars in Lane 0.
                // 
                // `gap_car_idx` can be used to iterate.
                // We need to find:
                //   last car with dist < 10.
                //   first car with dist > 10.
                // 
                // We have `gap_sizes` or `organized_distance`.
                // We need to access `organized_distance` for lane 0 cars.
                // `lane_indices[0][i]` gives index.
                // `organized_distance[...]` gives dist.
                // 
                // Logic:
                // If `gap_car_idx` < cars_per_lane[0]:
                //   idx = lane_indices[0][gap_car_idx]
                //   dist = organized_distance[idx]
                //   front = dist + len[idx] (need len too? No, for gap_after calculation we need next car front).
                //   Actually, we just need to identify the closest car before 10 and closest after 10.
                //   
                //   Let's use `sort_idx` for the closest before, `sort_jdx` for closest after.
                //   Or just scan.
                //   
                //   Let's use `gap_car_idx` to scan.
                //   We need temp variables:
                //   `prev_car_dist` (max dist < 10)
                //   `next_car_dist` (min dist > 10)
                //   `prev_car_len` (length of car at prev_car_dist)
                //   
                //   If organized_distance < 10:
                //     if organized_distance > prev_car_dist: update prev.
                //   Else (>= 10):
                //     if organized_distance < next_car_dist: update next.
                //   
                //   After loop:
                //   gap_before = 10 - (prev_car_dist + prev_car_len)
                //   gap_after = (next_car_dist) - (10 + 10)
                //   
                //   What if no car before? Gap_before = 10 (from 0 to 10?). 
                //   Wait, if no car before, gap_before is from 0 to 10.
                //   If no car after, gap_after is from 20 to 256.
                
                //   Formula: `Safety = min(gap_before, gap_after) - 5`.
                
                //   
                //   Implementation in hardware:
                //   This is complex to do in one state.
                //   We can use `CHECK_SWITCH` state for this too? 
                //   No, instructions say `CALC_SAFETY`.
                //   
                //   Let's assume we can do this in `CALC_SAFETY`.
                //   We iterate `gap_car_idx` from 0 to `cars_per_lane[0]`.
                //   We maintain `temp_safety` (which will hold min gap), `cur_safety` (which will hold max gap).
                //   Actually, `temp_safety` used before. Let's use `temp_max_gap`.
                //   
                //   Wait, `min_safety` holds the global min from lanes 1,2,3.
                //   We need to calculate safety for lane 0, compare with `min_safety`, and store.
                //   
                //   Let's use:
                //   `calc_temp` to store gap_before.
                //   `temp_gap_size` to store gap_after.
                //   
                //   
                //   Step 1: Scan for cars.
                //   Step 2: Compute gaps.
                //   Step 3: Compute safety.
                //   Step 4: Update `min_safety`.
                //   
                //   We need several sub-cycles.
                //   Let's use `check_lane` as a sub-state counter for `CALC_SAFETY`.
                //   
                //   `check_lane` usage in `CALC_SAFETY`:
                //   0: Init scan vars. Reset gap_car_idx.
                //   1: Scan loop. gap_car_idx < count? yes -> update. no -> go to 2.
                //   2: Compute values.
                //   3: Update min and finish.
                
                //   Let's implement this logic.
                //   We need to initialize `prev_car_dist`, `next_car_dist`, `prev_car_len`.
                //   We need to scan `gap_car_idx` from 0 to `cars_per_lane[0]`.
                //   We need to update `prev_car_dist`, `next_car_dist`, `prev_car_len` based on conditions.
                //   After scanning, we compute `gap_before`, `gap_after`, and `safety`.
                //   Finally, we update `min_safety` if necessary.
                
                //   Let's define the logic in steps.
                
                //   Step 0: Initialize
                if (check_lane == 0) begin
                    // Initialize scan variables
                    prev_car_dist <= 0;
                    next_car_dist <= 32'hFFFFFFFF;
                    prev_car_len <= 0;
                    gap_car_idx <= 0;
                    check_lane <= 1;
                end
                // Step 1: Scan loop
                else if (check_lane == 1) begin
                    if (gap_car_idx < cars_per_lane[0]) begin
                        idx = lane_indices[0][gap_car_idx];
                        dist = organized_distance[idx];
                        if (dist < 10) begin
                            if (dist > prev_car_dist) begin
                                prev_car_dist <= dist;
                                prev_car_len <= organized_length[idx];
                            end
                        end else begin
                            if (dist < next_car_dist) begin
                                next_car_dist <= dist;
                            end
                        end
                        gap_car_idx <= gap_car_idx + 1;
                    end else begin
                        // Done scanning
                        check_lane <= 2;
                    end
                end
                // Step 2: Compute gaps
                else if (check_lane == 2) begin
                    // Compute gap_before and gap_after
                    if (prev_car_dist == 0) begin
                        gap_before <= 10;
                    end else begin
                        gap_before <= 10 - (prev_car_dist + prev_car_len);
                    end
                    if (next_car_dist == 32'hFFFFFFFF) begin
                        gap_after <= FP_SENSOR_RANGE - 20;
                    end else begin
                        gap_after <= next_car_dist - 20;
                    end
                    check_lane <= 3;
                end
                // Step 3: Compute safety and update min_safety
                else if (check_lane == 3) begin
                    // Compute safety
                    if (gap_before < gap_after) begin
                        temp_safety <= gap_before - 5;
                    end else begin
                        temp_safety <= gap_after - 5;
                    end
                    // Update min_safety
                    if (temp_safety < min_safety) min_safety <= temp_safety;
                    check_lane <= 0;
                    next_state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                result_valid <= 1;
                done <= 1;
                safety_factor_result <= min_safety;
                // If impossible was set, keep it high.
                // If not impossible, but min_safety is still max value? Then it's impossible too.
                if (min_safety == 32'hFFFFFFFF && !impossible) begin
                    impossible <= 1;
                    safety_factor_result <= 0;
                end
            end
        endcase
    end
end

// Next State Logic
always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = READ_INPUT;
        end
        
        READ_INPUT: begin
            if (sort_idx >= car_count_reg) begin
                // Data loaded. Now need to sort in FIND_GAPS.
                // Or we can move to FIND_GAPS and reset counters there.
                next_state = FIND_GAPS;
            end else begin
                next_state = READ_INPUT;
            end
        end
        
        FIND_GAPS: begin
            // Logic to transition out is tricky inside the block.
            // Let's check status here.
            // If gap_lane >= 4, we are done.
            // But gap_lane is updated inside the block.
            // We need to know if we are done.
            // Let's use a 'done_flag' or just check counters.
            // If gap_lane == 4, transition.
            // We need to detect this.
            // gap_lane is updated in the sequential block.
            // So in combinational block, if gap_lane < 4, stay. If gap_lane >= 4, next.
            // However, gap_lane might be 3 and we are still processing it.
            // 
            // Let's add a `processing_lane` flag or rely on `gap_car_idx`.
            // Actually, `gap_lane` is the index of the lane currently being processed.
            // When `gap_lane` becomes 4, we are done.
            // 
            // To handle the "done with gap_lane 3" -> "gap_lane 4" transition:
            // In the sequential block, when we finish gap_lane 3, we set gap_lane to 4.
            // So in next cycle, state will switch.
            // 
            // But how do we know we are done with gap_lane 3?
            // We need to detect end of gap calculation for lane 3.
            // 
            // Let's modify the logic slightly.
            // In FIND_GAPS block:
            // if (gap_lane < 4) ...
            // else: transition.
            // 
            // But `gap_lane` is 3 inside the block. How do we reach 4?
            // We increment `gap_lane` when done.
            // 
            // So, if `gap_lane` becomes 4 inside the block, we must force transition.
            // But we can't modify `next_state` inside an `else if` block easily.
            // 
            // Let's cheat: if `gap_lane` == 3 AND we finish processing, then `next_state = CHECK_SWITCH`.
            // If `gap_lane` < 3, `next_state = FIND_GAPS`.
            // 
            // Wait, `gap_lane` is updated at the end of the cycle.
            // So `next_state` logic can look at the *current* `gap_lane`.
            // 
            // If `gap_lane` < 4, we stay in FIND_GAPS.
            // If `gap_lane` >= 4, we move to CHECK_SWITCH.
            // 
            // But `gap_lane` starts at 0.
            // We need to ensure we finish lane 3.
            // In sequential block, we increment `gap_lane` when done.
            // So `gap_lane` will be 0, 1, 2, 3, 4.
            // While `gap_lane` is 0..3, we do work.
            // When `gap_lane` becomes 4, next cycle we exit.
            // 
            // What if `gap_lane` is 3 and we haven't finished? We stay.
            // 
            // Let's add a condition:
            // if (gap_lane < 4) next_state = FIND_GAPS;
            // else next_state = CHECK_SWITCH;
            // 
            // Wait, what if `cars_per_lane[3]` is 0? We increment immediately.
            // 
            // Let's assume this logic works.
            if (gap_lane < 4) begin
                next_state = FIND_GAPS;
            end else begin
                next_state = CHECK_SWITCH;
            end
        end
        
        CHECK_SWITCH: begin
            // Logic:
            // We iterate check_lane 0, 1, 2 (for lanes 1, 2, 3).
            // If we finish lane 2, move to CALC_SAFETY.
            // If we find impossible, move to DONE.
            // 
            // We need to know if we are done with a lane.
            // In the sequential block, we iterate `gap_car_idx`.
            // When `gap_car_idx` hits `gap_count`, we process and increment `check_lane`.
            // 
            // So, `check_lane` will be 0, 1, 2, 3.
            // If `check_lane` becomes 3 (meaning we just finished 2), we move to CALC_SAFETY.
            // 
            // If `impossible` is set, we move to DONE.
            // 
            // So:
            if (impossible) begin
                next_state = DONE_STATE;
            end else if (check_lane < 3) begin // Actually, if check_lane is 0,1,2, we stay. If 3, we are done.
                // Wait, `check_lane` is incremented in seq block.
                // Start: 0. (Lane 1).
                // End of 0: 1. (Lane 2).
                // End of 1: 2. (Lane 3).
                // End of 2: 3.
                // When check_lane == 3, we are done with lanes 1,2,3.
                // So:
                if (check_lane == 3) next_state = CALC_SAFETY;
                else next_state = CHECK_SWITCH;
            end else begin
                next_state = CALC_SAFETY;
            end
            // Wait, the above is slightly buggy. 
            // If `check_lane` is 2, we are processing lane 3.
            // When done, `check_lane` becomes 3.
            // So we need `if (check_lane < 3) stay, else next`.
            // BUT, `check_lane` is updated in seq block. 
            // So in combinational block, if `check_lane` is already 3, we transition.
            // 
            // Let's simplify:
            // If `check_lane` < 3, stay in CHECK_SWITCH.
            // If `check_lane` >= 3, move to CALC_SAFETY.
            // 
            // However, we need to handle the case where we are NOT done with the lane yet.
            // `gap_car_idx` determines if we are done.
            // If `gap_car_idx` < `gap_count`, we stay in CHECK_SWITCH.
            // 
            // Let's use `sort_jdx` to indicate if we are done with the lane.
            // Or just use `check_lane` and `gap_car_idx`.
            // 
            // Let's assume `check_lane` only increments when a lane is fully processed.
            // So we just check `check_lane`.
            // 
            // Wait, impossible check.
            // If impossible is set, next_state = DONE.
            // 
            // Let's refine:
            // If impossible set, DONE.
            // Else if check_lane >= 3, CALC_SAFETY.
            // Else CHECK_SWITCH.
            
            if (impossible) next_state = DONE_STATE;
            else if (check_lane >= 3) next_state = CALC_SAFETY;
            else next_state = CHECK_SWITCH;
            // Note: check_lane logic needs to be careful.
            // `check_lane` 0, 1, 2 correspond to lanes 1, 2, 3.
            // We update `check_lane` in seq block.
            // Start: 0.
            // After Lane 1: 1.
            // After Lane 2: 2.
            // After Lane 3: 3.
            // So yes, `check_lane >= 3` means done with lanes 1,2,3.
        end
        
        CALC_SAFETY: begin
            // Lane 0 logic.
            // `check_lane` used as sub-state counter.
            // 0: Init
            // 1: Scan
            // 2: Calc
            // 3: Update min
            // 
            // We can just iterate `check_lane` 0 to 2 (or 3).
            // If `check_lane` < 2, stay.
            // If `check_lane` >= 2, move to DONE.
            // 
            // But we need to know when scan is done.
            // `gap_car_idx` iterates.
            // 
            // Let's assume `check_lane` is updated in seq block.
            // We want to stay until done.
            // 
            // Let's use a specific flag or counter.
            // 
            // Actually, let's just use `check_lane` 0, 1, 2.
            // 
            // To keep it simple:
            // If `check_lane` < 2, stay.
            // Else, DONE.
            // 
            // (Wait, if `check_lane` is 0 -> init. 1 -> scan. 2 -> calc. 3 -> update).
            // So stay until `check_lane` becomes 4.
            // 
            // Let's refine the SEQ logic for CALC_SAFETY to be clear.
            // 
            // I will just use `if (check_lane < 2)` for simplicity in the example, 
            // assuming the seq logic moves it to 3 to exit.
            // 
            // Actually, let's check if `gap_car_idx` is done.
            // If `gap_car_idx` < cars_per_lane[0], stay.
            // Else, next step.
            // 
            // But `check_lane` controls the step.
            // 
            // Let's go with: stay in CALC_SAFETY until `impossible` or `done` flag.
            // Or use `check_lane` to count steps.
            // 
            // Let's assume `check_lane` 0 = init, 1 = scan, 2 = calc.
            // If `check_lane` is 2, we are done.
            // 
            // If we use `gap_car_idx` for scanning:
            // While `gap_car_idx` < count, stay in step 1.
            // 
            // This is getting messy. Let's stick to the simplest:
            // CALC_SAFETY state will just take a few cycles.
            // We use `check_lane` as a step counter.
            // 
            // Seq Logic:
            // if step == 0: reset. step = 1.
            // if step == 1: scan. if done, step = 2.
            // if step == 2: calc. step = 3.
            // if step == 3: update min. -> DONE.
            // 
            // So in Next State:
            if (check_lane < 3) next_state = CALC_SAFETY;
            else next_state = DONE_STATE;
        end
        
        DONE_STATE: begin
            next_state = IDLE; // Auto reset or stay? Usually stay until next start.
            // Let's stay in DONE until reset or start.
            if (start) next_state = READ_INPUT; // Or IDLE?
            // The prompt says "on start: transition to PROCESSING".
            // So if done, and start again, restart.
        end
        
        default: next_state = IDLE;
    endcase
end

endmodule
