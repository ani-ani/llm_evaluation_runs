module transit_card_cost (
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

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SETUP = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [6:0] current_day;
    reg [6:0] current_start;
    reg [17:0] dp [0:128]; // dp[i] = min cost for first i days
    reg [17:0] trip_cost [0:128]; // Cost of trip covering day i
    reg [17:0] min_cost;
    reg [17:0] new_cost;
    reg is_active;
    reg [3:0] level_idx;
    reg [6:0] day_counter;
    reg [6:0] trip_counter;
    reg [3:0] current_l;
    reg [9:0] current_p [0:9];
    reg [5:0] current_d [0:8];
    reg [6:0] current_t;
    reg [3:0] current_n;
    reg [6:0] current_trip_a [0:9];
    reg [6:0] current_trip_b [0:9];
    reg [17:0] cost_temp;
    reg [17:0] trip_cost_temp;
    reg [6:0] trip_end_temp;
    reg [6:0] interval_len;
    reg [6:0] remaining_days;
    reg [6:0] level_remaining;
    reg [17:0] base_cost;
    reg [17:0] final_trip_cost;
    reg calculate_trip_cost_flag;
    reg [6:0] loop_i;
    reg [6:0] loop_j;
    reg [6:0] loop_k;
    
    // Loop counters for combinational logic
    reg [6:0] calc_day;
    reg [6:0] calc_start;
    reg [6:0] calc_len;
    reg [3:0] calc_level;
    reg [17:0] calc_accum;
    reg [6:0] calc_remaining;
    reg [6:0] calc_used;
    reg [3:0] calc_l_idx;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 18'd0;
            done <= 1'b0;
            current_day <= 7'd0;
            current_start <= 7'd0;
            min_cost <= 18'd0;
            new_cost <= 18'd0;
            is_active <= 1'b0;
            level_idx <= 4'd0;
            day_counter <= 7'd0;
            trip_counter <= 7'd0;
            current_l <= 4'd0;
            current_t <= 7'd0;
            current_n <= 4'd0;
            cost_temp <= 18'd0;
            trip_cost_temp <= 18'd0;
            trip_end_temp <= 7'd0;
            interval_len <= 7'd0;
            remaining_days <= 7'd0;
            level_remaining <= 7'd0;
            base_cost <= 18'd0;
            final_trip_cost <= 18'd0;
            calculate_trip_cost_flag <= 1'b0;
            calc_day <= 7'd0;
            calc_start <= 7'd0;
            calc_len <= 7'd0;
            calc_level <= 4'd0;
            calc_accum <= 18'd0;
            calc_remaining <= 7'd0;
            calc_used <= 7'd0;
            calc_l_idx <= 4'd0;
            loop_i <= 7'd0;
            loop_j <= 7'd0;
            loop_k <= 7'd0;
            // Initialize arrays
            begin : init_arrays
                integer i;
                for (i = 0; i < 129; i = i + 1) begin
                    dp[i] <= 18'd0;
                    trip_cost[i] <= 18'd0;
                end
                for (i = 0; i < 10; i = i + 1) begin
                    current_p[i] <= 10'd0;
                    current_trip_a[i] <= 7'd0;
                    current_trip_b[i] <= 7'd0;
                end
                for (i = 0; i < 9; i = i + 1) begin
                    current_d[i] <= 6'd0;
                end
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Latch inputs
                        current_l <= l_in;
                        current_t <= t_in;
                        current_n <= n_in;
                        // Copy arrays
                        begin : latch_inputs
                            integer i;
                            for (i = 0; i < 10; i = i + 1) begin
                                current_p[i] <= p_in[i];
                                current_trip_a[i] <= trip_a[i];
                                current_trip_b[i] <= trip_b[i];
                            end
                            for (i = 0; i < 9; i = i + 1) begin
                                current_d[i] <= d_in[i];
                            end
                        end
                        day_counter <= 7'd0;
                        trip_counter <= 7'd0;
                        loop_i <= 7'd0;
                    end
                end
                
                SETUP: begin
                    // Reset trip_cost
                    trip_cost[loop_i] <= 18'd0;
                    loop_i <= loop_i + 7'd1;
                    if (loop_i == 7'd128) begin
                        loop_i <= 7'd0;
                    end
                    // Calculate trip costs
                    if (trip_counter < current_n) begin
                        trip_end_temp <= current_trip_b[trip_counter];
                        // Calculate cost for this trip
                        // Not doing inline calculation here to avoid timing issues
                        trip_counter <= trip_counter + 7'd1;
                    end
                end
                
                CALCULATE: begin
                    if (loop_i < current_t) begin
                        // Initialize dp[loop_i] to a large value
                        dp[loop_i] <= 18'h3FFFF; // Max 18-bit
                        loop_i <= loop_i + 7'd1;
                    end else if (loop_j < current_t) begin
                        // For each day j
                        current_start <= loop_j + 7'd1;
                        // Check if day is trip day
                        is_active <= 1'b1;
                        begin : check_trip_active
                            integer k;
                            for (k = 0; k < 10; k = k + 1) begin
                                if ((loop_j + 7'd1) >= current_trip_a[k] && (loop_j + 7'd1) <= current_trip_b[k]) begin
                                    if (k < current_n) begin
                                        is_active <= 1'b0;
                                    end
                                end
                            end
                        end
                        
                        // Calculate cost for interval from start to j+1
                        if (is_active) begin
                            interval_len <= loop_j + 7'd1 - current_start + 7'd1;
                            calc_len <= loop_j + 7'd1 - current_start + 7'd1;
                            calc_start <= current_start;
                            calc_l_idx <= 4'd0;
                            calc_accum <= 18'd0;
                            calc_remaining <= loop_j + 7'd1 - current_start + 7'd1;
                            calc_used <= 7'd0;
                            // Wait for calculation
                            calculate_trip_cost_flag <= 1'b1;
                        end else begin
                            // Trip day, cost is 0
                            if (current_start == loop_j + 7'd1) begin
                                // Single trip day interval
                                cost_temp <= dp[current_start - 7'd2] + 18'd0;
                            end else begin
                                // Multi-day interval with trip days
                                // Simplify: cost is dp[start-1] + 0
                                cost_temp <= dp[current_start - 7'd2] + 18'd0;
                            end
                        end
                        loop_j <= loop_j + 7'd1;
                    end else if (loop_k < current_t) begin
                        // Finalize dp value
                        if (is_active && calculate_trip_cost_flag) begin
                            dp[loop_k + 7'd1] <= cost_temp;
                        end else begin
                            dp[loop_k + 7'd1] <= cost_temp;
                        end
                        loop_k <= loop_k + 7'd1;
                    end
                    
                    // Combinational calculation for cost
                    if (calculate_trip_cost_flag && calc_l_idx <= current_l) begin
                        if (calc_remaining > 0) begin
                            if (calc_l_idx == 0) begin
                                // First level
                                level_remaining <= (calc_used < current_d[0]) ? (current_d[0] - calc_used) : 7'd0;
                                if (level_remaining > 0 && calc_remaining > 0) begin
                                    calc_used <= calc_used + calc_remaining;
                                    calc_accum <= calc_accum + (calc_remaining * current_p[0]);
                                    calc_remaining <= 7'd0;
                                end
                            end else if (calc_l_idx < current_l) begin
                                // Middle levels
                                level_remaining <= (calc_used < (current_d[calc_l_idx-1] + current_d[calc_l_idx])) ? ((current_d[calc_l_idx-1] + current_d[calc_l_idx]) - calc_used) : 7'd0;
                                if (level_remaining > 0 && calc_remaining > 0) begin
                                    calc_used <= calc_used + calc_remaining;
                                    calc_accum <= calc_accum + (calc_remaining * current_p[calc_l_idx]);
                                    calc_remaining <= calc_remaining;
                                end
                            end else begin
                                // Last level
                                calc_accum <= calc_accum + (calc_remaining * current_p[current_l-1]);
                                calc_remaining <= 7'd0;
                            end
                            calc_l_idx <= calc_l_idx + 4'd1;
                        end else begin
                            calculate_trip_cost_flag <= 1'b0;
                            cost_temp <= dp[calc_start - 7'd2] + calc_accum;
                        end
                    end
                    
                    if (loop_k >= current_t) begin
                        // Update result
                        result <= dp[current_t];
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = SETUP;
                else next_state = IDLE;
            end
            SETUP: begin
                if (trip_counter >= current_n && loop_i == 7'd128) begin
                    next_state = CALCULATE;
                end else begin
                    next_state = SETUP;
                end
            end
            CALCULATE: begin
                if (loop_k >= current_t) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALCULATE;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule