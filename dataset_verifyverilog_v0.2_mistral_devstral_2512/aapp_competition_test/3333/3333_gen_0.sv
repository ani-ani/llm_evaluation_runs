module fox_hiding_optimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] roost_x, roost_y,
    input [2:0] num_spots,
    input [5:0][15:0] spots_x, spots_y,
    output reg [31:0] min_distance,
    output reg done
);

    parameter MAX_SPOTS = 6;
    parameter IDLE = 3'b000;
    parameter INIT = 3'b001;
    parameter PAIRING_ITERATOR = 3'b010;
    parameter TRIP_DISTANCE = 3'b011;
    parameter DISTANCE_CALC = 3'b100;
    parameter UPDATE_MIN = 3'b101;
    parameter DONE_STATE = 3'b110;

    reg [2:0] state = IDLE;
    reg [5:0] current_pairing = 0;
    reg [5:0] max_pairings = 0;
    reg [2:0] current_trip = 0;
    reg [2:0] max_trips = 0;
    reg [5:0] spot_mask = 0;
    reg [5:0] spot1, spot2;
    reg [31:0] current_distance = 0;
    reg [31:0] trip_distance = 0;
    reg [31:0] segment_distance = 0;
    reg [31:0] dx, dy;
    reg [31:0] dx_sq, dy_sq;
    reg [31:0] sum_sq;
    reg [31:0] sqrt_val;
    reg [31:0] sqrt_prev;
    reg [5:0] sqrt_iter;
    reg [5:0] pairing_index = 0;
    reg [5:0] spot_index = 0;
    reg [5:0] trip_index = 0;
    reg [5:0] segment_index = 0;
    reg [5:0] spot_count = 0;
    reg [5:0] spot_used [0:MAX_SPOTS-1];
    reg [5:0] pairing [0:MAX_SPOTS-1];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_distance <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                    end
                end
                INIT: begin
                    // Initialize variables
                    current_pairing <= 0;
                    max_pairings <= (num_spots % 2 == 0) ? (num_spots - 1) * (num_spots - 3) + 1 : (num_spots - 1) * (num_spots - 3) + 1;
                    max_trips <= (num_spots + 1) / 2;
                    spot_mask <= 0;
                    current_distance <= 0;
                    min_distance <= 0;
                    pairing_index <= 0;
                    spot_index <= 0;
                    trip_index <= 0;
                    segment_index <= 0;
                    spot_count <= 0;
                    for (int i = 0; i < MAX_SPOTS; i = i + 1) begin
                        spot_used[i] <= 0;
                        pairing[i] <= 0;
                    end
                    state <= PAIRING_ITERATOR;
                end
                PAIRING_ITERATOR: begin
                    // Generate next pairing
                    if (pairing_index < max_pairings) begin
                        // Generate pairing
                        for (int i = 0; i < MAX_SPOTS; i = i + 1) begin
                            spot_used[i] <= 0;
                        end
                        spot_count <= 0;
                        spot_index <= 0;
                        state <= TRIP_DISTANCE;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                TRIP_DISTANCE: begin
                    // Compute trip distances
                    if (trip_index < max_trips) begin
                        // Find next unused spot
                        if (spot_index < num_spots && !spot_used[spot_index]) begin
                            spot1 <= spot_index;
                            spot_used[spot_index] <= 1;
                            spot_count <= spot_count + 1;
                            if (spot_count == 1) begin
                                segment_index <= 0;
                                state <= DISTANCE_CALC;
                            end else begin
                                spot_index <= spot_index + 1;
                            end
                        end else begin
                            // All spots used, move to next trip
                            trip_index <= trip_index + 1;
                            spot_index <= 0;
                        end
                    end else begin
                        // All trips computed, update min distance
                        state <= UPDATE_MIN;
                    end
                end
                DISTANCE_CALC: begin
                    // Compute Euclidean distance
                    case (segment_index)
                        0: begin // roost to spot1
                            dx <= roost_x - spots_x[spot1];
                            dy <= roost_y - spots_y[spot1];
                        end
                        1: begin // spot1 to spot2
                            dx <= spots_x[spot1] - spots_x[spot2];
                            dy <= spots_y[spot1] - spots_y[spot2];
                        end
                        2: begin // spot2 to roost
                            dx <= spots_x[spot2] - roost_x;
                            dy <= spots_y[spot2] - roost_y;
                        end
                    endcase
                    dx_sq <= dx * dx;
                    dy_sq <= dy * dy;
                    sum_sq <= dx_sq + dy_sq;
                    sqrt_val <= sum_sq;
                    sqrt_prev <= 0;
                    sqrt_iter <= 0;
                    state <= DISTANCE_CALC + 1;
                end
                DISTANCE_CALC + 1: begin
                    // Newton-Raphson iteration
                    if (sqrt_iter < 16) begin
                        sqrt_prev <= sqrt_val;
                        sqrt_val <= (sqrt_val + sum_sq / sqrt_val) >> 1;
                        sqrt_iter <= sqrt_iter + 1;
                    end else begin
                        segment_distance <= sqrt_val;
                        current_distance <= current_distance + segment_distance;
                        segment_index <= segment_index + 1;
                        if (segment_index == 3) begin
                            segment_index <= 0;
                            state <= TRIP_DISTANCE;
                        end else begin
                            state <= DISTANCE_CALC;
                        end
                    end
                end
                UPDATE_MIN: begin
                    // Update minimum distance
                    if (min_distance == 0 || current_distance < min_distance) begin
                        min_distance <= current_distance;
                    end
                    current_distance <= 0;
                    pairing_index <= pairing_index + 1;
                    state <= PAIRING_ITERATOR;
                end
                DONE_STATE: begin
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule