module ManhattanPositioningSystem(
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
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Beacon storage (up to 8 beacons)
    reg [23:0] beacon_x_mem [0:7];
    reg [23:0] beacon_y_mem [0:7];
    reg [23:0] beacon_d_mem [0:7];
    reg [3:0] beacon_count;

    // Search parameters
    reg [23:0] y_min, y_max;
    reg [23:0] current_y;
    reg [23:0] x_min, x_max;
    reg [23:0] x_min_temp, x_max_temp;

    // Solution tracking
    reg [23:0] solution_x, solution_y;
    reg solution_found;
    reg multiple_solutions;

    // Counters and control
    reg [2:0] state, next_state;
    reg [11:0] y_counter;
    reg [6:0] x_counter;
    reg [6:0] beacon_counter;

    // Maximum iterations
    localparam [11:0] MAX_Y_ITER = 12'd2048;
    localparam [6:0] MAX_X_ITER = 7'd128;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            beacon_count <= 4'd0;
            y_counter <= 12'd0;
            x_counter <= 7'd0;
            beacon_counter <= 7'd0;
            solution_found <= 1'b0;
            multiple_solutions <= 1'b0;
            result_x <= 24'd0;
            result_y <= 24'd0;
            status <= 2'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end
            LOAD: begin
                if (beacon_valid && beacon_count < 4'd8) begin
                    // Stay in LOAD state
                end else if (beacon_count >= 4'd2) begin
                    next_state = COMPUTE;
                end else begin
                    next_state = IDLE;
                end
            end
            COMPUTE: begin
                if (y_counter >= MAX_Y_ITER) begin
                    next_state = FINISH;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Beacon loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            beacon_count <= 4'd0;
        end else if (state == LOAD && beacon_valid && beacon_count < 4'd8) begin
            beacon_x_mem[beacon_count] <= beacon_x;
            beacon_y_mem[beacon_count] <= beacon_y;
            beacon_d_mem[beacon_count] <= beacon_d;
            beacon_count <= beacon_count + 4'd1;
        end
    end

    // Compute state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            y_counter <= 12'd0;
            x_counter <= 7'd0;
            beacon_counter <= 7'd0;
            solution_found <= 1'b0;
            multiple_solutions <= 1'b0;
            y_min <= 24'd0;
            y_max <= 24'd0;
            current_y <= 24'd0;
        end else if (state == COMPUTE) begin
            // Initialize Y range from first beacon
            if (y_counter == 12'd0) begin
                y_min <= beacon_y_mem[0] - beacon_d_mem[0];
                y_max <= beacon_y_mem[0] + beacon_d_mem[0];
                current_y <= y_min;
            end

            // Process current Y value
            if (y_counter < MAX_Y_ITER) begin
                // Initialize X range from first beacon
                if (x_counter == 7'd0 && beacon_counter == 7'd0) begin
                    x_min <= beacon_x_mem[0] - (beacon_d_mem[0] - ((current_y > beacon_y_mem[0]) ? 
                                (current_y - beacon_y_mem[0]) : (beacon_y_mem[0] - current_y)));
                    x_max <= beacon_x_mem[0] + (beacon_d_mem[0] - ((current_y > beacon_y_mem[0]) ? 
                                (current_y - beacon_y_mem[0]) : (beacon_y_mem[0] - current_y)));
                end

                // Check all beacons for this Y
                if (beacon_counter < beacon_count) begin
                    // Calculate X range for current beacon
                    x_min_temp <= beacon_x_mem[beacon_counter] - (beacon_d_mem[beacon_counter] - 
                                ((current_y > beacon_y_mem[beacon_counter]) ? 
                                (current_y - beacon_y_mem[beacon_counter]) : 
                                (beacon_y_mem[beacon_counter] - current_y)));
                    x_max_temp <= beacon_x_mem[beacon_counter] + (beacon_d_mem[beacon_counter] - 
                                ((current_y > beacon_y_mem[beacon_counter]) ? 
                                (current_y - beacon_y_mem[beacon_counter]) : 
                                (beacon_y_mem[beacon_counter] - current_y)));

                    // Update X range intersection
                    if (x_min_temp > x_min) begin
                        x_min <= x_min_temp;
                    end
                    if (x_max_temp < x_max) begin
                        x_max <= x_max_temp;
                    end

                    beacon_counter <= beacon_counter + 7'd1;
                end else begin
                    // Check if we have a valid X range
                    if (x_min <= x_max) begin
                        // Check if it's a single point
                        if (x_min == x_max) begin
                            if (solution_found) begin
                                multiple_solutions <= 1'b1;
                            end else begin
                                solution_found <= 1'b1;
                                solution_x <= x_min;
                                solution_y <= current_y;
                            end
                        end else begin
                            multiple_solutions <= 1'b1;
                        end
                    end

                    // Move to next Y
                    beacon_counter <= 7'd0;
                    x_counter <= 7'd0;
                    y_counter <= y_counter + 12'd1;
                    current_y <= current_y + 24'd1;

                    // Check if we've exceeded Y range
                    if (current_y > y_max) begin
                        y_counter <= MAX_Y_ITER;
                    end
                end
            end
        end
    end

    // Finish state - set outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == FINISH) begin
            if (solution_found && !multiple_solutions) begin
                result_x <= solution_x;
                result_y <= solution_y;
                status <= 2'd1;  // Valid single solution
            end else if (solution_found && multiple_solutions) begin
                status <= 2'd2;  // Uncertain
            end else begin
                status <= 2'd0;  // No solution
            end
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule