module calorie_optimizer(
    input clk,
    input rst_n,
    input start,
    input [15:0] m,
    input [3:0] n,
    input [15:0] courses [0:9],
    output reg [31:0] result,
    output reg done
);

    // Precomputed capacities for 1-4 consecutive hours
    reg [15:0] cap_0; // m
    reg [15:0] cap_1; // m * 2/3
    reg [15:0] cap_2; // m * 4/9
    reg [15:0] cap_3; // m * 8/27
    
    // State encoding
    // hour_idx: 0-9 (current course being processed)
    // streak: 0-4 (consecutive eating hours)
    // skip_len: 0-2 (consecutive skips)
    // cap_idx: 0-3 (which capacity to use)
    
    // DP storage: current and next hour states
    // 5*3*4 = 60 states per hour
    reg [31:0] dp_current [0:59];
    reg [31:0] dp_next [0:59];
    
    // FSM states
    localparam IDLE = 3'b000;
    localparam PRECOMPUTE = 3'b001;
    localparam INIT = 3'b010;
    localparam PROCESS = 3'b011;
    localparam CALC_RESULT = 3'b100;
    localparam DONE_STATE = 3'b101;
    
    reg [2:0] state;
    reg [3:0] hour_idx; // 0 to n-1
    reg [2:0] state_idx; // 0 to 59
    reg [2:0] stride; // for iteration
    
    // Helper indices
    wire [2:0] streak;
    wire [1:0] skip_len;
    wire [1:0] cap_idx;
    
    assign streak = state_idx[4:2];      // 3 bits: 0-4
    assign skip_len = state_idx[1:0];    // 2 bits: 0-2, but we need to split
    // Actually, state_idx layout: {streak[2:0], skip_len[1:0], cap_idx[1:0]} - too many bits
    // Need: streak 0-4 (3 bits), skip_len 0-2 (2 bits), cap_idx 0-3 (2 bits) = 7 bits
    // 7 bits = 128 states, we need 60
    
    // New encoding:
    // For streak 0-4 (5 values) and skip_len 0-2 (3 values) = 15 combinations
    // For each, cap_idx 0-3 (4 values) = 60 states
    // index = (streak * 3 + skip_len) * 4 + cap_idx
    // OR: streak * 12 + skip_len * 4 + cap_idx
    
    // Extract from state_idx
    wire [2:0] state_streak;
    wire [1:0] state_skip;
    wire [1:0] state_cap;
    
    assign state_streak = state_idx[5:3];  // 3 bits: 0-4
    assign state_skip = state_idx[2:2];    // WRONG - need 2 bits
    
    // Actually, we need to restructure
    // Let's use sequential access
    
    // Current state values during processing
    reg [2:0] curr_streak;
    reg [1:0] curr_skip;
    reg [1:0] curr_cap;
    reg [31:0] curr_val;
    
    // Next state computation registers
    reg [31:0] new_val_eat;
    reg [31:0] new_val_skip;
    reg [2:0] next_streak_eat;
    reg [2:0] next_streak_skip;
    reg [1:0] next_skip_eat;
    reg [1:0] next_skip_skip;
    reg [1:0] next_cap_eat;
    reg [1:0] next_cap_skip;
    
    // Computed capacity for current state
    reg [15:0] current_capacity;
    
    // Counter for loop iterations
    reg [5:0] loop_counter;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            hour_idx <= 0;
            state_idx <= 0;
            loop_counter <= 0;
            // Reset DP array
            for (integer i = 0; i < 60; i = i + 1) begin
                dp_current[i] <= 0;
                dp_next[i] <= 0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        state <= PRECOMPUTE;
                        hour_idx <= 0;
                        state_idx <= 0;
                    end
                end
                
                PRECOMPUTE: begin
                    // Precompute capacities
                    cap_0 <= m;
                    cap_1 <= (m * 16'sd2) / 16'sd3;
                    cap_2 <= (m * 16'sd2 * 16'sd2) / (16'sd3 * 16'sd3);
                    cap_3 <= (m * 16'sd2 * 16'sd2 * 16'sd2) / (16'sd3 * 16'sd3 * 16'sd3);
                    state <= INIT;
                end
                
                INIT: begin
                    // Initialize dp_current for hour 0
                    // All states initialized to 0 except invalid ones
                    // State 0: streak=0, skip=0, cap=0 -> value = 0 (starting state)
                    for (integer i = 0; i < 60; i = i + 1) begin
                        dp_current[i] <= 32'hFFFFFFF; // Initialize to "infinite" (representing -infinity)
                    end
                    dp_current[0] <= 0; // Index 0: streak=0, skip=0, cap=0
                    hour_idx <= 0;
                    state <= PROCESS;
                end
                
                PROCESS: begin
                    // Process one hour at a time
                    // For each state in dp_current, compute transitions
                    
                    if (hour_idx < n) begin
                        // Get current state values
                        // Decode state_idx to streak, skip, cap
                        curr_streak <= state_idx[5:3];
                        curr_skip <= state_idx[2:1];
                        curr_cap <= {state_idx[0], 1'b0}; // Hacky 2-bit extraction
                        // Need better decoding
                        
                        // Manual decoding
                        if (state_idx < 12) begin
                            curr_streak <= 0;
                            curr_skip <= state_idx[2:1];
                            curr_cap <= {1'b0, state_idx[0]};
                        end else if (state_idx < 24) begin
                            curr_streak <= 1;
                            curr_skip <= (state_idx - 12)[2:1];
                            curr_cap <= {1'b0, (state_idx - 12)[0]};
                        end else if (state_idx < 36) begin
                            curr_streak <= 2;
                            curr_skip <= (state_idx - 24)[2:1];
                            curr_cap <= {1'b0, (state_idx - 24)[0]};
                        end else if (state_idx < 48) begin
                            curr_streak <= 3;
                            curr_skip <= (state_idx - 36)[2:1];
                            curr_cap <= {1'b0, (state_idx - 36)[0]};
                        end else begin
                            curr_streak <= 4;
                            curr_skip <= (state_idx - 48)[2:1];
                            curr_cap <= {1'b0, (state_idx - 48)[0]};
                        end
                        
                        curr_val <= dp_current[state_idx];
                        
                        // Wait one cycle for values to settle
                        state <= UPDATE_STATE;
                    end else begin
                        state <= CALC_RESULT;
                    end
                end
                
                UPDATE_STATE: begin
                    // Compute capacity based on state
                    case (curr_cap)
                        2'b00: current_capacity <= cap_0;
                        2'b01: current_capacity <= cap_1;
                        2'b10: current_capacity <= cap_2;
                        2'b11: current_capacity <= cap_3;
                    endcase
                    
                    // Skip transition
                    if (curr_skip < 2) begin
                        next_skip_skip <= curr_skip + 1;
                    end else begin
                        next_skip_skip <= 2;
                    end
                    next_streak_skip <= 0;
                    next_cap_skip <= (curr_skip == 2'b01) ? curr_cap : 2'b00;
                    new_val_skip <= curr_val; // No calories added
                    
                    // Eat transition - need to check course value
                    if (courses[hour_idx] <= current_capacity) begin
                        // Valid to eat
                        if (curr_streak < 4) begin
                            next_streak_eat <= curr_streak + 1;
                        end else begin
                            next_streak_eat <= 4;
                        end
                        next_skip_eat <= 0;
                        next_cap_eat <= (curr_streak < 4) ? curr_cap : curr_cap; // Cap stays or increments
                        // But cap should increment if streak increments
                        // Actually cap_idx represents which capacity level we're at
                        // For eating, if coming from streak 0 (skip or start), cap_idx should be 0
                        // If in streak, cap_idx stays same
                        // Need to adjust: if curr_streak == 0 and curr_skip == 0, use cap_idx
                        // If eating after skip, need to continue
                        
                        // Simplified: cap_idx tracks continuous eating
                        // After skip 1: keep cap_idx (continuing)
                        // After skip 2: reset to 0
                        if (curr_skip == 2'b00) begin
                            next_cap_eat <= curr_cap;
                        end else if (curr_skip == 2'b01) begin
                            next_cap_eat <= curr_cap; // Continue
                        end else begin // skip 2 or fresh start
                            next_cap_eat <= 2'b00;
                        end
                        
                        new_val_eat <= curr_val + courses[hour_idx];
                    end else begin
                        // Cannot eat this course (capacity exceeded)
                        // Treat as skip
                        new_val_eat <= 32'hFFFFFFF;
                    end
                    
                    // Write to dp_next
                    // Need to compute target indices
                    // Skip:
                    // idx = (0 * 12) + (next_skip_skip * 4) + next_cap_skip
                    // idx = next_skip_skip * 4 + next_cap_skip
                    
                    // Eat:
                    // idx = (next_streak_eat * 12) + (0 * 4) + next_cap_eat
                    // idx = next_streak_eat * 12 + next_cap_eat
                    
                    // Determine write indices
                    // Skip index
                    if (new_val_skip < dp_next[next_skip_skip * 4 + next_cap_skip]) begin
                        dp_next[next_skip_skip * 4 + next_cap_skip] <= new_val_skip;
                    end
                    
                    // Eat index (only if valid)
                    if (new_val_eat != 32'hFFFFFFF) begin
                        if (new_val_eat < dp_next[next_streak_eat * 12 + next_cap_eat]) begin
                            dp_next[next_streak_eat * 12 + next_cap_eat] <= new_val_eat;
                        end
                    end
                    
                    // Move to next state
                    state_idx <= state_idx + 1;
                    if (state_idx == 59) begin
                        // Finished all states for this hour
                        state_idx <= 0;
                        hour_idx <= hour_idx + 1;
                        // Copy dp_next to dp_current
                        for (integer i = 0; i < 60; i = i + 1) begin
                            dp_current[i] <= dp_next[i];
                            dp_next[i] <= 32'hFFFFFFF; // Reset for next hour
                        end
                        state <= PROCESS;
                    end else begin
                        state <= PROCESS;
                    end
                end
                
                CALC_RESULT: begin
                    // Find maximum in dp_current
                    result <= 32'hFFFFFFF; // Min value
                    for (integer i = 0; i < 60; i = i + 1) begin
                        if (dp_current[i] < result && dp_current[i] != 32'hFFFFFFF) begin
                            result <= dp_current[i];
                        end
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    done <= 1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule