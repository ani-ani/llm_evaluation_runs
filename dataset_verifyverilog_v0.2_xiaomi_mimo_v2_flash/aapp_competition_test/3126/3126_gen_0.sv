module frog_dance(
    input clk,
    input rst_n,
    input start,
    input [5:0] frog_positions [49:0],
    input [5:0] num_frogs,
    input [5:0] target_pos,
    output reg [15:0] total_jumps,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam PROCESS_FROGS = 3'b001;
    localparam CALCULATE_DISTANCE = 3'b010;
    localparam FIND_MIN_JUMPS = 3'b011;
    localparam UPDATE_SUM = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] current_state, next_state;
    
    // Registers for iteration and calculation
    reg [5:0] frog_idx;
    reg [6:0] distance; // Max distance 63, fits in 6 bits, but sum check needs 7 bits
    reg [6:0] k_counter; // Iteration variable for finding jumps
    reg [6:0] k_sum;     // Sum of 1..k
    reg [15:0] accumulated_jumps;
    
    // Temporary calculation registers
    reg signed [6:0] pos_diff;
    reg [6:0] abs_diff;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State and Output Logic (Moore style)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs and internal registers
            total_jumps <= 16'b0;
            done <= 1'b0;
            frog_idx <= 6'b0;
            distance <= 7'b0;
            k_counter <= 7'b0;
            k_sum <= 7'b0;
            accumulated_jumps <= 16'b0;
            pos_diff <= 7'sd0;
            abs_diff <= 7'b0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    accumulated_jumps <= 16'b0;
                    frog_idx <= 6'b0;
                    if (start) begin
                        next_state <= PROCESS_FROGS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESS_FROGS: begin
                    if (frog_idx < num_frogs && num_frogs > 0) begin
                        next_state <= CALCULATE_DISTANCE;
                    end else begin
                        // All frogs processed or no frogs
                        total_jumps <= accumulated_jumps;
                        next_state <= DONE;
                    end
                end

                CALCULATE_DISTANCE: begin
                    // Calculate absolute difference |frog_positions[frog_idx] - target_pos|
                    pos_diff <= $signed({1'b0, frog_positions[frog_idx]}) - $signed({1'b0, target_pos});
                    // Note: Actual abs logic handled in combinational block below, 
                    // or we can do it here strictly sequentially.
                    // To be strictly sequential per requirement of reg inputs:
                    if (frog_positions[frog_idx] > target_pos)
                        abs_diff <= frog_positions[frog_idx] - target_pos;
                    else
                        abs_diff <= target_pos - frog_positions[frog_idx];
                    
                    distance <= 0; // Clear for next step
                    k_counter <= 7'b1; // Start k at 1
                    k_sum <= 7'b0; // Clear sum
                    next_state <= FIND_MIN_JUMPS;
                end

                FIND_MIN_JUMPS: begin
                    // Logic: find min k such that sum(1..k) >= d and (sum - d) is even.
                    // We iterate k from 1 to 64.
                    // k_sum is updated: k_sum <= k_sum + k_counter (where k_counter is current k)
                    // Wait state for sum update logic (purely combinational in next block or here)
                    
                    if (k_counter > 64) begin
                        // Should not happen given constraints, fallback
                        next_state <= UPDATE_SUM;
                        distance <= abs_diff; // restore original dist for update
                    end else begin
                        // Check condition
                        // New potential sum = current k_sum + k_counter
                        // We need to know if this new sum meets criteria
                        // Since we are sequential, let's use the values computed in the previous cycle or combinational logic.
                        
                        // Let's define the check logic:
                        // Sum of 1..k is k*(k+1)/2. 
                        // Since k is small (<64), we can calculate k_sum incrementally.
                        // In this state, we assume k_sum currently holds sum(1..k-1) and k_counter holds k.
                        // Or simpler: calculate sum inside logic.
                        
                        // Let's implement the check using a separate combinational block signal or internal logic.
                        // For strict sequential block, we calculate next sum and check.
                        
                        if ((k_sum + k_counter >= abs_diff) && (((k_sum + k_counter) - abs_diff) % 2 == 0)) begin
                            // Found k
                            distance <= k_counter; // Store the result k in distance register for update step
                            next_state <= UPDATE_SUM;
                        end else begin
                            // Increment
                            k_sum <= k_sum + k_counter;
                            k_counter <= k_counter + 1'b1;
                            next_state <= FIND_MIN_JUMPS;
                        end
                    end
                end

                UPDATE_SUM: begin
                    // Accumulate the jumps found (stored in distance register)
                    accumulated_jumps <= accumulated_jumps + {9'b0, distance};
                    frog_idx <= frog_idx + 1'b1;
                    next_state <= PROCESS_FROGS;
                end

                DONE: begin
                    done <= 1'b1;
                    if (!start) begin
                        next_state <= IDLE;
                    end else begin
                        next_state <= DONE;
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule