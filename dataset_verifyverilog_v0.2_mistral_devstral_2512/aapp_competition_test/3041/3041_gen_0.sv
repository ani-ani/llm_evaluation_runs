module ticket_optimizer #(
    parameter N = 8
)(
    input clk,
    input rst_n,
    input start,
    input [2:0] trip_zone,
    input [7:0] trip_time,
    input load_trip,
    input compute,
    output reg [15:0] min_cost,
    output reg done,
    output reg [2:0] debug_state
);

    // State definitions
    localparam [2:0] IDLE = 3'b000;
    localparam [2:0] LOAD_TRIP = 3'b001;
    localparam [2:0] COMPUTE = 3'b010;
    localparam [2:0] COMPLETE = 3'b011;

    // Trip storage (8 trips max)
    reg [2:0] trip_zones [0:N-1];
    reg [7:0] trip_times [0:N-1];
    reg [2:0] trip_count;

    // DP state tracking
    reg [2:0] last_ticket_A;
    reg [2:0] last_ticket_B;
    reg [7:0] last_ticket_start_time;
    reg [7:0] current_cost;

    // Internal state
    reg [2:0] state;
    reg [2:0] current_trip_index;

    // Initialize
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            trip_count <= 0;
            current_trip_index <= 0;
            min_cost <= 0;
            done <= 0;
            debug_state <= IDLE;
            last_ticket_A <= 0;
            last_ticket_B <= 0;
            last_ticket_start_time <= 0;
            current_cost <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_TRIP;
                        debug_state <= LOAD_TRIP;
                    end
                end
                LOAD_TRIP: begin
                    if (load_trip && trip_count < N) begin
                        trip_zones[trip_count] <= trip_zone;
                        trip_times[trip_count] <= trip_time;
                        trip_count <= trip_count + 1;
                        if (trip_count == N) begin
                            state <= COMPUTE;
                            debug_state <= COMPUTE;
                        end
                    end
                end
                COMPUTE: begin
                    if (compute) begin
                        // Process current trip
                        reg [2:0] current_zone = trip_zones[current_trip_index];
                        reg [7:0] current_time = trip_times[current_trip_index];
                        reg [7:0] time_diff = current_time - last_ticket_start_time;
                        reg [2:0] new_A, new_B;
                        reg [7:0] new_cost;
                        reg valid_ticket;

                        // Check if current ticket is valid
                        valid_ticket = (current_zone >= last_ticket_A && 
                                      current_zone <= last_ticket_B && 
                                      time_diff < 256);

                        // Option 1: Use existing ticket if valid
                        if (valid_ticket) begin
                            new_cost = current_cost;
                            new_A = last_ticket_A;
                            new_B = last_ticket_B;
                        end
                        // Option 2: Buy new ticket covering current zone
                        else begin
                            new_A = current_zone;
                            new_B = current_zone;
                            new_cost = current_cost + 2 + (new_B - new_A);
                        end

                        // Update state
                        last_ticket_A <= new_A;
                        last_ticket_B <= new_B;
                        last_ticket_start_time <= current_time;
                        current_cost <= new_cost;

                        // Move to next trip
                        current_trip_index <= current_trip_index + 1;
                        if (current_trip_index == N) begin
                            state <= COMPLETE;
                            debug_state <= COMPLETE;
                            min_cost <= current_cost;
                            done <= 1;
                        end
                    end
                end
                COMPLETE: begin
                    if (!start) begin
                        state <= IDLE;
                        debug_state <= IDLE;
                        done <= 0;
                        trip_count <= 0;
                        current_trip_index <= 0;
                    end
                end
            endcase
        end
    end

endmodule