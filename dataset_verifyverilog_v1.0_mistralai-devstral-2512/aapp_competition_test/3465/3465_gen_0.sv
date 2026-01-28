module AbsurdistanRoads(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [3:0] edges_a [0:15],
    input wire [3:0] edges_b [0:15],
    output reg [3:0] result_city [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] START   = 3'd1;
    localparam [2:0] TRAVEL  = 3'd2;
    localparam [2:0] FOUND   = 3'd3;
    localparam [2:0] DONE    = 3'd4;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // Stack for iterative DFS
    reg [3:0] stack_road_idx [0:15];
    reg [15:0] stack_city_mask [0:15];
    reg [3:0] stack_ptr;

    // Current state variables
    reg [3:0] current_road;
    reg [15:0] city_mask;
    reg [3:0] solution_idx;

    // Temporary variables
    reg [3:0] city_a;
    reg [3:0] city_b;
    reg [3:0] temp_city;
    reg [15:0] temp_mask;
    reg try_b;
    reg valid;

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            stack_ptr <= 4'd0;
            current_road <= 4'd0;
            city_mask <= 16'd0;
            solution_idx <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result_city[i] <= 4'd0;
                stack_road_idx[i] <= 4'd0;
                stack_city_mask[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= START;
                    end
                end

                START: begin
                    // Initialize for new computation
                    stack_ptr <= 4'd0;
                    current_road <= 4'd0;
                    city_mask <= 16'd0;
                    solution_idx <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        result_city[i] <= 4'd0;
                    end
                    state <= TRAVEL;
                end

                TRAVEL: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've processed all roads
                    if (current_road == n) begin
                        state <= FOUND;
                    end else begin
                        // Get current road's cities
                        city_a <= edges_a[current_road];
                        city_b <= edges_b[current_road];

                        // Try assigning to city_a first
                        temp_city <= city_a;
                        temp_mask <= city_mask | (1 << temp_city);

                        // Check if city_a is available (not already assigned)
                        if ((city_mask & (1 << temp_city)) == 0) begin
                            // Push current state to stack
                            stack_road_idx[stack_ptr] <= current_road;
                            stack_city_mask[stack_ptr] <= city_mask;
                            stack_ptr <= stack_ptr + 4'd1;

                            // Update current state
                            current_road <= current_road + 4'd1;
                            city_mask <= temp_mask;
                            result_city[current_road] <= temp_city;
                        end else begin
                            // Try city_b
                            temp_city <= city_b;
                            temp_mask <= city_mask | (1 << temp_city);

                            if ((city_mask & (1 << temp_city)) == 0) begin
                                // Push current state to stack
                                stack_road_idx[stack_ptr] <= current_road;
                                stack_city_mask[stack_ptr] <= city_mask;
                                stack_ptr <= stack_ptr + 4'd1;

                                // Update current state
                                current_road <= current_road + 4'd1;
                                city_mask <= temp_mask;
                                result_city[current_road] <= temp_city;
                            end else begin
                                // Backtrack
                                if (stack_ptr > 4'd0) begin
                                    stack_ptr <= stack_ptr - 4'd1;
                                    current_road <= stack_road_idx[stack_ptr] + 4'd1;
                                    city_mask <= stack_city_mask[stack_ptr];

                                    // Try alternative assignment for this road
                                    city_a <= edges_a[current_road];
                                    city_b <= edges_b[current_road];

                                    // If we already tried city_a, try city_b
                                    if (result_city[current_road] == city_a) begin
                                        temp_city <= city_b;
                                        temp_mask <= city_mask | (1 << temp_city);

                                        if ((city_mask & (1 << temp_city)) == 0) begin
                                            // Update assignment
                                            result_city[current_road] <= temp_city;
                                            city_mask <= temp_mask;
                                            current_road <= current_road + 4'd1;
                                        end else begin
                                            // Need to backtrack further
                                            stack_ptr <= stack_ptr - 4'd1;
                                            current_road <= stack_road_idx[stack_ptr] + 4'd1;
                                            city_mask <= stack_city_mask[stack_ptr];
                                        end
                                    end else begin
                                        // Already tried both, backtrack further
                                        stack_ptr <= stack_ptr - 4'd1;
                                        current_road <= stack_road_idx[stack_ptr] + 4'd1;
                                        city_mask <= stack_city_mask[stack_ptr];
                                    end
                                end else begin
                                    // No solution found (shouldn't happen per problem statement)
                                    state <= IDLE;
                                end
                            end
                        end
                    end

                    // Safety check for cycle count
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                FOUND: begin
                    // Solution found, prepare to output
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule