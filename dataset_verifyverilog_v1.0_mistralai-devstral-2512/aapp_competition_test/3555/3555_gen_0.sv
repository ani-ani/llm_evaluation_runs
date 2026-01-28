module spot_leash(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [31:0] data_in,
    input wire data_valid,
    input wire data_type,
    input wire [5:0] data_count,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] LOAD  = 2'd1;
    localparam [1:0] CALC  = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;

    // Data buffers
    reg signed [15:0] toy_x [0:15];
    reg signed [15:0] toy_y [0:15];
    reg signed [15:0] tree_x [0:7];
    reg signed [15:0] tree_y [0:7];

    // Counters and pointers
    reg [3:0] toy_count;
    reg [2:0] tree_count;
    reg [3:0] toy_ptr;
    reg [2:0] tree_ptr;
    reg [5:0] data_counter;

    // Current position
    reg signed [15:0] curr_x;
    reg signed [15:0] curr_y;

    // Total length accumulator (Q16.16)
    reg signed [31:0] total_length;

    // Temporary calculation registers
    reg signed [15:0] dx, dy;
    reg signed [31:0] dist_sq, dist_approx;
    reg signed [31:0] scaled_dist;
    reg signed [31:0] cross_product;
    reg signed [31:0] threshold;

    // Obstacle detection flag
    reg obstacle_detected;

    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            toy_count <= 4'd0;
            tree_count <= 3'd0;
            toy_ptr <= 4'd0;
            tree_ptr <= 3'd0;
            data_counter <= 6'd0;
            curr_x <= 16'd0;
            curr_y <= 16'd0;
            total_length <= 32'd0;
            done <= 1'b0;
            busy <= 1'b0;
            cycle_count <= 10'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;

            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                        busy <= 1'b1;
                        data_counter <= 6'd0;
                        toy_count <= 4'd0;
                        tree_count <= 3'd0;
                        total_length <= 32'd0;
                        curr_x <= 16'd0;
                        curr_y <= 16'd0;
                        cycle_count <= 10'd0;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        if (data_type == 1'b0) begin
                            // Toy data
                            toy_x[toy_count] <= data_in[31:16];
                            toy_y[toy_count] <= data_in[15:0];
                            toy_count <= toy_count + 4'd1;
                        end else begin
                            // Tree data
                            tree_x[tree_count] <= data_in[31:16];
                            tree_y[tree_count] <= data_in[15:0];
                            tree_count <= tree_count + 3'd1;
                        end
                        data_counter <= data_counter + 6'd1;
                    end

                    if (data_counter == data_count) begin
                        next_state <= CALC;
                        toy_ptr <= 4'd0;
                    end
                end

                CALC: begin
                    if (toy_ptr < toy_count) begin
                        // Calculate vector to next toy
                        dx <= toy_x[toy_ptr] - curr_x;
                        dy <= toy_y[toy_ptr] - curr_y;

                        // Check for obstacles
                        obstacle_detected <= 1'b0;
                        tree_ptr <= 3'd0;
                        while (tree_ptr < tree_count && !obstacle_detected) begin
                            // Cross product check for line segment proximity
                            cross_product <= (tree_x[tree_ptr] - curr_x) * dy - (tree_y[tree_ptr] - curr_y) * dx;
                            threshold <= 16'd100; // Threshold for "close" detection
                            if (cross_product < threshold && cross_product > -threshold) begin
                                obstacle_detected <= 1'b1;
                            end
                            tree_ptr <= tree_ptr + 3'd1;
                        end

                        // Calculate distance (simplified approximation)
                        dist_sq <= dx * dx + dy * dy;
                        dist_approx <= (dist_sq >> 16) + ((dist_sq[15:0] != 0) ? 16'd1 : 16'd0);

                        // Scale to Q16.16
                        scaled_dist <= dist_approx << 16;

                        // Apply obstacle penalty if needed
                        if (obstacle_detected) begin
                            scaled_dist <= scaled_dist + (scaled_dist >> 1); // Multiply by 1.5
                        end

                        // Add to total length
                        total_length <= total_length + scaled_dist;

                        // Update current position
                        curr_x <= toy_x[toy_ptr];
                        curr_y <= toy_y[toy_ptr];

                        // Move to next toy
                        toy_ptr <= toy_ptr + 4'd1;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result <= total_length;
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES && state != IDLE) begin
            next_state <= IDLE;
            busy <= 1'b0;
            done <= 1'b0;
        end
    end

endmodule