module manhattan_positioning (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [23:0] beacon_x,
    input wire [23:0] beacon_y,
    input wire [23:0] beacon_d,
    input wire beacon_valid,
    output reg [23:0] result_x,
    output reg [23:0] result_y,
    output reg [1:0] status,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] LOAD          = 3'd1;
    localparam [2:0] LOAD_COMPLETE = 3'd2;
    localparam [2:0] SEARCH_Y      = 3'd3;
    localparam [2:0] CHECK_X       = 3'd4;
    localparam [2:0] UPDATE_RESULT = 3'd5;
    localparam [2:0] FINISH        = 3'd6;

    // Status definitions
    localparam [1:0] STAT_NONE     = 2'd0;
    localparam [1:0] STAT_VALID    = 2'd1;
    localparam [1:0] STAT_UNCERTAIN = 2'd2;
    localparam [1:0] STAT_ERROR    = 2'd3;

    // Constants
    localparam [3:0] MAX_BEACONS = 4'd8;
    localparam [12:0] MAX_Y_ITER = 13'd2048; // Max range for Y search
    localparam [7:0] MAX_X_ITER = 8'd128;    // Max steps for X check
    localparam [23:0] COORD_MIN = 24'h000000;
    localparam [23:0] COORD_MAX = 24'hFFFFFF;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] state_reg;
    
    // Beacon storage registers (unpacked arrays for Icarus compatibility)
    reg [23:0] bx [0:7];
    reg [23:0] by [0:7];
    reg [23:0] bd [0:7];
    reg [3:0] beacon_count;
    reg [3:0] beacon_idx;
    
    // Search registers
    reg [23:0] y_candidate;
    reg [23:0] y_start;
    reg [23:0] y_end;
    reg [12:0] y_iteration;
    
    // X range tracking
    reg [23:0] x_min_current;
    reg [23:0] x_max_current;
    reg [23:0] x_min_next;
    reg [23:0] x_max_next;
    reg [7:0] x_check_counter;
    
    // Solution tracking
    reg [1:0] solution_count; // 0, 1, or 2+ (2 means >1)
    reg [23:0] stored_x;
    reg [23:0] stored_y;
    reg [1:0] current_status;
    
    // Timing controls
    reg cycle_counter_reset;
    
    // Internal signals for computations
    wire signed [24:0] abs_diff_y; // signed for abs calculation
    wire signed [24:0] signed_y_cand;
    wire signed [24:0] signed_by_i;
    wire [23:0] diff_y;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Combinational next_state logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? LOAD : IDLE;
            LOAD: begin
                if (!beacon_valid && beacon_count > 0)
                    next_state = LOAD_COMPLETE;
                else if (beacon_count >= MAX_BEACONS && !beacon_valid)
                    next_state = LOAD_COMPLETE;
                else
                    next_state = LOAD;
            end
            LOAD_COMPLETE: begin
                if (beacon_count == 0)
                    next_state = FINISH;
                else
                    next_state = SEARCH_Y;
            end
            SEARCH_Y: begin
                if (y_iteration >= MAX_Y_ITER)
                    next_state = FINISH;
                else if (beacon_count == 0)
                    next_state = FINISH;
                else
                    next_state = CHECK_X;
            end
            CHECK_X: begin
                if (x_check_counter >= beacon_count)
                    next_state = UPDATE_RESULT;
                else
                    next_state = CHECK_X;
            end
            UPDATE_RESULT: begin
                if (y_candidate >= y_end)
                    next_state = FINISH;
                else
                    next_state = SEARCH_Y;
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Main FSM logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state_reg <= IDLE;
            beacon_count <= 4'd0;
            beacon_idx <= 4'd0;
            y_candidate <= 24'd0;
            y_start <= 24'd0;
            y_end <= 24'd0;
            y_iteration <= 13'd0;
            x_min_current <= 24'd0;
            x_max_current <= 24'd0;
            x_min_next <= 24'd0;
            x_max_next <= 24'd0;
            x_check_counter <= 8'd0;
            solution_count <= 2'd0;
            stored_x <= 24'd0;
            stored_y <= 24'd0;
            current_status <= STAT_NONE;
            result_x <= 24'd0;
            result_y <= 24'd0;
            status <= STAT_NONE;
            done <= 1'b0;
            
            // Reset beacon storage
            bx[0] <= 24'd0; bx[1] <= 24'd0; bx[2] <= 24'd0; bx[3] <= 24'd0;
            bx[4] <= 24'd0; bx[5] <= 24'd0; bx[6] <= 24'd0; bx[7] <= 24'd0;
            by[0] <= 24'd0; by[1] <= 24'd0; by[2] <= 24'd0; by[3] <= 24'd0;
            by[4] <= 24'd0; by[5] <= 24'd0; by[6] <= 24'd0; by[7] <= 24'd0;
            bd[0] <= 24'd0; bd[1] <= 24'd0; bd[2] <= 24'd0; bd[3] <= 24'd0;
            bd[4] <= 24'd0; bd[5] <= 24'd0; bd[6] <= 24'd0; bd[7] <= 24'd0;
        end else begin
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        beacon_count <= 4'd0;
                        beacon_idx <= 4'd0;
                        solution_count <= 2'd0;
                        current_status <= STAT_NONE;
                    end
                end
                
                LOAD: begin
                    if (beacon_valid && beacon_count < MAX_BEACONS) begin
                        // Store beacon data
                        bx[beacon_count] <= beacon_x;
                        by[beacon_count] <= beacon_y;
                        bd[beacon_count] <= beacon_d;
                        beacon_count <= beacon_count + 4'd1;
                    end
                end
                
                LOAD_COMPLETE: begin
                    // Initialize search range from first beacon
                    if (beacon_count > 0) begin
                        if (by[0] >= bd[0]) begin
                            y_start <= by[0] - bd[0];
                        end else begin
                            y_start <= 24'd0;
                        end
                        y_end <= by[0] + bd[0];
                        y_candidate <= (by[0] >= bd[0]) ? (by[0] - bd[0]) : 24'd0;
                        y_iteration <= 13'd0;
                    end
                end
                
                SEARCH_Y: begin
                    // Setup for X range check
                    beacon_idx <= 4'd0;
                    x_check_counter <= 8'd0;
                    // Initialize X range as wide as possible
                    x_min_current <= COORD_MIN;
                    x_max_current <= COORD_MAX;
                end
                
                CHECK_X: begin
                    if (beacon_idx < beacon_count) begin
                        // Calculate |Y - Y_i|
                        // Compute absolute difference manually
                        if (y_candidate >= by[beacon_idx]) begin
                            // y_cand >= y_i: diff = y_cand - y_i
                            // Check if diff > beacon_d[beacon_idx]
                            if ((y_candidate - by[beacon_idx]) > bd[beacon_idx]) begin
                                // Y difference too large, no valid X
                                x_min_next <= COORD_MAX + 24'd1; // Set to invalid range
                                x_max_next <= COORD_MIN;
                            end else begin
                                // Calculate X range bounds
                                // x_min = x_i - (d_i - (y_cand - y_i))
                                // x_max = x_i + (d_i - (y_cand - y_i))
                                if ((bd[beacon_idx] - (y_candidate - by[beacon_idx])) <= by[beacon_idx]) begin
                                     x_min_next <= by[beacon_idx] - (bd[beacon_idx] - (y_candidate - by[beacon_idx]));
                                end else begin
                                     x_min_next <= 24'd0;
                                end
                                x_max_next <= by[beacon_idx] + (bd[beacon_idx] - (y_candidate - by[beacon_idx]));
                            end
                        end else begin
                            // y_cand < y_i: diff = y_i - y_cand
                            if ((by[beacon_idx] - y_candidate) > bd[beacon_idx]) begin
                                x_min_next <= COORD_MAX + 24'd1;
                                x_max_next <= COORD_MIN;
                            end else begin
                                if ((bd[beacon_idx] - (by[beacon_idx] - y_candidate)) <= bx[beacon_idx]) begin
                                     x_min_next <= bx[beacon_idx] - (bd[beacon_idx] - (by[beacon_idx] - y_candidate));
                                end else begin
                                     x_min_next <= 24'd0;
                                end
                                x_max_next <= bx[beacon_idx] + (bd[beacon_idx] - (by[beacon_idx] - y_candidate));
                            end
                        end
                        
                        // Wait for next cycle to use computed values
                    end
                end
                
                UPDATE_RESULT: begin
                    // Move to next Y candidate
                    y_candidate <= y_candidate + 24'd1;
                    y_iteration <= y_iteration + 13'd1;
                    
                    // Check if we found any valid solutions in X
                    // x_min_current and x_max_current hold the intersection after processing all beacons
                    // Intersection logic is actually checked in the CHECK_X loop through updates
                end
                
                FINISH: begin
                    result_x <= stored_x;
                    result_y <= stored_y;
                    status <= current_status;
                    done <= 1'b1;
                end
            endcase
            
            // Interleaved logic for CHECK_X state updates
            if (state == CHECK_X) begin
                if (beacon_idx < beacon_count) begin
                    // Update intersection
                    if (x_min_next <= x_max_next) begin
                        // This beacon's range is valid
                        // Intersect with current range
                        if (x_min_current < x_min_next) begin
                            x_min_current <= x_min_next;
                        end
                        if (x_max_current > x_max_next) begin
                            x_max_current <= x_max_next;
                        end
                    end else begin
                        // This beacon provides no valid X range, kill the intersection
                        x_min_current <= COORD_MAX + 24'd1;
                        x_max_current <= COORD_MIN;
                    end
                    beacon_idx <= beacon_idx + 4'd1;
                end
            end
            
            if (state == UPDATE_RESULT) begin
                // After checking all beacons for this Y, check intersection
                // Intersection result is in x_min_current and x_max_current
                
                // Did we find a valid intersection?
                if (x_min_current <= x_max_current) begin
                    // Valid range exists
                    if (x_min_current == x_max_current) begin
                        // Single point solution
                        if (solution_count == 0) begin
                            // First solution found
                            solution_count <= 2'd1;
                            stored_x <= x_min_current;
                            stored_y <= y_candidate;
                            current_status <= STAT_VALID;
                        end else begin
                            // Second or more solution
                            solution_count <= 2'd2;
                            current_status <= STAT_UNCERTAIN;
                        end
                    end else begin
                        // Range of solutions (uncertain)
                        solution_count <= 2'd2; // Mark as multiple
                        current_status <= STAT_UNCERTAIN;
                    end
                end
            end
            
            if (state == FINISH) begin
                // Override status if no solutions found
                if (solution_count == 2'd0 && beacon_count > 0) begin
                    current_status <= STAT_NONE;
                end else if (beacon_count == 0) begin
                    current_status <= STAT_ERROR;
                end
            end
        end
    end

endmodule