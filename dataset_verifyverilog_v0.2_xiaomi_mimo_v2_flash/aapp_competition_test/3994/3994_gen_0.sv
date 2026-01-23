module lights_controller(
    input clk,
    input rst_n,
    input start,
    input [15:0] initial_states,
    input [4:0] a [15:0],
    input [4:0] b [15:0],
    output reg [4:0] max_lights,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CALCULATING = 2'b01;
    localparam DONE = 2'b10;

    // Internal Registers
    reg [1:0] state, next_state;
    reg [5:0] t_counter, next_t_counter;           // Time counter 0-63
    reg [3:0] light_idx, next_light_idx;           // Light index 0-15
    reg [4:0] current_count, next_current_count;    // Lights ON at current t
    reg [4:0] next_max_lights;                      // Max lights tracker
    reg [15:0] current_light_state, next_light_state; // Holds state of 16 lights
    reg [4:0] toggle_threshold;                     // Computed threshold for toggle
    reg is_toggle;                                  // Flag for toggle condition

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            t_counter <= 6'b0;
            light_idx <= 4'b0;
            current_count <= 5'b0;
            max_lights <= 5'b0;
            current_light_state <= 16'b0;
        end else begin
            state <= next_state;
            t_counter <= next_t_counter;
            light_idx <= next_light_idx;
            current_count <= next_current_count;
            max_lights <= next_max_lights;
            current_light_state <= next_light_state;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments to prevent latches
        next_state = state;
        next_t_counter = t_counter;
        next_light_idx = light_idx;
        next_current_count = current_count;
        next_max_lights = max_lights;
        next_light_state = current_light_state;
        done = 1'b0;
        
        // Combinational logic for specific light calculation
        is_toggle = 1'b0;
        toggle_threshold = 5'b0;
        
        if (state == CALCULATING) begin
            // Check if light 'light_idx' toggles at time 't_counter'
            // Toggle if t >= b[i] and (t - b[i]) % a[i] == 0
            
            if (t_counter >= b[light_idx]) begin
                toggle_threshold = t_counter - b[light_idx];
                // Since a[i] is max 31 and t-b[i] is max 63, we only need modulo logic.
                // However, division/modulo in hardware is complex. 
                // Since a[i] is 5-bit and range is small, we can check divisibility.
                // Note: The most efficient way here depends on constraints. 
                // Using the condition (t - b[i]) % a[i] == 0.
                // Since a[i] is variable, we can't unroll easily without a divider.
                // We will perform the check: 
                // If a[i] is 0, we treat it as no toggle (or handle safe). Assuming valid a[i] >= 1.
                // We will use a loop-unrolled equivalent or a simple comparison if needed, 
                // but since we are in a comb block, we can't use division operator freely for inference.
                // Let's assume a synthesizable modulo operation is allowed or we use a property:
                // (t - b[i]) % a[i] == 0 implies ((t - b[i]) / a[i]) * a[i] == (t - b[i]).
                // Since we are in a sequential logic step per cycle, let's compute the remainder logic:
                // Actually, doing full modulo in combinational logic for 16 lights in parallel might be heavy.
                // However, the prompt implies a standard sequential operation.
                // We will perform the check: 
                // For simulation/synthesis correctness with variable 'a', we rely on the standard operator.
                // But strictly, let's be explicit:
                // If we cannot assume a divider, we can't easily do this in one cycle for variable 'a'.
                // Wait, the instructions say "Sequential Verilog module... Latency 1024 cycles".
                // This means 1 cycle per (t, light) pair.
                // We do: if ((t_counter - b[light_idx]) % a[light_idx] == 0) is_toggle = 1;
                // This is a valid comb check. 
                
                // Check for division by zero safety
                if (a[light_idx] != 5'b0) begin
                    if ((toggle_threshold % a[light_idx]) == 0) begin
                        is_toggle = 1'b1;
                    end
                end
            end
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATING;
                    next_t_counter = 6'b0;
                    next_light_idx = 4'b0;
                    next_current_count = 5'b0;
                    next_max_lights = 5'b0;
                    next_light_state = initial_states;
                end else begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end

            CALCULATING: begin
                // Logic for one light processing at a time
                
                // 1. Determine if current light toggles
                if (is_toggle) begin
                    next_light_state[light_idx] = ~current_light_state[light_idx];
                end else begin
                    next_light_state[light_idx] = current_light_state[light_idx];
                end
                
                // 2. Update count if light is ON after potential toggle
                // Note: We update current_count cumulatively during the loop over lights
                if (next_light_state[light_idx]) begin
                    next_current_count = current_count + 1'b1;
                end else begin
                    next_current_count = current_count;
                end

                // 3. Update Max Lights (only check after all 16 lights are processed for this t)
                if (light_idx == 4'd15) begin
                    if (next_current_count > max_lights) begin
                        next_max_lights = next_current_count;
                    end
                end else begin
                    next_max_lights = max_lights;
                end

                // 4. Increment Counters
                if (light_idx == 4'd15) begin
                    // End of lights for this t
                    next_light_idx = 4'b0;
                    next_current_count = 5'b0; // Reset for next time step
                    
                    if (t_counter == 6'd63) begin
                        // End of all time steps
                        next_state = DONE;
                    end else begin
                        next_t_counter = t_counter + 1'b1;
                    end
                end else begin
                    // Next light
                    next_light_idx = light_idx + 1'b1;
                    next_t_counter = t_counter;
                    next_state = CALCULATING;
                end
            end

            DONE: begin
                done = 1'b1;
                if (!start) begin
                    // Wait for start to go low to return to IDLE (optional handshake)
                    next_state = DONE;
                end else begin
                    // If start is asserted again, restart or stay? 
                    // Standard behavior: hold done until reset or restart.
                    // Let's stay in DONE until rst or start goes low then high.
                    // To be simple, we stay in DONE.
                    next_state = DONE;
                end
                // If restart is desired on new start, we would check start rising edge.
                // But strictly IDLE waits for start. 
                // Let's allow restart if start is low then high.
                if (!start) begin
                     // Waiting for start low to reset logic... but strictly we stay in DONE.
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
