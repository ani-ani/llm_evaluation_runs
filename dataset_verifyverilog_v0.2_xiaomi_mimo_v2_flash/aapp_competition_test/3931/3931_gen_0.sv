module travel_expense_calculator(
    input clk,
    input rst_n,
    input start,
    input [7:0] num_trips,
    input [7:0] max_cards,
    input [7:0] reg_cost,
    input [7:0] trans_cost,
    input [7:0] card_cost,
    input [7:0] trip_start_char,
    input [7:0] trip_end_char,
    input trip_valid,
    input trip_done,
    output reg [15:0] result,
    output reg done,
    output reg trip_ready
);

    // State Encoding
    localparam IDLE = 5'b00001;
    localparam RECEIVE_TRIPS = 5'b00010;
    localparam WAIT_FOR_DONE = 5'b00100;
    localparam CALCULATE_BENEFIT = 5'b01000;
    localparam APPLY_CARDS = 5'b10000;

    // Registers for State Machine
    reg [4:0] current_state;
    reg [4:0] next_state;

    // Internal Registers
    reg [15:0] total_cost;
    reg [7:0] last_stop;
    reg [7:0] trip_counter;
    reg [3:0] route_count; // Tracks number of unique routes identified
    
    // Route Storage: Max 16 unique routes
    // We use parallel arrays to store route info: start_char, end_char, accumulated_cost
    // To simplify address mapping, we maintain a small content-addressable memory (CAM) structure
    // or simply search linearly on insert (since N <= 16, latency is acceptable)
    reg [7:0] route_start [0:15];
    reg [7:0] route_end [0:15];
    reg [15:0] route_cost_acc [0:15]; // Accumulator per route

    // This module will inserted trip costs [0: a new route is found. If not, we update route_cost_acc with new route count and insert the trip.

    // Update Route Cost
        // New route identified?  // Check if route exists
        reg [4:0] route_id_match;
        reg [15:0] route_id;
        // If match, add to cost to existing route
        if (route_id_match != 0) begin
            route_cost_acc[route_id_match] <= route_cost_acc[route_id_match] + calculated_cost;
            end else begin
                // New route: Add to list
                if (route_count < 16) begin
                    route_start[route_count] <= r_start;
                    route_end[route_count] <= r_end;
                    route_cost_acc[route_count] <= calculated_cost;
                    route_count <= route_count + 1;
                end
            end
            
            total_cost <= total_cost + calculated_cost;
            last_stop <= trip_end_char;
            trip_counter <= trip_counter - 1;
            
            if (trip_counter == 1) begin
                // Last trip received
                next_state <= WAIT_FOR_DONE;
            end
        end
    end

    // WAIT_FOR_DONE Logic
    // Just waits for trip_done signal to ensure host knows we processed the stream
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset handled in main block
        end else if (current_state == WAIT_FOR_DONE) begin
            if (trip_done) begin
                next_state <= CALCULATE_BENEFIT;
            end
        end
    end

    // CALCULATE_BENEFIT Logic (State Transition & Sorting Prep)
    // We will do the sorting inside APPLY_CARDS using a bubble sort approach triggered by a counter
    // Here we just transition to APPLY_CARDS
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset
        end else if (current_state == CALCULATE_BENEFIT) begin
            next_state <= APPLY_CARDS;
        end
    end

    // APPLY_CARDS Logic (Detailed Implementation)
    // We implement a bubble sort in place over route_cost_acc
    // Then we iterate to subtract card costs
    reg [3:0] sort_idx;      // Outer loop index for bubble sort
    reg [3:0] swap_idx;      // Inner loop index
    reg [15:0] temp_cost;
    reg [7:0] temp_start;
    reg [7:0] temp_end;
    reg sorting_done;
    reg [3:0] card_idx;      // Index to apply cards (iterate through sorted routes)
    reg [3:0] cards_applied;
    
    wire [15:0] benefit;
    assign benefit = (route_cost_acc[card_idx] > card_cost) ? (route_cost_acc[card_idx] - card_cost) : 0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            trip_ready <= 0;
            result <= 0;
            total_cost <= 0;
            trip_counter <= 0;
            route_count <= 0;
            last_stop <= 0;
            sort_idx <= 0;
            swap_idx <= 0;
            card_idx <= 0;
            cards_applied <= 0;
        end else begin
            current_state <= next_state;

            case (current_state)
                IDLE: begin
                    if (start) begin
                        total_cost <= 0;
                        last_stop <= 0;
                        trip_counter <= num_trips;
                        route_count <= 0;
                        done <= 0;
                    end
                    trip_ready <= start;
                end

                RECEIVE_TRIPS: begin
                    trip_ready <= 1; // Ready for input
                    if (trip_valid && trip_ready) begin
                        // Process trip (Logic handled in always_comb block for calculation)
                        // We just clear ready if we are done, but here we rely on state transition
                        if (trip_counter == 1) trip_ready <= 0;
                    end
                end

                WAIT_FOR_DONE: begin
                    trip_ready <= 0;
                end

                CALCULATE_BENEFIT: begin
                    // Reset sort counters
                    sort_idx <= route_count;
                    swap_idx <= 0;
                    sorting_done <= 0;
                    // Reset Card Application Counters
                    card_idx <= 0;
                    cards_applied <= 0;
                end

                APPLY_CARDS: begin
                    // Step 1: Bubble Sort (if not done)
                    if (!sorting_done) begin
                        // One pass of bubble sort per clock cycle
                        // Invert logic: perform swap logic on the array
                        // We use swap_idx to iterate 0 to sort_idx-2
                        if (swap_idx < sort_idx - 1) begin
                            if (route_cost_acc[swap_idx] < route_cost_acc[swap_idx + 1]) begin
                                // Swap costs
                                temp_cost <= route_cost_acc[swap_idx];
                                route_cost_acc[swap_idx] <= route_cost_acc[swap_idx + 1];
                                route_cost_acc[swap_idx + 1] <= temp_cost;
                                // Swap metadata to keep consistency (optional but good practice)
                                temp_start <= route_start[swap_idx];
                                route_start[swap_idx] <= route_start[swap_idx + 1];
                                route_start[swap_idx + 1] <= temp_start;
                                temp_end <= route_end[swap_idx];
                                route_end[swap_idx] <= route_end[swap_idx + 1];
                                route_end[swap_idx + 1] <= temp_end;
                            end
                            swap_idx <= swap_idx + 1;
                        end else begin
                            // One pass complete
                            swap_idx <= 0;
                            sort_idx <= sort_idx - 1;
                            if (sort_idx <= 2) sorting_done <= 1; // Small array, finish quickly
                        end
                    end else begin
                        // Step 2: Apply Cards
                        // We iterate through the sorted array (largest benefit first)
                        if (card_idx < route_count && cards_applied < max_cards) begin
                            // Check Benefit
                            // Note: We use wire 'benefit' which depends on route_cost_acc[card_idx]
                            // Since route_cost_acc is updated in sorting, it holds the accumulated cost.
                            // We want to apply card if Cost > CardCost.
                            // We need to be careful about combinational paths. Let's latch the decision.
                            // Actually, let's just check the register value directly.
                            if (route_cost_acc[card_idx] > card_cost) begin
                                total_cost <= total_cost - (route_cost_acc[card_idx] - card_cost);
                                cards_applied <= cards_applied + 1;
                            end
                            card_idx <= card_idx + 1;
                        end else begin
                            result <= total_cost;
                            done <= 1;
                            next_state <= IDLE; // Auto reset to idle or wait for start
                        end
                    end
                end
            endcase
        end
    end

endmodule
