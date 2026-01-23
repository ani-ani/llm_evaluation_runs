module contest_scheduler(
    input clk,
    input rst_n,
    input start,
    input [4:0] year_count,
    input [4:0] forbidden_count,
    input [4:0] forbidden_year [0:4],
    input [4:0] forbidden_day [0:4],
    output reg [15:0] min_penalty,
    output reg [4:0] result_year [0:1],
    output reg [4:0] result_day [0:1],
    output reg done
);

    // Parameters
    parameter MAX_YEARS = 2;
    parameter MAX_DATES = 31;
    parameter MAX_FORBIDDEN = 5;

    // State Machine Definition
    reg [3:0] state;
    localparam IDLE = 4'd0;
    localparam CALC_THANKSGIVING = 4'd1;
    localparam FIND_FRIDAYS = 4'd2;
    localparam BUILD_DP = 4'd3;
    localparam EXTRACT_RESULT = 4'd4;
    localparam DONE_STATE = 4'd5;

    // Internal Registers and Arrays
    reg [4:0] i_reg, j_reg, k_reg; // Iterators
    reg [4:0] tg [0:1]; // Thanksgiving dates for years 0 and 1 (mapped to 2019/2020)
    reg valid_date [0:1] [0:30]; // [year][day-1], 1 if valid Friday
    reg [15:0] dp [0:1] [0:30]; // DP table [year][day-1]
    reg [4:0] parent_year [0:1] [0:30]; // Stores parent year index for backtracking (0 or 1)
    reg [4:0] parent_day [0:1] [0:30]; // Stores parent day for backtracking
    
    // Temporary calculation registers
    reg [4:0] temp_year_idx;
    reg [4:0] temp_day;
    reg is_forbidden;
    reg [15:0] penalty_val;
    reg [15:0] min_val;
    reg [4:0] best_prev_day;
    reg [4:0] best_prev_year;
    reg [15:0] diff_sq;
    reg [4:0] temp_diff;

    // Thanksgiving Calculation (2nd Monday in October)
    // For 2019 (Year 1): Oct 1 is Tuesday (2). 2nd Monday is Oct 14.
    // For 2020 (Year 2): Oct 1 is Thursday (4). 2nd Monday is Oct 12.
    // Logic: Find first Monday >= Oct 1, add 7 days.
    // Day of week offset: 2019=2, 2020=4 (0=Sun, 6=Sat)
    // We use i_reg to iterate years 1 to year_count.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_penalty <= 0;
            result_year[0] <= 0;
            result_year[1] <= 0;
            result_day[0] <= 0;
            result_day[1] <= 0;
            i_reg <= 0;
            j_reg <= 0;
            k_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= CALC_THANKSGIVING;
                        i_reg <= 0; // Iterate 0 to year_count-1
                    end
                end

                CALC_THANKSGIVING: begin
                    // Precompute Thanksgiving dates
                    // Year 1 (2019): Offset 2 (Tue). First Mon is day 7? No. Oct 1 is Tue(2). 
                    // Mon(1) is Oct 7. 
                    // Wait, standard logic: 1 - offset + 7 (if offset != 1). 
                    // If offset is 2 (Tue), days to Mon: 6. Day 1+6 = 7. Then +7 = 14.
                    // If offset is 4 (Thu), days to Mon: 4. Day 1+4 = 5. Then +7 = 12.
                    // Correct logic: 
                    // 2019: Oct 1 Tue. 2nd Mon -> Oct 14.
                    // 2020: Oct 1 Thu. 2nd Mon -> Oct 12.
                    
                    if (i_reg < year_count) begin
                        if (i_reg == 0) tg[0] <= 5'd14; // 2019
                        else tg[1] <= 5'd12; // 2020
                        i_reg <= i_reg + 1;
                    end else begin
                        state <= FIND_FRIDAYS;
                        i_reg <= 0;
                        j_reg <= 1; // Start day 1
                    end
                end

                FIND_FRIDAYS: begin
                    // Iterate through years and days to populate valid_date
                    if (i_reg < year_count) begin
                        if (j_reg <= 31) begin
                            // Check if Friday
                            // 2019: Oct 1 Tue. Fri is Oct 4 (day 4). Period 7 days.
                            // 2020: Oct 1 Thu. Fri is Oct 2 (day 2). Period 7 days.
                            // Check (day - start_offset) % 7 == 0
                            
                            // We can simplify: if (day % 7 == offset) or compute logic.
                            // 2019: Day 4, 11, 18, 25
                            // 2020: Day 2, 9, 16, 23, 30
                            
                            // Compute day of week: (day + start_offset - 1) % 7
                            // 2019: Offset 2 (Tue). (day + 1) % 7 == 5 (Fri)
                            // 2020: Offset 4 (Thu). (day + 3) % 7 == 5 (Fri)
                            
                            // Let's do modulo arithmetic
                            // Modulo 7: (day + const) % 7 == 5
                            // We need a combinational block or simple calculation.
                            // Let's use combinational helper logic or simple arithmetic here.
                            // Since this is sequential state machine, we can calc on the fly.
                            
                            // Check forbidden
                            is_forbidden <= 0;
                            for (int f = 0; f < MAX_FORBIDDEN; f = f + 1) begin
                                if (f < forbidden_count && 
                                    forbidden_year[f] == (i_reg + 1) && 
                                    forbidden_day[f] == j_reg) begin
                                    is_forbidden <= 1;
                                end
                            end

                            // Check Thanksgiving-1 (Saturday before Thanksgiving)
                            if (j_reg == (tg[i_reg] - 1)) is_forbidden <= 1;

                            // Check Friday
                            // Helper variable for Friday check
                            reg is_fri;
                            if (i_reg == 0) is_fri = ((j_reg + 1) % 7 == 5); // 2019
                            else is_fri = ((j_reg + 3) % 7 == 5); // 2020

                            valid_date[i_reg][j_reg-1] <= is_fri & ~is_forbidden;
                            
                            j_reg <= j_reg + 1;
                        end else begin
                            j_reg <= 1;
                            i_reg <= i_reg + 1;
                        end
                    end else begin
                        state <= BUILD_DP;
                        i_reg <= 0;
                        j_reg <= 0;
                        k_reg <= 0;
                        // Initialize DP for year 0
                        // If valid, penalty 0, else infinite
                        // We use 16'hFFFF for infinity
                    end
                end

                BUILD_DP: begin
                    // DP Algorithm
                    // DP[i][d] = min(prev_dp[pd] + (d-pd)^2)
                    
                    if (i_reg == 0) begin
                        // Base case: Year 0
                        if (j_reg < 31) begin
                            if (valid_date[0][j_reg]) begin
                                dp[0][j_reg] <= 0;
                            end else begin
                                dp[0][j_reg] <= 16'hFFFF;
                            end
                            j_reg <= j_reg + 1;
                        end else begin
                            i_reg <= 1;
                            j_reg <= 0;
                            k_reg <= 0; // k_reg tracks the previous year date
                            min_val <= 16'hFFFF;
                            best_prev_day <= 0;
                            best_prev_year <= 0;
                        end
                    end else if (i_reg < year_count) begin
                        // Compute DP for year i_reg (using year i_reg-1)
                        // Inner loop: iterate over prev dates (k_reg)
                        // Outer loop: iterate over current dates (j_reg)
                        
                        // We need to find min over k_reg for fixed j_reg.
                        // Since k_reg goes 0..30, we can process sequentially.
                        
                        if (j_reg < 31) begin
                            if (valid_date[i_reg][j_reg]) begin
                                // Check previous date k_reg
                                if (k_reg < 31) begin
                                    // Compare dp[i_reg-1][k_reg] + diff^2
                                    // Only if prev is valid (dp value != inf)
                                    if (dp[i_reg-1][k_reg] < 16'hFFFF) begin
                                        // Calculate diff squared
                                        // Using signed arithmetic or handle negative carefully
                                        // d_diff = j_reg - k_reg
                                        // We can assume k_reg and j_reg are 0-30 (representing 1-31)
                                        temp_diff = (j_reg > k_reg) ? (j_reg - k_reg) : (k_reg - j_reg);
                                        // Square: 0-30. 30^2 = 900. Fits in 16 bits.
                                        diff_sq = temp_diff * temp_diff;
                                        penalty_val = dp[i_reg-1][k_reg] + diff_sq;
                                        
                                        if (penalty_val < min_val) begin
                                            min_val <= penalty_val;
                                            best_prev_day <= k_reg;
                                            best_prev_year <= i_reg - 1;
                                        end
                                    end
                                    k_reg <= k_reg + 1;
                                end else begin
                                    // Finished iterating k_reg for this j_reg
                                    dp[i_reg][j_reg] <= min_val;
                                    parent_year[i_reg][j_reg] <= best_prev_year;
                                    parent_day[i_reg][j_reg] <= best_prev_day;
                                    
                                    // Reset for next j_reg
                                    j_reg <= j_reg + 1;
                                    k_reg <= 0;
                                    min_val <= 16'hFFFF;
                                end
                            end else begin
                                // Invalid date, set infinity
                                dp[i_reg][j_reg] <= 16'hFFFF;
                                j_reg <= j_reg + 1;
                                k_reg <= 0;
                                min_val <= 16'hFFFF;
                            end
                        end else begin
                            // Done this year
                            i_reg <= i_reg + 1;
                            j_reg <= 0;
                        end
                    end else begin
                        // Finished all years
                        state <= EXTRACT_RESULT;
                        // Find min penalty in last year
                        min_penalty <= 16'hFFFF;
                        i_reg <= 0; // Iterate days of last year
                    end
                end

                EXTRACT_RESULT: begin
                    // 1. Find the minimum penalty in the last completed year
                    // 2. Backtrack to fill result arrays
                    
                    if (i_reg == 0) begin
                        // Step 1: Find optimal end state
                        // Iterate days of year_count-1
                        if (j_reg < 31) begin
                            if (dp[year_count-1][j_reg] < min_penalty) begin
                                min_penalty <= dp[year_count-1][j_reg];
                                // Store backtrack starting point
                                result_year[year_count-1] <= year_count; // Year value 1 or 2
                                result_day[year_count-1] <= j_reg + 1; // Day value 1-31
                                k_reg <= j_reg; // Save current best day index
                            end
                            j_reg <= j_reg + 1;
                        end else begin
                            // Start Backtracking
                            // If year_count == 1, done
                            if (year_count == 1) state <= DONE_STATE;
                            else begin
                                i_reg <= 1; // Indicates we are in backtracking phase
                                j_reg <= year_count - 2; // Previous year index to fill
                                // k_reg holds the day index of year_count-1
                            end
                        end
                    end else begin
                        // Step 2: Backtrack
                        // i_reg serves as a flag (1 = backtracking)
                        // j_reg is the year index we are currently filling
                        // We look up parent of result_year[j_reg+1], result_day[j_reg+1]
                        
                        // Let's say j_reg is 0 (2019), we look at year 1 result to find parent
                        // parent_year[1][k_reg] gives year index (0 or 1) - wait, indices
                        // parent arrays store index 0 or 1 relative to internal array
                        
                        // Let's refine:
                        // We need to fill result_year[j_reg] and result_day[j_reg]
                        // The year currently filled at j_reg+1 is result_year[j_reg+1] (value 1 or 2)
                        // The day is result_day[j_reg+1] (value 1-31)
                        // We need internal index for lookup: internal_idx = result_year[j_reg+1] - 1
                        // internal_day = result_day[j_reg+1] - 1
                        
                        // Optimization: Store current year value and day value in temp regs
                        // But we can use result arrays directly if we are careful.
                        
                        // Let's use temp registers to hold the "next" year info during iteration
                        // But simpler: just access result arrays.
                        
                        // We need to map value 1/2 to index 0/1
                        // We need to map value 1-31 to index 0-30
                        
                        // Let's assume we have computed result for year j_reg+1
                        // We need to find parent of that state.
                        
                        // Target Year Index (internal): result_year[j_reg+1] - 1
                        // Target Day Index: result_day[j_reg+1] - 1
                        
                        // Let's use j_reg as the "current year to fill" index.
                        // We are filling result for year j_reg.
                        // The child is year j_reg + 1.
                        
                        // Wait, in first step we filled year_count-1.
                        // So we start with j_reg = year_count - 2.
                        
                        // Source year index for lookup: result_year[j_reg+1] - 1
                        // Source day index for lookup: result_day[j_reg+1] - 1
                        
                        // Logic:
                        reg [4:0] src_year_idx = result_year[j_reg + 1] - 1;
                        reg [4:0] src_day_idx = result_day[j_reg + 1] - 1;
                        
                        result_year[j_reg] <= parent_year[src_year_idx][src_day_idx] + 1;
                        result_day[j_reg] <= parent_day[src_year_idx][src_day_idx] + 1;
                        
                        // Update k_reg for next iteration (if we were using it, but we don't need to store history)
                        
                        if (j_reg == 0) state <= DONE_STATE;
                        else j_reg <= j_reg - 1;
                    end
                end

                DONE_STATE: begin
                    done <= 1;
                    if (!start) begin // Wait for start to go low to reset or allow restart
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end
endmodule

module contest_scheduler(
    input clk,
    input rst_n,
    input start,
    input [4:0] year_count,
    input [4:0] forbidden_count,
    input [4:0] forbidden_year [0:4],
    input [4:0] forbidden_day [0:4],
    output reg [15:0] min_penalty,
    output reg [4:0] result_year [0:1],
    output reg [4:0] result_day [0:1],
    output reg done
);

    // State Machine Definition
    reg [3:0] state;
    localparam IDLE = 4'd0;
    localparam PREP_THANKSGIVING = 4'd1;
    localparam FIND_FRIDAYS = 4'd2;
    localparam BUILD_DP_BASE = 4'd3;
    localparam BUILD_DP_ITER = 4'd4;
    localparam FIND_MIN_FINAL = 4'd5;
    localparam EXTRACT_RESULT = 4'd6;
    localparam DONE_STATE = 4'd7;

    // Internal Registers
    reg [4:0] i_reg, j_reg, k_reg; // Iterators
    reg [4:0] tg [0:1]; // Thanksgiving dates
    reg valid_date [0:1] [0:30]; // Valid Fridays
    reg [15:0] dp [0:1] [0:30]; // DP table
    reg [4:0] parent_idx [0:1] [0:30]; // Stores parent day index
    
    // Combinational helper signals
    wire [4:0] current_day_idx;
    wire [4:0] prev_day_idx;
    wire [4:0] diff;
    wire [15:0] diff_sq;
    wire is_forbidden;
    wire is_thanksgiving_minus_1;
    wire is_friday;
    wire [4:0] lookup_year_idx;
    wire [4:0] lookup_day_idx;

    // Assignments for helpers
    assign current_day_idx = j_reg;
    assign prev_day_idx = k_reg;
    assign diff = (current_day_idx > prev_day_idx) ? (current_day_idx - prev_day_idx) : (prev_day_idx - current_day_idx);
    assign diff_sq = diff * diff;
    
    // Check Friday Logic
    // 2019 (index 0): Offset 2 (Tue). (day+1) % 7 == 5
    // 2020 (index 1): Offset 4 (Thu). (day+3) % 7 == 5
    assign is_friday = (i_reg == 0) ? ((j_reg + 1) % 7 == 5) : ((j_reg + 3) % 7 == 5);

    // Check Forbidden Logic (Combinational Loop)
    integer f_idx;
    assign is_thanksgiving_minus_1 = (j_reg == (tg[i_reg] - 2)); // j_reg is index, tg is value 1-31
    
    assign is_forbidden = (is_thanksgiving_minus_1) || (
        (forbidden_count > 0) && (
            (forbidden_year[0] == (i_reg + 1) && forbidden_day[0] == (j_reg + 1)) ||
            (forbidden_count > 1 && forbidden_year[1] == (i_reg + 1) && forbidden_day[1] == (j_reg + 1)) ||
            (forbidden_count > 2 && forbidden_year[2] == (i_reg + 1) && forbidden_day[2] == (j_reg + 1)) ||
            (forbidden_count > 3 && forbidden_year[3] == (i_reg + 1) && forbidden_day[3] == (j_reg + 1)) ||
            (forbidden_count > 4 && forbidden_year[4] == (i_reg + 1) && forbidden_day[4] == (j_reg + 1))
        )
    );

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_penalty <= 0;
            result_year[0] <= 0; result_year[1] <= 0;
            result_day[0] <= 0; result_day[1] <= 0;
            i_reg <= 0; j_reg <= 0; k_reg <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PREP_THANKSGIVING;
                        i_reg <= 0;
                    end
                end

                PREP_THANKSGIVING: begin
                    // Calculate Thanksgiving for years 1 to year_count
                    // Index 0 (Year 1/2019): Oct 14
                    // Index 1 (Year 2/2020): Oct 12
                    if (i_reg < year_count) begin
                        if (i_reg == 0) tg[0] <= 5'd14;
                        else tg[1] <= 5'd12;
                        i_reg <= i_reg + 1;
                    end else begin
                        state <= FIND_FRIDAYS;
                        i_reg <= 0;
                        j_reg <= 0; // day index 0..30
                    end
                end

                FIND_FRIDAYS: begin
                    // Populate valid_date array
                    if (i_reg < year_count) begin
                        if (j_reg < 31) begin
                            valid_date[i_reg][j_reg] <= is_friday & ~is_forbidden;
                            j_reg <= j_reg + 1;
                        end else begin
                            j_reg <= 0;
                            i_reg <= i_reg + 1;
                        end
                    end else begin
                        state <= BUILD_DP_BASE;
                        i_reg <= 0;
                        j_reg <= 0;
                    end
                end

                BUILD_DP_BASE: begin
                    // Initialize DP for Year 0
                    if (j_reg < 31) begin
                        if (valid_date[0][j_reg]) dp[0][j_reg] <= 0;
                        else dp[0][j_reg] <= 16'hFFFF;
                        j_reg <= j_reg + 1;
                    end else begin
                        if (year_count > 1) begin
                            state <= BUILD_DP_ITER;
                            i_reg <= 1; // Current Year
                            j_reg <= 0; // Current Day
                            k_reg <= 0; // Prev Day
                        end else begin
                            state <= FIND_MIN_FINAL;
                            i_reg <= 0;
                        end
                    end
                end

                BUILD_DP_ITER: begin
                    // DP for Year 1..N
                    // i_reg = current year, j_reg = current day, k_reg = prev day
                    if (j_reg < 31) begin
                        if (valid_date[i_reg][j_reg]) begin
                            // Check k_reg
                            if (k_reg < 31) begin
                                if (dp[i_reg-1][k_reg] < 16'hFFFF) begin
                                    // Calculate min in state logic or use temp reg? 
                                    // Since we are in seq block, we need to accumulate min.
                                    // We can use dp[i_reg][j_reg] as accumulator for min so far.
                                    if (k_reg == 0) begin
                                        // First prev day
                                        dp[i_reg][j_reg] <= dp[i_reg-1][k_reg] + diff_sq;
                                        parent_idx[i_reg][j_reg] <= k_reg;
                                    end else begin
                                        // Compare with current min
                                        if (dp[i_reg-1][k_reg] + diff_sq < dp[i_reg][j_reg]) begin
                                            dp[i_reg][j_reg] <= dp[i_reg-1][k_reg] + diff_sq;
                                            parent_idx[i_reg][j_reg] <= k_reg;
                                        end
                                    end
                                end
                                k_reg <= k_reg + 1;
                            end else begin
                                // Done with this day j_reg
                                j_reg <= j_reg + 1;
                                k_reg <= 0;
                            end
                        end else begin
                            // Invalid day, set INF
                            dp[i_reg][j_reg] <= 16'hFFFF;
                            j_reg <= j_reg + 1;
                            k_reg <= 0;
                        end
                    end else begin
                        // Done this year
                        i_reg <= i_reg + 1;
                        j_reg <= 0;
                        if (i_reg + 1 >= year_count) state <= FIND_MIN_FINAL;
                    end
                end

                FIND_MIN_FINAL: begin
                    // Find min penalty in final year (year_count-1)
                    // Use i_reg for iteration
                    if (i_reg == 0) begin // Init pass
                        min_penalty <= 16'hFFFF;
                        i_reg <= 1;
                        j_reg <= 0;
                    end else begin
                        if (j_reg < 31) begin
                            if (dp[year_count-1][j_reg] < min_penalty) begin
                                min_penalty <= dp[year_count-1][j_reg];
                                result_year[year_count-1] <= year_count; // 1 or 2
                                result_day[year_count-1] <= j_reg + 1;
                            end
                            j_reg <= j_reg + 1;
                        end else begin
                            if (year_count > 1) begin
                                state <= EXTRACT_RESULT;
                                // Setup for backtrack
                                // i_reg will be index of year we are filling (0..year_count-2)
                                i_reg <= year_count - 2;
                            end else begin
                                state <= DONE_STATE;
                            end
                        end
                    end
                end

                EXTRACT_RESULT: begin
                    // Backtrack to fill result_year[i] and result_day[i] for i < year_count-1
                    // i_reg is the index of the year we are currently filling
                    // We need to look at the child (i_reg + 1)
                    // Child Year Index (internal): result_year[i_reg+1] - 1
                    // Child Day Index: result_day[i_reg+1] - 1
                    
                    // Wait, if year_count=2, we filled index 1. We need to fill index 0.
                    // i_reg = 0.
                    // Lookup at year index = result_year[1] - 1. Day = result_day[1] - 1.
                    
                    lookup_year_idx = result_year[i_reg + 1] - 1;
                    lookup_day_idx = result_day[i_reg + 1] - 1;
                    
                    result_year[i_reg] <= parent_idx[lookup_year_idx][lookup_day_idx] + 1; // Parent year value
                    result_day[i_reg] <= parent_idx[lookup_year_idx][lookup_day_idx] + 1; // Parent day value (Wait, logic)
                    // Actually parent_idx stores the day index (0-30) of the PREVIOUS year.
                    // The year index is always i_reg.
                    
                    // Correction:
                    // DP is defined per year.
                    // parent_idx[Year_i][Day_j] stores the Day Index in Year i-1.
                    // So if we are filling result for Year i (index i),
                    // We look at result for Year i+1 (which is already filled).
                    // We need the Day Index of Year i+1 result.
                    // Then parent_idx[Year i+1][DayIndex] gives Day Index for Year i.
                    
                    // So:
                    // Target index to fill: i_reg (Year value = i_reg+1)
                    // Source (next year): result_year[i_reg+1] (val), result_day[i_reg+1] (val)
                    // Source Internal Index Year: result_year[i_reg+1] - 1
                    // Source Internal Index Day: result_day[i_reg+1] - 1
                    
                    // parent_idx[SourceYearIdx][SourceDayIdx] = DayIndex of Previous Year (i_reg)
                    // Previous Year Value is i_reg + 1.
                    
                    result_year[i_reg] <= i_reg + 1;
                    result_day[i_reg] <= parent_idx[result_year[i_reg+1] - 1][result_day[i_reg+1] - 1] + 1;
                    
                    if (i_reg == 0) state <= DONE_STATE;
                    else i_reg <= i_reg - 1;
                end

                DONE_STATE: begin
                    done <= 1;
                    // Wait for start to go low to allow restart
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end
endmodule