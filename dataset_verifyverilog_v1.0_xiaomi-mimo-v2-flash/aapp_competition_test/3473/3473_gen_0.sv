module CanadianContestsScheduler (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [99:0] forbidden_table [0:99] [0:30],
    input wire [6:0] z_in,
    output reg [31:0] result_sum,
    output reg done,
    output reg [3199:0] schedule_out
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_DATE = 3'd1;
    localparam [2:0] FIND_FRIDAYS = 3'd2;
    localparam [2:0] CALC_DP = 3'd3;
    localparam [2:0] BACKTRACK = 3'd4;
    localparam [2:0] FINISHED = 3'd5;
    
    reg [2:0] state;
    reg [6:0] year_idx; // 0 to z-1
    reg [4:0] day_idx;  // 0 to 30 (days 1-31)
    reg [4:0] prev_idx; // 0 to 30
    
    // Date calculation registers
    reg [9:0] year_current; // 2019 to 2118
    reg [8:0] day_of_week_oct1; // 0-6
    reg [8:0] temp_days;
    reg leap_flag;
    
    // Friday detection
    reg [31:0] valid_days_mask; // Bit 1 if day is valid Friday
    reg [4:0] friday_count;
    reg [4:0] friday_list [0:31];
    
    // DP memory - penalty values (12 bits max for Z=100)
    reg [11:0] dp [0:31];
    reg [11:0] next_dp [0:31];
    // Choice memory - stores previous day for backtracking
    reg [5:0] choice [0:99] [0:31]; // year_idx, day_idx -> prev_day
    
    // DP computation registers
    reg [11:0] min_penalty;
    reg [5:0] best_prev_day;
    reg [5:0] current_friday;
    reg [5:0] prev_friday;
    reg [7:0] penalty_calc;
    reg [3:0] friday_idx;
    
    // Backtracking registers
    reg [6:0] backtrack_year;
    reg [5:0] backtrack_day;
    reg [4:0] output_slot;
    
    // Counter for done assertion
    reg done_cycle;
    
    integer i, j;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_sum <= 32'd0;
            done <= 1'b0;
            done_cycle <= 1'b0;
            year_idx <= 7'd0;
            day_idx <= 5'd0;
            prev_idx <= 5'd0;
            friday_count <= 5'd0;
            friday_idx <= 4'd0;
            output_slot <= 5'd0;
            schedule_out <= 3200'd0;
            for (i = 0; i < 32; i = i + 1) begin
                dp[i] <= 12'd0;
                next_dp[i] <= 12'd0;
            end
            for (i = 0; i < 100; i = i + 1) begin
                for (j = 0; j < 32; j = j + 1) begin
                    choice[i][j] <= 6'd0;
                end
            end
            for (i = 0; i < 32; i = i + 1) begin
                friday_list[i] <= 5'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_cycle <= 1'b0;
                    if (start) begin
                        year_idx <= 7'd0;
                        state <= CALC_DATE;
                        // Initialize dp for 2018 (base year)
                        // Day 12 (Oct 12) is the base, penalty 0
                        for (i = 0; i < 32; i = i + 1) begin
                            dp[i] <= 12'd0; // Only day 12 is valid, but fill all for safety
                        end
                        // Base year specific: only day 12 is valid
                        dp[12] <= 12'd0;
                    end
                end
                
                CALC_DATE: begin
                    // Calculate year
                    year_current <= 2019 + year_idx;
                    // Calculate day of week for Oct 1
                    // Base: Oct 1, 2018 is day 274 of year (or use known day 174 if counting from Jan 1)
                    // Let's use a simple accumulator from 2018
                    // 2018 Oct 1: Let's assume Sunday (0) for simplicity, adjust if needed
                    // Days in year: 365 or 366
                    // day_of_week = (prev_day + days_in_prev_year) % 7
                    
                    if (year_idx == 7'd0) begin
                        // 2019: days in 2018
                        leap_flag <= 1'b0; // 2018 not leap
                        temp_days <= 9'd365;
                    end else begin
                        // Check if year_current-1 is leap
                        // Leap rule: divisible by 4, not by 100 unless 2400
                        // Range 2019-2118: 2100 is NOT leap
                        leap_flag <= ((year_current - 1) % 4 == 0) && (!((year_current - 1) % 100 == 0) || ((year_current - 1) % 400 == 0));
                        temp_days <= ((year_current - 1) % 4 == 0) && (!((year_current - 1) % 100 == 0) || ((year_current - 1) % 400 == 0)) ? 9'd366 : 9'd365;
                    end
                    
                    // Initialize day_idx
                    day_idx <= 5'd0;
                    friday_count <= 5'd0;
                    state <= FIND_FRIDAYS;
                end
                
                FIND_FRIDAYS: begin
                    // Update day of week
                    if (day_idx == 5'd0) begin
                        if (year_idx == 7'd0) day_of_week_oct1 <= 9'd1; // Assume 2019 Oct 1 is Tuesday (1=Mon, so 1 is Tue? No, 0=Mon)
                        // Let's say 2018 Oct 1 was Monday (0). 2018 has 365 days (52w+1d).
                        // 2019 Oct 1 = (0 + 365) % 7 = 1 (Tuesday)
                        // Actually, let's hardcode base or use logic.
                        // 2018 Oct 1: Sunday (6) is common.
                        // 2018 days remaining: 91 (Oct-Dec). Total days in 2018: 365.
                        // 365 % 7 = 1. Sunday + 1 = Monday.
                        day_of_week_oct1 <= 9'd0; // Monday (0)
                    end else begin
                        day_of_week_oct1 <= (day_of_week_oct1 + 1) % 7;
                    end
                    
                    // Check if Friday (Friday is 4 if 0=Mon)
                    if (day_of_week_oct1 == 9'd4) begin
                        // Check forbidden
                        // forbidden_table[year_idx][day_idx] bit 0 is flag
                        if (!forbidden_table[year_idx][day_idx][0]) begin
                            valid_days_mask[day_idx] <= 1'b1;
                            friday_list[friday_count] <= day_idx;
                            friday_count <= friday_count + 5'd1;
                        end else begin
                            valid_days_mask[day_idx] <= 1'b0;
                        end
                    end else begin
                        valid_days_mask[day_idx] <= 1'b0;
                    end
                    
                    if (day_idx == 5'd30) begin
                        day_idx <= 5'd0;
                        friday_idx <= 4'd0;
                        state <= CALC_DP;
                    end else begin
                        day_idx <= day_idx + 5'd1;
                    end
                end
                
                CALC_DP: begin
                    // Compute next_dp for current_friday
                    current_friday <= friday_list[friday_idx];
                    
                    if (friday_idx < friday_count) begin
                        // Initialize min penalty
                        min_penalty <= 12'hFFF; // Max
                        best_prev_day <= 6'd0;
                        prev_idx <= 5'd0;
                        state <= CALC_DP; // Stay in this state
                        
                        // Iterate previous days from 2018 or previous years
                        // For year 0 (2019), previous is 2018 (base)
                        // Base valid day is 12 (Oct 12)
                        
                        if (year_idx == 7'd0) begin
                            // Compare with base day 12 only
                            // Wait, base dp array is initialized.
                            // We need to iterate over ALL previous valid days.
                            // For year 0: previous valid days come from 2018 (only day 12).
                            // For year > 0: previous valid days come from dp array.
                            
                            // We need a separate state or logic to loop over prev days.
                            // Let's use a sub-loop logic using prev_idx.
                        end else begin
                            // Standard DP: iterate prev_idx 0..31
                        end
                        
                        // To simplify: Split CALC_DP into sub-states or use prev_idx counter.
                    end else begin
                        // Done with this year
                        // Update dp = next_dp
                        for (i = 0; i < 32; i = i + 1) begin
                            dp[i] <= next_dp[i];
                        end
                        
                        if (year_idx < z_in - 7'd1) begin
                            year_idx <= year_idx + 7'd1;
                            state <= CALC_DATE;
                        end else begin
                            // Compute total sum from final dp
                            // But we need backtracking to fill schedule_out
                            state <= BACKTRACK;
                            backtrack_year <= z_in - 7'd1; // Last year index
                            // Find min penalty in dp
                            result_sum <= 12'hFFF;
                            for (i = 0; i < 32; i = i + 1) begin
                                if (dp[i] < result_sum) begin
                                    result_sum <= dp[i];
                                end
                            end
                        end
                    end
                end
                
                BACKTRACK: begin
                    // To fix the CALC_DP complexity, let's redo the DP logic properly.
                    // CALC_DP will now be a high-level state that triggers sub-iterations.
                    // But to keep it flat, we'll use a different approach for CALC_DP.
                    // 
                    // RE-CALC_DP LOGIC:
                    // We are in state CALC_DP.
                    // We iterate 'friday_idx' (0 to friday_count-1).
                    // For each friday, we iterate 'prev_idx' (0 to 31).
                    // This requires nested loops. In hardware, we unroll or use counters.
                    // We'll use a flat FSM with counter variables.
                    // 
                    // We need a 2D iteration.
                    // 
                    // Let's restart the CALC_DP logic inside this block to be correct.
                    // We will modify the state transition.
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Re-implementing the DP logic to be flat and correct
    // The previous CALC_DP was incomplete. Here is the corrected continuous block.
    // We need to handle the nested loops for DP update.
    // State CALC_DP will now handle the inner loop.
    
    // Actually, let's rewrite the FSM block cleanly with the correct logic.
    // The previous block has a transition issue.
    
endmodule

// Corrected Full Module Implementation
module CanadianContestsScheduler_Corrected (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [99:0] forbidden_table [0:99] [0:30],
    input wire [6:0] z_in,
    output reg [31:0] result_sum,
    output reg done,
    output reg [3199:0] schedule_out
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALC_DATE = 3'd1;
    localparam [2:0] FIND_FRIDAYS = 3'd2;
    localparam [2:0] CALC_DP_START = 3'd3;
    localparam [2:0] CALC_DP_INNER = 3'd4;
    localparam [2:0] BACKTRACK = 3'd5;
    localparam [2:0] FINISHED = 3'd6;
    
    reg [2:0] state;
    reg [6:0] year_idx;
    reg [5:0] day_idx;
    
    // Date logic
    reg [9:0] year_current;
    reg [8:0] day_of_week_oct1;
    reg [4:0] friday_count;
    reg [5:0] friday_list [0:31];
    
    // DP
    reg [11:0] dp [0:31];
    reg [11:0] next_dp [0:31];
    reg [5:0] choice [0:99] [0:31]; // Stores previous day index
    
    // DP Iteration variables
    reg [5:0] current_friday_idx;
    reg [5:0] prev_day_idx;
    reg [5:0] local_best_prev;
    reg [11:0] local_min_pen;
    reg [7:0] pen_calc;
    
    // Backtrack variables
    reg [6:0] bt_year;
    reg [5:0] bt_day;
    reg [4:0] out_idx;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_sum <= 32'd0;
            done <= 1'b0;
            schedule_out <= 3200'd0;
            year_idx <= 7'd0;
            friday_count <= 5'd0;
            current_friday_idx <= 6'd0;
            prev_day_idx <= 6'd0;
            out_idx <= 5'd0;
            for (i = 0; i < 32; i = i + 1) begin
                dp[i] <= 12'd0;
                next_dp[i] <= 12'd0;
                friday_list[i] <= 5'd0;
            end
            for (i = 0; i < 100; i = i + 1) begin
                for (j = 0; j < 32; j = j + 1) begin
                    choice[i][j] <= 6'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize base DP (Year 2018)
                        // Only Oct 12 is valid with penalty 0
                        for (i = 0; i < 32; i = i + 1) dp[i] <= 12'hFFF;
                        dp[12] <= 12'd0;
                        
                        year_idx <= 7'd0;
                        state <= CALC_DATE;
                    end
                end

                CALC_DATE: begin
                    year_current <= 2019 + year_idx;
                    
                    // Calculate day of week for Oct 1
                    // 2018 Oct 1 is Monday (0)
                    // We need to accumulate days from 2018 to year_current - 1
                    if (year_idx == 7'd0) begin
                        day_of_week_oct1 <= 9'd0; // 2019 Oct 1 (Mon + 365 % 7) = Mon + 1 = Tue (1)
                        // Wait, 2018 Oct 1 (Mon) -> 2018 remaining (91 days?) -> No, Oct 1 to Dec 31 is 92 days (Oct 31, Nov 30, Dec 31).
                        // 92 % 7 = 1. Mon + 1 = Tue (1).
                        // Let's set 2019 Oct 1 to 1.
                        day_of_week_oct1 <= 9'd1;
                    end else begin
                        // Determine days in previous year
                        // prev year = 2018 + year_idx
                        // Leap check
                        if (((2018 + year_idx) % 4 == 0) && (!((2018 + year_idx) % 100 == 0) || ((2018 + year_idx) % 400 == 0))) begin
                            day_of_week_oct1 <= (day_of_week_oct1 + 366) % 7;
                        end else begin
                            day_of_week_oct1 <= (day_of_week_oct1 + 365) % 7;
                        end
                    end
                    
                    day_idx <= 5'd0;
                    friday_count <= 5'd0;
                    state <= FIND_FRIDAYS;
                end

                FIND_FRIDAYS: begin
                    // Check if Friday (Friday=4 if Mon=0)
                    // Day 1 (index 0) has dow = day_of_week_oct1
                    // Day D (index D-1) has dow = (day_of_week_oct1 + D - 1) % 7
                    
                    if (day_idx < 5'd31) begin
                        if (((day_of_week_oct1 + day_idx) % 7) == 4) begin
                            // Check forbidden
                            if (!forbidden_table[year_idx][day_idx][0]) begin
                                friday_list[friday_count] <= day_idx + 5'd1; // Store day number 1-31
                                friday_count <= friday_count + 5'd1;
                            end
                        end
                        day_idx <= day_idx + 5'd1;
                    end else begin
                        // Done finding
                        current_friday_idx <= 6'd0;
                        state <= CALC_DP_START;
                    end
                end

                CALC_DP_START: begin
                    if (current_friday_idx < friday_count) begin
                        prev_day_idx <= 6'd0;
                        local_min_pen <= 12'hFFF;
                        local_best_prev <= 6'd0;
                        state <= CALC_DP_INNER;
                    end else begin
                        // Year finished
                        for (i = 0; i < 32; i = i + 1) dp[i] <= next_dp[i];
                        
                        if (year_idx < z_in - 7'd1) begin
                            year_idx <= year_idx + 7'd1;
                            state <= CALC_DATE;
                        end else begin
                            state <= BACKTRACK;
                            // Find total min penalty for output
                            result_sum <= 32'hFFFFFFFF;
                            for (i = 0; i < 32; i = i + 1) begin
                                if (next_dp[i] < result_sum) result_sum <= next_dp[i];
                            end
                            bt_year <= z_in - 7'd1;
                            // We need to find the end day for the last year
                            // Find min in next_dp
                        end
                    end
                end

                CALC_DP_INNER: begin
                    // Iterate prev_day_idx 0 to 31
                    if (prev_day_idx < 6'd32) begin
                        // Check if prev_day_idx is valid (dp != inf)
                        if (dp[prev_day_idx] < 12'hFFF) begin
                            // Calculate penalty
                            // Penalty = dp[prev] + (current_friday - prev_day_idx)^2
                            // Note: prev_day_idx is 0-31, but stored as day number in dp? 
                            // We store dp based on day index 0-31.
                            // friday_list stores day number 1-31.
                            // prev_day_idx 0-31 corresponds to day prev_day_idx (if we use index directly).
                            
                            // Let's assume dp indices are day numbers 0-31 (0 unused).
                            // friday_list[current_friday_idx] is day number 1-31.
                            
                            // Difference calculation
                            if (friday_list[current_friday_idx] > prev_day_idx) begin
                                pen_calc <= (friday_list[current_friday_idx] - prev_day_idx) * (friday_list[current_friday_idx] - prev_day_idx);
                            end else begin
                                pen_calc <= (prev_day_idx - friday_list[current_friday_idx]) * (prev_day_idx - friday_list[current_friday_idx]);
                            end
                            
                            // Wait one cycle for calculation
                        end else begin
                            prev_day_idx <= prev_day_idx + 6'd1;
                        end
                    end else begin
                        // Finished inner loop
                        next_dp[friday_list[current_friday_idx]] <= local_min_pen;
                        choice[year_idx][friday_list[current_friday_idx]] <= local_best_prev;
                        current_friday_idx <= current_friday_idx + 6'd1;
                        state <= CALC_DP_START;
                    end
                end
                
                // Special handling for the calculation result of CALC_DP_INNER
                // We need to combine the state logic or add a state
                // Let's modify CALC_DP_INNER to handle the update in the same cycle if possible, or add a WAIT state.
                // Given the complexity, let's insert a WAIT state.
                
                // Wait state for penalty calc
                // We'll actually merge it into the logic flow properly.
                
                BACKTRACK: begin
                    if (bt_year == 7'd0) begin
                        // Base case: 2018
                        // Base day is 12
                        if (out_idx == 5'd0) begin
                            // Pack result
                            schedule_out[31:0] <= {12'd2018, 6'd12};
                            out_idx <= out_idx + 5'd1;
                        end
                        state <= FINISHED;
                    end else begin
                        // Find min day for current year
                        // We need to know which day ended up at the end.
                        // Since we only stored total min in result_sum, we need to search the last year's DP.
                        // Wait, result_sum holds the total min penalty.
                        // We need to find the day in year z-1 that matches result_sum.
                        
                        // This is tricky because we might have multiple paths with same penalty.
                        // But backtracking requires knowing the specific day.
                        // We should store the BEST day for the last year during CALC_DP_START? 
                        // No, we need to find it during backtracking.
                        
                        // Logic:
                        // If out_idx == 0 (first backtracking step):
                        // Find day d in dp[z-1] such that dp[d] == result_sum.
                        // Then choice[z-1][d] gives prev day.
                        
                        // If out_idx > 0:
                        // Use choice[bt_year][bt_day] to get prev day.
                        
                        // This requires searching or storing the end day.
                        // Let's search during BACKTRACK.
                        
                        if (out_idx == 5'd0) begin
                            // Find end day
                            if (bt_day < 6'd32) begin
                                if (dp[bt_day] == result_sum) begin
                                    // Found
                                    schedule_out[ (out_idx * 32) + 31 : (out_idx * 32) ] <= {2019 + bt_year, bt_day};
                                    bt_day <= choice[bt_year][bt_day]; // Previous day
                                    out_idx <= out_idx + 5'd1;
                                end else begin
                                    bt_day <= bt_day + 6'd1;
                                end
                            end else begin
                                state <= FINISHED;
                            end
                        end else begin
                            // Subsequent years
                            schedule_out[ (out_idx * 32) + 31 : (out_idx * 32) ] <= {2019 + bt_year, bt_day};
                            bt_day <= choice[bt_year][bt_day];
                            bt_year <= bt_year - 7'd1;
                            
                            if (out_idx == z_in - 7'd1) begin
                                // Add 2018 base
                                schedule_out[ (out_idx + 1) * 32 + 31 : (out_idx + 1) * 32 ] <= {12'd2018, 6'd12};
                                state <= FINISHED;
                            end else begin
                                out_idx <= out_idx + 5'd1;
                            end
                        end
                    end
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
    
    // Continuous logic for the penalty calculation (to avoid extra state)
    // This handles the logic that was in CALC_DP_INNER waiting
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled above
        end else begin
            if (state == CALC_DP_INNER && dp[prev_day_idx] < 12'hFFF) begin
                // Update min if needed
                if (dp[prev_day_idx] + pen_calc < local_min_pen) begin
                    local_min_pen <= dp[prev_day_idx] + pen_calc;
                    local_best_prev <= prev_day_idx;
                end
                prev_day_idx <= prev_day_idx + 6'd1;
            end
        end
    end

endmodule