module road_assignment (
    input clk,
    input rst_n,
    input start,
    input [3:0] city_a [0:7],
    input [3:0] city_b [0:7],
    output reg [3:0] out_city,
    output reg [3:0] out_road_end,
    output reg out_valid,
    output reg out_done
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        SEARCH,
        DONE
    } state_t;

    state_t state, next_state;

    // Internal registers
    reg [3:0] current_city;
    reg [2:0] current_road;
    reg [7:0] assigned_roads;
    reg [3:0] found_city;
    reg [3:0] found_road_end;
    reg found_valid;

    // State transition logic
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_city <= 4'd0;
            current_road <= 3'd0;
            assigned_roads <= 8'b0;
            found_city <= 4'd0;
            found_road_end <= 4'd0;
            found_valid <= 1'b0;
            out_city <= 4'd0;
            out_road_end <= 4'd0;
            out_valid <= 1'b0;
            out_done <= 1'b0;
        end else begin
            state <= next_state;
            
            // Update current_road and current_city based on state transitions
            case (state)
                IDLE: begin
                    if (start) begin
                        current_city <= 4'd1;
                        current_road <= 3'd0;
                        assigned_roads <= 8'b0;
                    end
                end
                SEARCH: begin
                    if (found_valid) begin
                        current_city <= current_city + 1'b1;
                        current_road <= 3'd0;
                    end else begin
                        current_road <= current_road + 1'b1;
                    end
                end
                DONE: begin
                    // Stay in DONE until reset
                end
            endcase
            
            // Output registers
            out_city <= found_city;
            out_road_end <= found_road_end;
            out_valid <= found_valid;
            out_done <= (state == DONE) ? 1'b1 : 1'b0;
        end
    end

    // Next state logic
    always_comb begin
        next_state = state;
        found_valid = 1'b0;
        found_city = 4'd0;
        found_road_end = 4'd0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                end
            end
            SEARCH: begin
                // Check if current_road is valid for current_city
                if (!assigned_roads[current_road] && 
                    (city_a[current_road] == current_city || city_b[current_road] == current_city)) begin
                    // Found a valid road
                    found_valid = 1'b1;
                    found_city = current_city;
                    found_road_end = (city_a[current_road] == current_city) ? city_b[current_road] : city_a[current_road];
                    
                    // Mark road as assigned
                    assigned_roads[current_road] = 1'b1;
                    
                    // Move to next city or DONE
                    if (current_city == 4'd8) begin
                        next_state = DONE;
                    end
                end else if (current_road == 3'd7) begin
                    // No valid road found for current city (should not happen per problem statement)
                    if (current_city == 4'd8) begin
                        next_state = DONE;
                    end
                end
            end
            DONE: begin
                // Stay in DONE
            end
        endcase
    end

endmodule