module transit_cost_calculator(
    input clk,
    input rst_n,
    input start,
    input [3:0] l_in,
    input [9:0] p_in [0:9],
    input [5:0] d_in [0:8],
    input [6:0] t_in,
    input [3:0] n_in,
    input [6:0] trip_a [0:9],
    input [6:0] trip_b [0:9],
    output reg [17:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LATCH = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    
    // Latched inputs
    reg [3:0] l_latched;
    reg [9:0] p_latched [0:9];
    reg [5:0] d_latched [0:8];
    reg [6:0] t_latched;
    reg [3:0] n_latched;
    reg [6:0] trip_a_latched [0:9];
    reg [6:0] trip_b_latched [0:9];
    
    // DP state
    reg [17:0] dp [0:127];
    reg [17:0] dp_next [0:127];
    
    // Current day counter
    reg [6:0] day_counter;
    
    // Trip active flags
    reg trip_active [0:127];
    
    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 18'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            day_counter <= 7'd0;
            
            // Initialize DP arrays
            integer i;
            for (i = 0; i < 128; i = i + 1) begin
                dp[i] <= 18'd0;
                dp_next[i] <= 18'd0;
                trip_active[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LATCH;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                LATCH: begin
                    // Latch all inputs
                    l_latched <= l_in;
                    t_latched <= t_in;
                    n_latched <= n_in;
                    
                    integer i;
                    for (i = 0; i < 10; i = i + 1) begin
                        p_latched[i] <= p_in[i];
                    end
                    
                    for (i = 0; i < 9; i = i + 1) begin
                        d_latched[i] <= d_in[i];
                    end
                    
                    for (i = 0; i < 10; i = i + 1) begin
                        trip_a_latched[i] <= trip_a[i];
                        trip_b_latched[i] <= trip_b[i];
                    end
                    
                    // Initialize trip_active array
                    for (i = 0; i < 128; i = i + 1) begin
                        trip_active[i] <= 1'b0;
                    end
                    
                    // Mark trip days as active
                    for (i = 0; i < 10; i = i + 1) begin
                        if (trip_a_latched[i] > 0 && trip_b_latched[i] > 0) begin
                            integer j;
                            for (j = trip_a_latched[i]; j <= trip_b_latched[i]; j = j + 1) begin
                                if (j < 128) begin
                                    trip_active[j] <= 1'b1;
                                end
                            end
                        end
                    end
                    
                    // Initialize DP array
                    dp[0] <= 18'd0;
                    for (i = 1; i < 128; i = i + 1) begin
                        dp[i] <= 18'd0;
                    end
                    
                    day_counter <= 7'd1;
                    next_state <= COMPUTE;
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compute cost for current day
                    if (day_counter <= t_latched) begin
                        integer i;
                        reg [17:0] min_cost;
                        reg [17:0] current_cost;
                        
                        // Option 1: Continue previous interval (if day_counter > 1)
                        if (day_counter > 1) begin
                            min_cost <= dp[day_counter - 1];
                        end else begin
                            min_cost <= 18'd0;
                        end
                        
                        // Option 2: Start new interval at each possible previous day
                        for (i = 0; i < day_counter; i = i + 1) begin
                            current_cost <= dp[i];
                            
                            // Calculate cost for interval from i+1 to day_counter
                            if (i < day_counter) begin
                                reg [6:0] interval_length;
                                interval_length <= day_counter - i;
                                
                                reg [17:0] interval_cost;
                                interval_cost <= 18'd0;
                                
                                // Calculate cost based on pricing levels
                                reg [6:0] remaining_days;
                                remaining_days <= interval_length;
                                
                                integer j;
                                for (j = 0; j < 9; j = j + 1) begin
                                    if (remaining_days > 0 && d_latched[j] > 0) begin
                                        if (remaining_days >= d_latched[j]) begin
                                            interval_cost <= interval_cost + p_latched[j] * d_latched[j];
                                            remaining_days <= remaining_days - d_latched[j];
                                        end else begin
                                            interval_cost <= interval_cost + p_latched[j] * remaining_days;
                                            remaining_days <= 0;
                                        end
                                    end
                                end
                                
                                // Add cost for remaining days at last price level
                                if (remaining_days > 0) begin
                                    interval_cost <= interval_cost + p_latched[9] * remaining_days;
                                end
                                
                                // Subtract cost for trip days (no cost)
                                integer k;
                                for (k = i + 1; k <= day_counter; k = k + 1) begin
                                    if (trip_active[k]) begin
                                        // Find which price level this day falls into
                                        reg [6:0] day_in_interval;
                                        day_in_interval <= k - i;
                                        
                                        reg [6:0] temp_remaining;
                                        temp_remaining <= day_in_interval;
                                        
                                        integer m;
                                        for (m = 0; m < 9; m = m + 1) begin
                                            if (temp_remaining > 0 && d_latched[m] > 0) begin
                                                if (temp_remaining <= d_latched[m]) begin
                                                    interval_cost <= interval_cost - p_latched[m];
                                                    break;
                                                end else begin
                                                    temp_remaining <= temp_remaining - d_latched[m];
                                                end
                                            end
                                        end
                                    end
                                end
                                
                                current_cost <= current_cost + interval_cost;
                                
                                if (current_cost < min_cost) begin
                                    min_cost <= current_cost;
                                end
                            end
                        end
                        
                        dp_next[day_counter] <= min_cost;
                        
                        // Move to next day
                        day_counter <= day_counter + 7'd1;
                        
                        // Check if we've processed all days
                        if (day_counter == t_latched) begin
                            next_state <= FINISH;
                        end else begin
                            next_state <= COMPUTE;
                        end
                    end else begin
                        next_state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Copy result from last day
                    result <= dp_next[t_latched];
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Update DP array at end of cycle
    always @(posedge clk) begin
        if (state == COMPUTE && day_counter > 1) begin
            dp[day_counter - 1] <= dp_next[day_counter - 1];
        end
    end

endmodule