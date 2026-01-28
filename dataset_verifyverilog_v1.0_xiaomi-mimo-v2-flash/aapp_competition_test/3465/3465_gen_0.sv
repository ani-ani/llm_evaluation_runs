module AbsurdistanRoads (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] edges_a,
    input wire [15:0] edges_b,
    output reg [63:0] result_city,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] TRAVEL = 3'd2;
    localparam [2:0] BACKTRACK = 3'd3;
    localparam [2:0] FOUND = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Stack entry: {road_idx[3:0], city_mask[15:0]}
    // 4 bits + 16 bits = 20 bits per entry
    localparam [3:0] MAX_ROADS = 4'd16;
    localparam [7:0] MAX_CYCLES = 8'd255;

    reg [2:0] state, next_state;
    reg [3:0] current_road;
    reg [15:0] city_mask;
    reg [15:0] used_cities;
    reg [3:0] stack_depth;
    reg [19:0] stack[0:15];  // 16 entries of 20 bits
    reg [7:0] cycle_count;
    reg [3:0] i;
    reg backtrack_flag;
    reg [3:0] road_idx_reg;
    reg [15:0] mask_reg;
    reg [3:0] temp_idx;
    reg [3:0] j;

    // Helper function to extract city from edges_a or edges_b
    reg [3:0] city_a, city_b;
    always @(*) begin
        // Convert from 1-indexed to 0-indexed
        case (current_road)
            4'd0: begin city_a = edges_a[3:0] - 4'd1; city_b = edges_b[3:0] - 4'd1; end
            4'd1: begin city_a = edges_a[7:4] - 4'd1; city_b = edges_b[7:4] - 4'd1; end
            4'd2: begin city_a = edges_a[11:8] - 4'd1; city_b = edges_b[11:8] - 4'd1; end
            4'd3: begin city_a = edges_a[15:12] - 4'd1; city_b = edges_b[15:12] - 4'd1; end
            default: begin city_a = 4'd0; city_b = 4'd0; end
        endcase
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_city <= 64'd0;
            current_road <= 4'd0;
            city_mask <= 16'd0;
            used_cities <= 16'd0;
            stack_depth <= 4'd0;
            cycle_count <= 8'd0;
            for (j = 0; j < 16; j = j + 1) begin
                stack[j] <= 20'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= INIT;
                        cycle_count <= 8'd0;
                    end
                end

                INIT: begin
                    current_road <= 4'd0;
                    city_mask <= 16'd0;
                    used_cities <= 16'd0;
                    stack_depth <= 4'd0;
                    // Initialize result_city to 0
                    for (i = 0; i < 16; i = i + 1) begin
                        result_city[i*4 +: 4] <= 4'd0;
                    end
                    state <= TRAVEL;
                end

                TRAVEL: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (current_road < n) begin
                        // Try assigning to city_a
                        if (city_a < n && !used_cities[city_a]) begin
                            // Push to stack
                            stack[stack_depth] <= {current_road, used_cities};
                            stack_depth <= stack_depth + 4'd1;
                            // Assign and move forward
                            used_cities[city_a] <= 1'b1;
                            result_city[current_road*4 +: 4] <= city_a;
                            current_road <= current_road + 4'd1;
                            state <= TRAVEL;
                        end else if (city_b < n && !used_cities[city_b]) begin
                            // Try city_b
                            stack[stack_depth] <= {current_road, used_cities};
                            stack_depth <= stack_depth + 4'd1;
                            used_cities[city_b] <= 1'b1;
                            result_city[current_road*4 +: 4] <= city_b;
                            current_road <= current_road + 4'd1;
                            state <= TRAVEL;
                        end else begin
                            // Both cities taken, backtrack
                            state <= BACKTRACK;
                        end
                    end else begin
                        // All roads processed, solution found
                        state <= FOUND;
                    end
                end

                BACKTRACK: begin
                    if (stack_depth > 4'd0) begin
                        // Pop from stack
                        stack_depth <= stack_depth - 4'd1;
                        {road_idx_reg, used_cities} <= stack[stack_depth - 4'd1];
                        current_road <= road_idx_reg;
                        // Try next option
                        // We need to extract the cities for this road again
                        state <= BACKTRACK_NEXT;
                    end else begin
                        // No solution (shouldn't happen)
                        state <= DONE_STATE;
                    end
                end

                BACKTRACK_NEXT: begin
                    // Get cities for current road
                    case (current_road)
                        4'd0: begin city_a = edges_a[3:0] - 4'd1; city_b = edges_b[3:0] - 4'd1; end
                        4'd1: begin city_a = edges_a[7:4] - 4'd1; city_b = edges_b[7:4] - 4'd1; end
                        4'd2: begin city_a = edges_a[11:8] - 4'd1; city_b = edges_b[11:8] - 4'd1; end
                        4'd3: begin city_a = edges_a[15:12] - 4'd1; city_b = edges_b[15:12] - 4'd1; end
                        default: begin city_a = 4'd0; city_b = 4'd0; end
                    endcase
                    
                    // If we were on city_a, try city_b
                    if (used_cities[city_a] && !used_cities[city_b] && city_b < n) begin
                        used_cities[city_b] <= 1'b1;
                        result_city[current_road*4 +: 4] <= city_b;
                        current_road <= current_road + 4'd1;
                        state <= TRAVEL;
                    end else begin
                        // Both tried, need to backtrack further
                        state <= BACKTRACK;
                    end
                end

                FOUND: begin
                    done <= 1'b1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule