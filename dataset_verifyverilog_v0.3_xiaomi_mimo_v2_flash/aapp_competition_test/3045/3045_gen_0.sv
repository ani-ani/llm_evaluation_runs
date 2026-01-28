module mps_system (
    input clk,
    input rst_n,
    input start,
    input [1:0] num_beacons,
    // Beacon 0
    input signed [7:0] beacon0_x,
    input signed [7:0] beacon0_y,
    input [13:0] beacon0_d,
    // Beacon 1
    input signed [7:0] beacon1_x,
    input signed [7:0] beacon1_y,
    input [13:0] beacon1_d,
    // Beacon 2
    input signed [7:0] beacon2_x,
    input signed [7:0] beacon2_y,
    input [13:0] beacon2_d,
    // Beacon 3
    input signed [7:0] beacon3_x,
    input signed [7:0] beacon3_y,
    input [13:0] beacon3_d,
    output reg [3:0] result_x,
    output reg [3:0] result_y,
    output reg done,
    output reg impossible,
    output reg uncertain
);

    // Grid parameters
    localparam [3:0] GRID_MIN = 4'd0;
    localparam [3:0] GRID_MAX = 4'd7;
    localparam [3:0] MAX_BEACONS = 4'd4;
    localparam [3:0] CLK_TIMEOUT = 4'd15;
    
    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK_BEACON = 3'd1;
    localparam [2:0] NEXT_CANDIDATE = 3'd2;
    localparam [2:0] CHECK_NEXT_BEACON = 3'd3;
    localparam [2:0] RECORD_SOLUTION = 3'd4;
    localparam [2:0] FINISHED = 3'd5;
    localparam [2:0] TIMEOUT = 3'd6;
    
    // Internal state
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] candidate_x;
    reg [3:0] candidate_y;
    reg [2:0] beacon_idx;
    reg [2:0] solution_count;
    reg [3:0] first_x;
    reg [3:0] first_y;
    reg [7:0] timeout_counter;
    
    // Beacon data storage (packed into wires for Icarus compatibility)
    wire signed [7:0] beacon_x [0:3];
    wire signed [7:0] beacon_y [0:3];
    wire [13:0] beacon_d [0:3];
    
    assign beacon_x[0] = beacon0_x;
    assign beacon_y[0] = beacon0_y;
    assign beacon_d[0] = beacon0_d;
    assign beacon_x[1] = beacon1_x;
    assign beacon_y[1] = beacon1_y;
    assign beacon_d[1] = beacon1_d;
    assign beacon_x[2] = beacon2_x;
    assign beacon_y[2] = beacon2_y;
    assign beacon_d[2] = beacon2_d;
    assign beacon_x[3] = beacon3_x;
    assign beacon_y[3] = beacon3_y;
    assign beacon_d[3] = beacon3_d;
    
    // Manhattan distance calculation for current candidate and beacon
    wire signed [8:0] dx;
    wire signed [8:0] dy;
    wire signed [8:0] abs_dx;
    wire signed [8:0] abs_dy;
    wire [13:0] calc_dist;
    wire match;
    
    // Calculations
    assign dx = $signed({1'b0, candidate_x}) - beacon_x[beacon_idx];
    assign dy = $signed({1'b0, candidate_y}) - beacon_y[beacon_idx];
    assign abs_dx = dx[8] ? -dx : dx;
    assign abs_dy = dy[8] ? -dy : dy;
    assign calc_dist = abs_dx + abs_dy;
    assign match = (calc_dist == beacon_d[beacon_idx]);
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_BEACON;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_BEACON: begin
                if (match) begin
                    if (beacon_idx + 1 < num_beacons) begin
                        next_state = CHECK_NEXT_BEACON;
                    end else begin
                        next_state = RECORD_SOLUTION;
                    end
                end else begin
                    next_state = NEXT_CANDIDATE;
                end
            end
            
            CHECK_NEXT_BEACON: begin
                next_state = CHECK_BEACON;
            end
            
            RECORD_SOLUTION: begin
                if (candidate_x == GRID_MAX && candidate_y == GRID_MAX) begin
                    next_state = FINISHED;
                end else begin
                    next_state = NEXT_CANDIDATE;
                end
            end
            
            NEXT_CANDIDATE: begin
                if (candidate_x == GRID_MAX && candidate_y == GRID_MAX) begin
                    next_state = FINISHED;
                end else begin
                    next_state = CHECK_BEACON;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            TIMEOUT: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_x <= 4'd0;
            result_y <= 4'd0;
            done <= 1'b0;
            impossible <= 1'b0;
            uncertain <= 1'b0;
            candidate_x <= GRID_MIN;
            candidate_y <= GRID_MIN;
            beacon_idx <= 3'd0;
            solution_count <= 3'd0;
            first_x <= 4'd0;
            first_y <= 4'd0;
            timeout_counter <= 8'd0;
        end else begin
            state <= next_state;
            
            case (next_state)
                IDLE: begin
                    done <= 1'b0;
                    impossible <= 1'b0;
                    uncertain <= 1'b0;
                    candidate_x <= GRID_MIN;
                    candidate_y <= GRID_MIN;
                    beacon_idx <= 3'd0;
                    solution_count <= 3'd0;
                    first_x <= 4'd0;
                    first_y <= 4'd0;
                    timeout_counter <= 8'd0;
                end
                
                CHECK_BEACON: begin
                    // Start checking current beacon for current candidate
                    // beacon_idx already set, no change needed
                end
                
                CHECK_NEXT_BEACON: begin
                    // Move to next beacon
                    beacon_idx <= beacon_idx + 1;
                end
                
                RECORD_SOLUTION: begin
                    // Record the solution
                    solution_count <= solution_count + 1;
                    if (solution_count == 3'd0) begin
                        first_x <= candidate_x;
                        first_y <= candidate_y;
                    end
                    beacon_idx <= 3'd0;
                end
                
                NEXT_CANDIDATE: begin
                    // Move to next candidate position
                    beacon_idx <= 3'd0;
                    if (candidate_x == GRID_MAX) begin
                        candidate_x <= GRID_MIN;
                        if (candidate_y == GRID_MAX) begin
                            // Will be handled by FINISHED state
                        end else begin
                            candidate_y <= candidate_y + 1;
                        end
                    end else begin
                        candidate_x <= candidate_x + 1;
                    end
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    if (solution_count == 3'd0) begin
                        impossible <= 1'b1;
                    end else if (solution_count > 3'd1) begin
                        uncertain <= 1'b1;
                    end else begin
                        result_x <= first_x;
                        result_y <= first_y;
                    end
                end
                
                TIMEOUT: begin
                    done <= 1'b1;
                    impossible <= 1'b1;
                end
                
                default: begin
                    // Keep all values
                end
            endcase
            
            // Timeout counter (increment when searching)
            if (state != IDLE && state != FINISHED && state != TIMEOUT) begin
                if (timeout_counter < 8'd255) begin
                    timeout_counter <= timeout_counter + 1;
                end
            end
        end
    end
    
endmodule