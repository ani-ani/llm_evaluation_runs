module torpedo_dodger(
    input clk,
    input rst_n,
    input start,
    input [5:0] ship_x1 [0:7],
    input [5:0] ship_x2 [0:7],
    input [5:0] ship_y [0:7],
    input [3:0] num_ships,
    output reg [15:0] path_data,
    output reg done,
    output reg possible
);

    // Parameters
    parameter N = 16;
    parameter MIN_X = -16;
    parameter MAX_X = 16;
    parameter ADDR_W = 5; // 0..16 -> 17 entries, 5 bits enough (32 max)
    parameter RANGE_W = 6; // Signed -16 to 16 needs 6 bits

    // State definition
    typedef enum logic [2:0] {
        IDLE,
        BUILD_RANGES,
        CHECK_POSSIBLE,
        TRACE_PATH,
        COMPLETE
    } state_t;

    state_t current_state, next_state;

    // Range memory (L and R boundaries for each step)
    // Indices 0..N (N=16)
    reg signed [RANGE_W-1:0] range_L [0:N];
    reg signed [RANGE_W-1:0] range_R [0:N];
    
    // Intermediate computation registers
    reg signed [RANGE_W-1:0] temp_L, next_temp_L;
    reg signed [RANGE_W-1:0] temp_R, next_temp_R;
    
    // Counters and control
    reg [4:0] step_cnt;     // 0..16 for Build, 0..15 for Trace
    reg [2:0] ship_cnt;     // 0..7 for iterating ships
    reg [3:0] trace_step;   // 0..15 for traceback
    
    // Traceback registers
    reg signed [RANGE_W-1:0] current_x, next_current_x;
    reg [15:0] next_path_data;
    
    // Helper signals for ship check
    wire signed [RANGE_W-1:0] s_x1, s_x2;
    wire signed [RANGE_W-1:0] s_y;
    wire signed [RANGE_W-1:0] clip_L, clip_R;
    wire overlap;
    wire full_cover;
    wire left_covered;
    wire right_covered;

    // Assign helper signals for ship bounds (cast to signed)
    assign s_x1 = $signed(ship_x1[ship_cnt]);
    assign s_x2 = $signed(ship_x2[ship_cnt]);
    assign s_y  = $signed(ship_y[ship_cnt]);

    // Logic to detect overlap and type
    assign overlap = (temp_R >= s_x1) && (temp_L <= s_x2);
    assign full_cover = (temp_L <= s_x1) && (temp_R >= s_x2);
    assign left_covered = (temp_L < s_x1) && (temp_R >= s_x1);
    assign right_covered = (temp_R > s_x2) && (temp_L <= s_x2);

    // Logic for BUILD_RANGES state
    always @(*) begin
        // Default: keep current temp values
        next_temp_L = temp_L;
        next_temp_R = temp_R;

        if (step_cnt == 0) begin
            // Initial step (height 0)
            next_temp_L = 0;
            next_temp_R = 0;
        end else if (ship_cnt == 0) begin
            // First iteration of step_cnt: Expand from previous stored range
            next_temp_L = range_L[step_cnt] - 1;
            next_temp_R = range_R[step_cnt] + 1;
            
            // Clamp
            if (next_temp_L < MIN_X) next_temp_L = MIN_X;
            if (next_temp_R > MAX_X) next_temp_R = MAX_X;
        end else begin
            // Subsequent iterations: Apply ship clipping
            // Check if ship is at current height (step_cnt)
            // Logic: We are calculating range for height 'step_cnt'.
            // Ships at height 'step_cnt' affect this range.
            if (s_y == step_cnt) begin
                if (overlap) begin
                    // If split (covered in middle), we cannot represent the hole.
                    // We update L and R to clip edges if they are covered.
                    // This maintains the bounding box.
                    if (left_covered)
                        next_temp_L = s_x2 + 1;
                    if (right_covered)
                        next_temp_R = s_x1 - 1;
                    
                    // If fully covered (and not edge clipped above), force empty
                    if (full_cover && !left_covered && !right_covered) begin
                        next_temp_L = 1;
                        next_temp_R = 0; // L > R -> Empty
                    end
                end
            end
        end
    end

    // Logic for TRACE_PATH state
    // We need to check if a candidate x is valid at step 't'
    // Valid means: within range_L[t]..range_R[t] AND not blocked by ship at height t
    function automatic logic is_valid;
        input signed [RANGE_W-1:0] x;
        input integer t;
        integer i;
        logic blocked;
        logic in_range;
        begin
            // Check range
            in_range = (x >= range_L[t]) && (x <= range_R[t]);
            
            // Check ships at height t
            blocked = 0;
            for (i = 0; i < 8; i++) begin
                if (i < num_ships) begin
                    if ($signed(ship_y[i]) == t) begin
                        if (x >= $signed(ship_x1[i]) && x <= $signed(ship_x2[i])) begin
                            blocked = 1;
                        end
                    end
                end
            end
            
            is_valid = in_range && !blocked;
        end
    endfunction

    // State transition and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            possible <= 0;
            path_data <= 0;
            step_cnt <= 0;
            ship_cnt <= 0;
            trace_step <= 0;
            current_x <= 0;
            temp_L <= 0;
            temp_R <= 0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    possible <= 0;
                    if (start) begin
                        current_state <= BUILD_RANGES;
                        step_cnt <= 0;
                        ship_cnt <= 0;
                    end
                end

                BUILD_RANGES: begin
                    // Cycle 0: Initialize temp_L/R for step 0
                    // Cycles 1..: Process ships for current step, then store and move to next step
                    
                    // Update temp with next logic
                    temp_L <= next_temp_L;
                    temp_R <= next_temp_R;

                    // Logic to advance counters and store
                    if (ship_cnt < 7 && ship_cnt < num_ships) begin
                        ship_cnt <= ship_cnt + 1;
                    end else begin
                        // Done with ships for this step (or no ships)
                        // Store the result for this step
                        range_L[step_cnt] <= next_temp_L;
                        range_R[step_cnt] <= next_temp_R;
                        
                        // Move to next step
                        if (step_cnt < N) begin
                            step_cnt <= step_cnt + 1;
                            ship_cnt <= 0;
                            // next_temp_L/R will be computed in next cycle (base case for step_cnt+1)
                        end else begin
                            current_state <= CHECK_POSSIBLE;
                        end
                    end
                end

                CHECK_POSSIBLE: begin
                    // Check if the final range is valid
                    if (range_L[N] <= range_R[N]) begin
                        possible <= 1;
                        current_state <= TRACE_PATH;
                    end else begin
                        possible <= 0;
                        current_state <= COMPLETE;
                    end
                    trace_step <= 0;
                    current_x <= 0; // Start at x=0
                    path_data <= 0;
                end

                TRACE_PATH: begin
                    if (trace_step < N) begin
                        // We are at step 'trace_step', at x = current_x.
                        // We want to find x_next for step 'trace_step + 1'.
                        // Try order: Straight (x), Turn Left (x-1), Turn Right (x+1)
                        // We try to pick the first valid one.
                        
                        // Check Straight (0)
                        if (is_valid(current_x, trace_step + 1)) begin
                            next_current_x = current_x;
                            next_path_data = path_data; // bit is 0
                        end
                        // Check Turn Left (1) -> x - 1
                        else if (is_valid(current_x - 1, trace_step + 1)) begin
                            next_current_x = current_x - 1;
                            next_path_data = path_data | (1'b1 << trace_step);
                        end
                        // Check Turn Right (1) -> x + 1
                        else if (is_valid(current_x + 1, trace_step + 1)) begin
                            next_current_x = current_x + 1;
                            next_path_data = path_data | (1'b1 << trace_step);
                        end
                        // If none valid, we have a problem (should not happen if Possible was high)
                        else begin
                            next_current_x = current_x;
                            next_path_data = path_data;
                            // We could set possible = 0 here, but let's just continue or stop
                        end

                        current_x <= next_current_x;
                        path_data <= next_path_data;
                        trace_step <= trace_step + 1;
                    end else begin
                        current_state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    done <= 1;
                    if (!start) begin
                        current_state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
