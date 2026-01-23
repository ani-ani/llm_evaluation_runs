module travel_expense_calculator (
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

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        RECEIVE_TRIPS,
        WAIT_FOR_DONE,
        CALCULATE_BENEFIT,
        APPLY_CARDS,
        FINISHED
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [15:0] total_cost;
    reg [7:0] last_stop;
    reg [7:0] remaining_trips;
    reg [7:0] route_count;
    reg [7:0] route_ids [0:15];
    reg [15:0] route_costs [0:15];
    reg [15:0] benefits [0:15];
    reg [7:0] benefit_count;

    // Route ID calculation
    function [7:0] calculate_route_id(input [7:0] start, input [7:0] end);
        return (start < end) ? {start, end} : {end, start};
    endfunction

    // Bubble sort for benefits
    function void sort_benefits(ref reg [15:0] arr, input [7:0] n);
        reg [7:0] i, j;
        reg [15:0] temp;
        for (i = 0; i < n; i = i + 1) begin
            for (j = 0; j < n - i - 1; j = j + 1) begin
                if (arr[j] < arr[j + 1]) begin
                    temp = arr[j];
                    arr[j] = arr[j + 1];
                    arr[j + 1] = temp;
                end
            end
        end
    endfunction

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            total_cost <= 0;
            last_stop <= 0;
            remaining_trips <= 0;
            route_count <= 0;
            benefit_count <= 0;
            result <= 0;
            done <= 0;
            trip_ready <= 0;
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = RECEIVE_TRIPS;
                    total_cost = 0;
                    last_stop = 0;
                    remaining_trips = num_trips;
                    route_count = 0;
                    benefit_count = 0;
                    result = 0;
                    done = 0;
                    trip_ready = 1;
                end
            end
            RECEIVE_TRIPS: begin
                if (trip_valid && trip_ready) begin
                    if (remaining_trips == 0) begin
                        next_state = WAIT_FOR_DONE;
                    end
                end
            end
            WAIT_FOR_DONE: begin
                if (trip_done) begin
                    next_state = CALCULATE_BENEFIT;
                end
            end
            CALCULATE_BENEFIT: begin
                next_state = APPLY_CARDS;
            end
            APPLY_CARDS: begin
                next_state = FINISHED;
            end
            FINISHED: begin
                if (!start) begin
                    next_state = IDLE;
                end
            end
        endcase
    end

    // Trip processing logic
    always @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in state machine
        end else begin
            case (current_state)
                RECEIVE_TRIPS: begin
                    if (trip_valid && trip_ready) begin
                        reg [7:0] current_cost;
                        reg [7:0] route_id;
                        reg [7:0] i;
                        reg found;

                        // Determine trip cost
                        if (remaining_trips != num_trips && trip_start_char == last_stop) begin
                            current_cost = trans_cost;
                        end else begin
                            current_cost = reg_cost;
                        end

                        // Update total cost
                        total_cost = total_cost + current_cost;

                        // Calculate route ID
                        route_id = calculate_route_id(trip_start_char, trip_end_char);

                        // Check if route exists
                        found = 0;
                        for (i = 0; i < route_count; i = i + 1) begin
                            if (route_ids[i] == route_id) begin
                                found = 1;
                                route_costs[i] = route_costs[i] + current_cost;
                            end
                        end

                        // Add new route if not found
                        if (!found && route_count < 16) begin
                            route_ids[route_count] = route_id;
                            route_costs[route_count] = current_cost;
                            route_count = route_count + 1;
                        end

                        // Update last stop
                        last_stop = trip_end_char;
                        remaining_trips = remaining_trips - 1;

                        // Check if all trips processed
                        if (remaining_trips == 0) begin
                            trip_ready = 0;
                        end
                    end
                end
                CALCULATE_BENEFIT: begin
                    // Calculate benefits
                    benefit_count = 0;
                    for (i = 0; i < route_count; i = i + 1) begin
                        if (route_costs[i] > card_cost) begin
                            benefits[benefit_count] = route_costs[i] - card_cost;
                            benefit_count = benefit_count + 1;
                        end
                    end

                    // Sort benefits
                    sort_benefits(benefits, benefit_count);
                end
                APPLY_CARDS: begin
                    reg [7:0] cards_used;
                    reg [15:0] savings;

                    // Apply cards
                    cards_used = 0;
                    savings = 0;
                    for (i = 0; i < benefit_count && cards_used < max_cards; i = i + 1) begin
                        if (benefits[i] > 0) begin
                            savings = savings + benefits[i];
                            cards_used = cards_used + 1;
                        end
                    end

                    // Update total cost
                    total_cost = total_cost - savings;
                    result = total_cost;
                    done = 1;
                end
            endcase
        end
    end

    // Trip ready logic
    always @(*) begin
        case (current_state)
            IDLE: trip_ready = 0;
            RECEIVE_TRIPS: trip_ready = (remaining_trips > 0);
            default: trip_ready = 0;
        endcase
    end

endmodule