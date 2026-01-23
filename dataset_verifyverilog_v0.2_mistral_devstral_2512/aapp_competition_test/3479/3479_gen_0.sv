module shuttle_optimizer (
    input clk,
    input rst_n,
    input start,
    input [4:0] n_in,
    input [2:0] k_in,
    input [15:0] t_in [0:15],
    output reg [31:0] min_time,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SORTING,
        SIMULATING_TRIPS,
        SIMULATING_RETURN,
        DONE
    } state_t;

    state_t state;

    // Internal registers
    reg [4:0] people_home;
    reg [2:0] cars_home;
    reg [2:0] cars_stadium;
    reg [31:0] current_time;
    reg [3:0] fastest_driver_idx;
    reg [3:0] next_driver_idx;
    reg [3:0] transport_count;
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg [3:0] sort_swap;
    reg [15:0] sorted_t [0:15];

    // Reset logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            people_home <= 0;
            cars_home <= 0;
            cars_stadium <= 0;
            current_time <= 0;
            fastest_driver_idx <= 0;
            next_driver_idx <= 0;
            transport_count <= 0;
            sort_i <= 0;
            sort_j <= 0;
            sort_swap <= 0;
            min_time <= 0;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= SORTING;
                        people_home <= n_in;
                        cars_home <= k_in;
                        cars_stadium <= 0;
                        current_time <= 0;
                        fastest_driver_idx <= 0;
                        next_driver_idx <= 0;
                        transport_count <= 0;
                        sort_i <= 0;
                        sort_j <= 0;
                        sort_swap <= 0;
                        done <= 0;
                        // Initialize sorted array
                        for (int i = 0; i < 16; i++) begin
                            sorted_t[i] <= t_in[i];
                        end
                    end
                end
                SORTING: begin
                    // Bubble sort implementation
                    if (sort_i < 15) begin
                        if (sort_j < 15 - sort_i) begin
                            if (sorted_t[sort_j] > sorted_t[sort_j + 1]) begin
                                sort_swap <= sorted_t[sort_j];
                                sorted_t[sort_j] <= sorted_t[sort_j + 1];
                                sorted_t[sort_j + 1] <= sort_swap;
                            end
                            sort_j <= sort_j + 1;
                        end else begin
                            sort_j <= 0;
                            sort_i <= sort_i + 1;
                        end
                    end else begin
                        state <= SIMULATING_TRIPS;
                        next_driver_idx <= 0;
                    end
                end
                SIMULATING_TRIPS: begin
                    // Trip to stadium
                    if (people_home > 0 && cars_home > 0) begin
                        // Find fastest available driver
                        next_driver_idx <= next_driver_idx + 1;
                        if (next_driver_idx >= people_home) begin
                            next_driver_idx <= 0;
                        end
                        // Calculate passengers
                        reg [3:0] passengers = (people_home < 5) ? people_home : 5;
                        // Update time
                        current_time <= current_time + sorted_t[next_driver_idx];
                        // Update people and cars
                        people_home <= people_home - passengers;
                        cars_home <= cars_home - 1;
                        cars_stadium <= cars_stadium + 1;
                        // Track fastest driver among transported
                        if (fastest_driver_idx < passengers) begin
                            fastest_driver_idx <= passengers - 1;
                        end
                        transport_count <= transport_count + 1;
                        state <= SIMULATING_RETURN;
                    end else if (people_home == 0) begin
                        state <= DONE;
                        min_time <= current_time;
                        done <= 1;
                    end
                end
                SIMULATING_RETURN: begin
                    // Return trip
                    if (cars_stadium > 0 && people_home > 0) begin
                        // Use fastest driver at stadium
                        current_time <= current_time + sorted_t[fastest_driver_idx];
                        cars_stadium <= cars_stadium - 1;
                        cars_home <= cars_home + 1;
                        state <= SIMULATING_TRIPS;
                    end else if (people_home == 0) begin
                        state <= DONE;
                        min_time <= current_time;
                        done <= 1;
                    end else begin
                        state <= SIMULATING_TRIPS;
                    end
                end
                DONE: begin
                    // Stay in DONE state until reset
                end
            endcase
        end
    end

endmodule