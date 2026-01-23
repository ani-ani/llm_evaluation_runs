module road_assignment(
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

    // State encoding
    localparam IDLE = 2'b00;
    localparam SEARCH = 2'b01;
    localparam NEXT_CITY = 2'b10;
    localparam DONE = 2'b11;

    // Internal registers
    reg [1:0] state;
    reg [3:0] current_city; // 1 to 8
    reg [2:0] road_idx;     // 0 to 7
    reg [7:0] assigned;     // Bitmask for assigned roads

    // Next state logic variables
    wire [1:0] next_state;
    wire [3:0] next_current_city;
    wire [2:0] next_road_idx;
    wire [7:0] next_assigned;
    wire next_out_valid;
    wire next_out_done;
    wire [3:0] next_out_city;
    wire [3:0] next_out_road_end;

    // Combinational logic for next state and outputs
    assign next_out_valid = 1'b0;
    assign next_out_done = 1'b0;
    
    // Default keep values
    assign next_current_city = current_city;
    assign next_road_idx = road_idx;
    assign next_assigned = assigned;
    assign next_out_city = out_city;
    assign next_out_road_end = out_road_end;
    
    // Helper signals
    wire is_match = (city_a[road_idx] == current_city) || (city_b[road_idx] == current_city);
    wire is_assigned = assigned[road_idx];
    wire found_valid = is_match && !is_checked; // We need to check if we found it in this iteration logic
    
    // Since we are in combinational block for state transition, we handle the search loop logic here
    // However, to strictly follow the sequential logic description, we will implement the loop 
    // by transitioning states appropriately.
    
    // We need a combinational block to calculate next state based on current state
    // But to make it simpler and robust for synthesis, we will use a single always block for state transitions
    // and separate combinational logic for the 'SEARCH' state decision.
    
    // Let's refine the logic:
    // In SEARCH state, we check one road per cycle. 
    // If valid: output, mark assigned, increment city. If city > 8 -> DONE else NextCity.
    // If not valid: increment road. If road > 7 -> NextCity.
    
    // We need a wire to know if we are done checking all roads for current city
    wire search_done = (road_idx == 3'd7);
    wire city_done = (current_city > 4'd8);
    
    // Next State Logic Combinational Block
    always @(*) begin
        next_state = state;
        next_current_city = current_city;
        next_road_idx = road_idx;
        next_assigned = assigned;
        next_out_city = out_city;
        next_out_road_end = out_road_end;
        next_out_valid = 1'b0;
        next_out_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SEARCH;
                    next_current_city = 4'd1;
                    next_road_idx = 3'd0;
                    next_assigned = 8'b0;
                    // Reset outputs
                    next_out_city = 4'd0;
                    next_out_road_end = 4'd0;
                    next_out_done = 1'b0;
                end
            end

            SEARCH: begin
                // Check current road index
                if (!is_assigned && is_match) begin
                    // Found valid road
                    next_out_valid = 1'b1;
                    next_out_city = current_city;
                    // Determine the other city
                    if (city_a[road_idx] == current_city) begin
                        next_out_road_end = city_b[road_idx];
                    end else begin
                        next_out_road_end = city_a[road_idx];
                    end
                    next_assigned = assigned | (1'b1 << road_idx);
                    next_current_city = current_city + 1'b1;
                    
                    if (current_city == 4'd8) begin
                        next_state = DONE;
                        next_out_done = 1'b1;
                    end else begin
                        next_state = NEXT_CITY;
                    end
                end else begin
                    // Road not valid or assigned, check next
                    if (search_done) begin
                        // Reached end of road list, go to next city
                        // (In this problem set, a solution is guaranteed, so we assume we find one before hitting end)
                        // But for safety, we increment city anyway
                        next_current_city = current_city + 1'b1;
                        if (current_city == 4'd8) begin
                            next_state = DONE;
                            next_out_done = 1'b1;
                        end else begin
                            next_state = NEXT_CITY;
                        end
                    end else begin
                        // Stay in SEARCH, increment road index
                        next_road_idx = road_idx + 1'b1;
                    end
                end
            end

            NEXT_CITY: begin
                // Reset road index for the new city and continue search
                next_road_idx = 3'd0;
                next_state = SEARCH;
            end

            DONE: begin
                next_out_done = 1'b1;
                // Stay here until reset
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_city <= 4'd0;
            road_idx <= 3'd0;
            assigned <= 8'b0;
            out_city <= 4'd0;
            out_road_end <= 4'd0;
            out_valid <= 1'b0;
            out_done <= 1'b0;
        end else begin
            state <= next_state;
            current_city <= next_current_city;
            road_idx <= next_road_idx;
            assigned <= next_assigned;
            out_city <= next_out_city;
            out_road_end <= next_out_road_end;
            out_valid <= next_out_valid;
            out_done <= next_out_done;
        end
    end

endmodule
