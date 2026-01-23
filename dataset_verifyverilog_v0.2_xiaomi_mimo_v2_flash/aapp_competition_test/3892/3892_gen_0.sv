module toy_train(
    input clk,
    input rst_n,
    input start,
    input valid_input,
    input [7:0] a,
    input [7:0] b,
    output reg output_valid,
    output reg [15:0] result,
    output reg busy
);

    // Parameters
    localparam MAX_STATIONS = 8;
    localparam STATE_IDLE = 2'b00;
    localparam STATE_RECV_INPUTS = 2'b01;
    localparam STATE_CALCULATE = 2'b10;
    localparam STATE_OUTPUT = 2'b11;

    // Registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] n; // Number of stations (detected from inputs)
    reg [7:0] next_n;
    reg [7:0] counts [0:MAX_STATIONS-1];
    reg [7:0] next_counts [0:MAX_STATIONS-1];
    reg [7:0] min_dist [0:MAX_STATIONS-1];
    reg [7:0] next_min_dist [0:MAX_STATIONS-1];
    
    // Calculation registers
    reg [7:0] s_reg; // Current start station
    reg [7:0] next_s_reg;
    reg [7:0] i_reg; // Current target station
    reg [7:0] next_i_reg;
    reg [15:0] current_max_time;
    reg [15:0] next_current_max_time;
    reg [15:0] result_reg;
    reg [15:0] next_result_reg;
    
    // Flags
    reg received_any_input;
    reg next_received_any_input;
    reg calculation_done_for_s;

    // Wires for calculation
    wire [15:0] dist_si;
    wire [15:0] time_i;
    
    // Combinational logic for distances and time
    // dist(s, i) = (i - s + n) % n
    // We handle the modulo logic specifically for small n
    reg [7:0] diff;
    always @(*) begin
        if (i_reg >= s_reg)
            diff = i_reg - s_reg;
        else
            diff = i_reg - s_reg + n;
    end
    assign dist_si = {8'd0, diff};
    
    // time_i = dist + min_dist[i] + (counts[i] - 1) * n
    wire [15:0] count_term;
    assign count_term = (counts[i_reg] == 8'd0) ? 16'd0 : (16'd0 + (counts[i_reg] - 8'd1)) * {8'd0, n};
    assign time_i = dist_si + {8'd0, min_dist[i_reg]} + count_term;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            n <= 8'd0;
            received_any_input <= 1'b0;
            s_reg <= 8'd0;
            i_reg <= 8'd0;
            current_max_time <= 16'd0;
            result_reg <= 16'd0;
            output_valid <= 1'b0;
            busy <= 1'b0;
            // Reset arrays
            for (int k = 0; k < MAX_STATIONS; k++) begin
                counts[k] <= 8'd0;
                min_dist[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            n <= next_n;
            received_any_input <= next_received_any_input;
            s_reg <= next_s_reg;
            i_reg <= next_i_reg;
            current_max_time <= next_current_max_time;
            result_reg <= next_result_reg;
            
            // Update arrays
            for (int k = 0; k < MAX_STATIONS; k++) begin
                counts[k] <= next_counts[k];
                min_dist[k] <= next_min_dist[k];
            end
            
            // Output signals
            if (state == STATE_OUTPUT) begin
                output_valid <= 1'b1;
                result <= result_reg;
                busy <= 1'b0;
            end else if (state == STATE_IDLE) begin
                output_valid <= 1'b0;
                result <= 16'd0;
                busy <= 1'b0;
            end else begin
                output_valid <= 1'b0;
                busy <= 1'b1;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Default assignments (keep values unless changed)
        next_state = state;
        next_n = n;
        next_received_any_input = received_any_input;
        next_s_reg = s_reg;
        next_i_reg = i_reg;
        next_current_max_time = current_max_time;
        next_result_reg = result_reg;
        
        // Array defaults
        for (int k = 0; k < MAX_STATIONS; k++) begin
            next_counts[k] = counts[k];
            next_min_dist[k] = min_dist[k];
        end
        
        case (state)
            STATE_IDLE: begin
                if (start) begin
                    next_state = STATE_RECV_INPUTS;
                    // Reset arrays to prepare for new input set
                    for (int k = 0; k < MAX_STATIONS; k++) begin
                        next_counts[k] = 8'd0;
                        next_min_dist[k] = 8'd0; // 0 effectively means "infinite" or not used
                    end
                    next_n = 8'd0;
                    next_received_any_input = 1'b0;
                end
            end
            
            STATE_RECV_INPUTS: begin
                if (valid_input) begin
                    // Update counts and min_dist
                    next_counts[a] = counts[a] + 1'b1;
                    
                    // Calculate distance b - a mod n
                    // Note: n might be updated as we see inputs, or we can update n = max(n, a+1, b+1)
                    // Assuming n is derived from max index seen so far + 1 (or fixed by user logic)
                    // Here we will infer n as max(index) + 1 seen so far.
                    if (a >= n || b >= n) begin
                        if (a > b) next_n = a + 1; else next_n = b + 1;
                    end
                    
                    // Update min_dist for station a
                    // dist = (b - a + n) % n (using logic similar to block above)
                    // We need 'n' for this calculation. But 'n' is updating in the same cycle.
                    // This is tricky in pure combinational logic if n changes. 
                    // However, we can calculate distance based on current n, or next_n.
                    // Let's use next_n logic to estimate distance.
                    reg [7:0] temp_n;
                    if (a > b) temp_n = a + 1; else temp_n = b + 1;
                    if (temp_n < n) temp_n = n; // Ensure n is monotonic or max
                    
                    reg [7:0] dist_ab;
                    if (b >= a)
                        dist_ab = b - a;
                    else
                        dist_ab = b - a + temp_n;
                        
                    // min_dist update: min(current, dist_ab)
                    // If min_dist is 0 (uninitialized), set to dist_ab
                    if (counts[a] == 8'd0) begin
                         next_min_dist[a] = dist_ab;
                    end else if (dist_ab < min_dist[a]) begin
                         next_min_dist[a] = dist_ab;
                    end else begin
                         next_min_dist[a] = min_dist[a];
                    end
                    
                    next_received_any_input = 1'b1;
                end
                
                // Transition condition: start signal goes low (input phase ends)
                // Or we can just wait for a "start" signal again, or a specific "finish_inputs" signal.
                // The prompt says: "When start is high, begin the calculation".
                // It implies 'start' acts as a trigger for the batch process. 
                // Usually, valid_input is high for M cycles. 
                // Let's assume we stay here until 'start' goes low, then we proceed.
                if (!start && received_any_input) begin
                    next_state = STATE_CALCULATE;
                    next_s_reg = 8'd0;
                    next_i_reg = 8'd0;
                    next_current_max_time = 16'd0;
                end
            end
            
            STATE_CALCULATE: begin
                // We iterate s from 0 to n-1
                // For each s, we iterate i from 0 to n-1
                // Then we output result for s.
                
                // Calculation logic for specific (s, i)
                // Update max time for current s
                if (time_i > current_max_time)
                    next_current_max_time = time_i;
                else
                    next_current_max_time = current_max_time;
                
                // Move to next i
                if (i_reg < n - 1) begin
                    next_i_reg = i_reg + 1;
                end else begin
                    // Finished iterating i for current s
                    // Output this result (move to output state)
                    next_result_reg = current_max_time; // Current max is the result for s
                    next_state = STATE_OUTPUT;
                    // Note: We don't increment s yet, we do it in OUTPUT or back in CALCULATE
                    // Let's do it in OUTPUT
                end
            end
            
            STATE_OUTPUT: begin
                // Result is already set in CALC transition
                // Now, check if we need to do more s
                if (s_reg < n - 1) begin
                    // Go back to calculate for next s
                    next_s_reg = s_reg + 1;
                    next_i_reg = 8'd0;
                    next_current_max_time = 16'd0;
                    next_state = STATE_CALCULATE;
                end else begin
                    // All s done. Return to IDLE or wait?
                    // Prompt implies continuous operation or one-shot.
                    // Let's go to IDLE to wait for next 'start' pulse.
                    if (!start) begin
                        next_state = STATE_IDLE;
                    end else begin
                        // Wait for start to go low to avoid re-triggering immediately?
                        // Actually, the prompt says "When start is high, begin calculation".
                        // If we stay in IDLE, it triggers. 
                        // If we are done, we must wait for start to reset or go low.
                        // Let's just go to IDLE. 
                        next_state = STATE_IDLE;
                    end
                end
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end

endmodule