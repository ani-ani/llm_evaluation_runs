module calorie_optimizer(
    input clk,
    input rst_n,
    input start,
    input [7:0] m,
    input [7:0] calories_0,
    input [7:0] calories_1,
    input [7:0] calories_2,
    input [7:0] calories_3,
    input [7:0] calories_4,
    output reg [15:0] result,
    output reg done
);

    // FSM States
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    reg [1:0] state;
    reg [3:0] hour_counter;  // 0-5 hours (5 courses, 5 hours)
    reg [7:0] cycle_counter; // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // DP State Dimensions: hour (0-5), streak (0-2), skip (0-1)
    // total states = 6 * 3 * 2 = 36
    // We'll store in a compressed format
    
    // Current and next max calories for each (streak, skip) state
    reg [15:0] dp_current [0:2][0:1];  // 3x2 = 6 entries
    reg [15:0] dp_next [0:2][0:1];
    
    // Helper registers for computation
    reg [15:0] temp_result;
    reg [15:0] temp_eat_value;
    reg [7:0]  temp_rate;
    reg [15:0] temp_skip_value;
    reg [2:0]  s;  // streak loop
    reg [1:0]  k;  // skip loop
    reg [2:0]  ns; // next streak
    reg [1:0]  nk; // next skip
    reg [15:0] candidate_eat;
    reg [15:0] candidate_skip;
    
    // Rate calculation helper
    function automatic [7:0] calc_rate;
        input [7:0] prev_rate;
        input [1:0] streak;
        begin
            if (streak == 2'd0) begin
                // First hour or after skip reset
                calc_rate = m;
            end else begin
                // streak >= 1: rate = floor(2/3 * prev_rate)
                // Using: floor(m * 171 / 256) = (m * 171) >> 8
                calc_rate = (prev_rate * 8'd171) >> 8;
            end
        end
    endfunction
    
    // Get current hour's calories
    function automatic [7:0] get_calories;
        input [3:0] hour_idx;
        begin
            case (hour_idx)
                4'd0: get_calories = calories_0;
                4'd1: get_calories = calories_1;
                4'd2: get_calories = calories_2;
                4'd3: get_calories = calories_3;
                4'd4: get_calories = calories_4;
                default: get_calories = 8'd0;
            endcase
        end
    endfunction
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            hour_counter <= 4'd0;
            cycle_counter <= 8'd0;
            // Initialize all dp_current entries
            for (s = 0; s < 3; s = s + 1) begin
                for (k = 0; k < 2; k = k + 1) begin
                    dp_current[s][k] <= 16'd0;
                    dp_next[s][k] <= 16'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    hour_counter <= 4'd0;
                    
                    // Initialize DP for hour 0 (before any eating)
                    // Starting state: streak=0 (no hour 0 eaten yet), skip=0
                    // But we need to initialize for the computation loop
                    // For hour 0, we consider all possible starting actions
                    // Actually, let's restructure: dp_current stores best values BEFORE current hour
                    // Initial state: streak=0, skip=0, total=0
                    for (s = 0; s < 3; s = s + 1) begin
                        for (k = 0; k < 2; k = k + 1) begin
                            dp_current[s][k] <= 16'd0;
                        end
                    end
                    // Only (streak=0, skip=0) is valid initially
                    // Others are initialized to 0 anyway
                    
                    if (start) begin
                        state <= COMPUTE;
                        hour_counter <= 4'd0;  // Process hour 0 first
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Clear next state table
                    for (s = 0; s < 3; s = s + 1) begin
                        for (k = 0; k < 2; k = k + 1) begin
                            dp_next[s][k] <= 16'd0;
                        end
                    end
                    
                    // Process current hour
                    if (hour_counter < 5) begin
                        // For each valid (streak, skip) state
                        // Valid states: streak 0-2, skip 0-1
                        // But not all combinations are valid:
                        // - streak=0 means previous hour was skipped (or start)
                        // - skip=0 means previous hour was eaten
                        // Let's handle all 6 states and let DP filter
                        
                        // Pre-calculate calorie value for this hour
                        temp_rate <= calc_rate(m, 2'd0); // placeholder
                        
                        // Process each state (streak, skip)
                        // State 0: streak=0, skip=0 (invalid, ignore)
                        // State 1: streak=0, skip=1 (came from skip, now streak reset)
                        // State 2: streak=1, skip=0 (ate once)
                        // State 3: streak=2, skip=0 (ate twice)
                        // State 4: streak=1, skip=1 (ate once then skipped, streak resets)
                        // State 5: streak=2, skip=1 (ate twice then skipped)
                        
                        // Actually, let's enumerate properly:
                        // After hour i, we have:
                        //  - streak: 0 if hour i was skipped, 1 if hour i ate and prev was skip, 2 if hour i ate and prev ate
                        //  - skip: 0 if hour i ate, 1 if hour i skipped
                        
                        // But we need to track state BEFORE hour i
                        // Let's use: state before hour i = (streak_from_prev, skip_from_prev)
                        // After eating hour i: streak = min(prev_streak + 1, 2), skip = 0
                        // After skipping hour i: streak = 0, skip = min(prev_skip + 1, 1)
                        
                        // For hour 0:
                        // Before: streak=0, skip=0
                        // Eat: streak=1, skip=0, total=min(c[0], m)
                        // Skip: streak=0, skip=1, total=0
                        
                        // We'll compute dp_next from dp_current
                        
                        // First, get calories for current hour
                        temp_rate <= get_calories(hour_counter);
                        
                        // Process eat option for all prev states
                        for (s = 0; s < 3; s = s + 1) begin
                            for (k = 0; k < 2; k = k + 1) begin
                                if (dp_current[s][k] != 16'd0 || (s == 0 && k == 0)) begin
                                    // Calculate rate if eating
                                    // Rate depends on how many consecutive hours eaten BEFORE this hour
                                    if (s == 2'd0) begin
                                        // Previous hour was skipped or start
                                        // If k == 0 and s == 0: start (streak=0 means 0 consecutive eaten)
                                        // If k == 1 and s == 0: previous was skipped
                                        // In either case, rate = m
                                        temp_rate <= m;
                                    end else begin
                                        // s = 1 or 2: ate 1 or 2 hours consecutively before
                                        // If s == 1: ate 1 hour, rate = floor(2/3 * m)
                                        // If s == 2: ate 2 hours, rate = floor(2/3 * prev_rate)
                                        // But we need prev_rate value!
                                        // Let's reconstruct: if s=1, prev_rate was m (first eat)
                                        // if s=2, prev_rate was floor(2/3*m)
                                        if (s == 2'd1) begin
                                            temp_rate <= (m * 8'd171) >> 8;
                                        end else if (s == 2'd2) begin
                                            // Need to track rate in state, or recalculate
                                            // Recalculate: rate after 2 eats = floor(2/3 * floor(2/3 * m))
                                            temp_rate <= ((m * 8'd171) >> 8) * 8'd171 >> 8;
                                        end
                                    end
                                    
                                    // Cap by course calories
                                    // Eat amount = min(calories[hour], rate)
                                    // We need to compare temp_rate with get_calories(hour_counter)
                                    // Since temp_rate is 8-bit and calories is 8-bit
                                    // Actually, let's do this differently
                                    
                                    // New state after eating: streak = min(s+1, 2), skip = 0
                                    ns = (s + 1) > 2 ? 2 : (s + 1);
                                    nk = 0;
                                    
                                    // Calculate eat value
                                    // We need to get the actual rate
                                    // Let's use a separate always block for this
                                    // For now, use a computed value
                                    if (s == 0) begin
                                        temp_eat_value = get_calories(hour_counter) < m ? 
                                                         {8'd0, get_calories(hour_counter)} : {8'd0, m};
                                    end else if (s == 1) begin
                                        temp_rate = (m * 8'd171) >> 8;
                                        temp_eat_value = get_calories(hour_counter) < temp_rate ? 
                                                         {8'd0, get_calories(hour_counter)} : {8'd0, temp_rate};
                                    end else begin
                                        temp_rate = ((m * 8'd171) >> 8) * 8'd171 >> 8;
                                        temp_eat_value = get_calories(hour_counter) < temp_rate ? 
                                                         {8'd0, get_calories(hour_counter)} : {8'd0, temp_rate};
                                    end
                                    
                                    candidate_eat = dp_current[s][k] + temp_eat_value;
                                    
                                    // Update next state
                                    if (candidate_eat > dp_next[ns][nk]) begin
                                        dp_next[ns][nk] <= candidate_eat;
                                    end
                                end
                            end
                        end
                        
                        // Process skip option for all prev states
                        for (s = 0; s < 3; s = s + 1) begin
                            for (k = 0; k < 2; k = k + 1) begin
                                if (dp_current[s][k] != 16'd0 || (s == 0 && k == 0)) begin
                                    // New state after skipping: streak = 0, skip = min(k+1, 1)
                                    ns = 0;
                                    nk = (k + 1) > 1 ? 1 : (k + 1);
                                    
                                    candidate_skip = dp_current[s][k]; // No addition
                                    
                                    // Update next state
                                    if (candidate_skip > dp_next[ns][nk]) begin
                                        dp_next[ns][nk] <= candidate_skip;
                                    end
                                end
                            end
                        end
                        
                        // Move to next hour
                        hour_counter <= hour_counter + 4'd1;
                        
                        // Copy dp_next to dp_current for next iteration
                        for (s = 0; s < 3; s = s + 1) begin
                            for (k = 0; k < 2; k = k + 1) begin
                                dp_current[s][k] <= dp_next[s][k];
                            end
                        end
                        
                    end else begin
                        // Done with all 5 hours
                        state <= FINISH;
                    end
                    
                    // Timeout protection
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Find maximum among all final states
                    temp_result <= 16'd0;
                    for (s = 0; s < 3; s = s + 1) begin
                        for (k = 0; k < 2; k = k + 1) begin
                            if (dp_current[s][k] > temp_result) begin
                                temp_result <= dp_current[s][k];
                            end
                        end
                    end
                    result <= temp_result;
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