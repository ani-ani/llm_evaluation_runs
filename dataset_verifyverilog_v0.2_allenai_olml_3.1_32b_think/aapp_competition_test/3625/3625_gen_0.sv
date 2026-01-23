module max_harvest (
    input clk,
    input rst_n,
    input start,
    // Species data interface: 10 species max, each with 4 params: Y, I, S, B
    // We pass these as 10 parallel inputs or load via a side interface. To keep it simple for the benchmark, we assume the data is loaded into a blockram-like interface.
    // However, for a pure module, we define inputs for the parameters of one species at a time. Actually, a standard way is to process a stream of species.
    // Let's define a control interface.
    input [31:0] param_y, // Years of increase
    input [31:0] param_i, // Increase amount
    input [31:0] param_s, // Start population
    input [31:0] param_b, // Planting year
    input [3:0] num_species, // Number of valid species (1 to 10)
    input species_valid, // Indicates valid species data
    output reg species_ready, // Ready to accept next species
    output reg [63:0] result_max_trees, // The maximum trees found
    output reg done // High when calculation complete
);

    // Constants
    parameter MAX_SPECIES = 10;
    parameter MAX_EVENTS = 40; // Increased to accommodate 4 events per species

    // State Machine States
    localparam IDLE = 3'b000;
    localparam LOAD_SPECIES = 3'b001;
    localparam GENERATE_EVENTS = 3'b010;
    localparam SORT_EVENTS = 3'b011;
    localparam SWEEP = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;

    // Internal registers
    reg [3:0] species_cnt; // Counter for species loading
    reg [3:0] event_idx;   // Counter for event generation
    reg [3:0] total_events; // Total events generated

    // Storage for parameters of one species at a time (simplified to process sequentially)
    // Actually, to compute max sum, we need all species active at once.
    // So we must store all species data or all events.
    // Let's store generated events in a small SRAM-like array.
    reg [31:0] event_time [0:39]; // Max 40 events
    reg signed [31:0] event_delta [0:39]; // Change in trees at this time

    // Temporary storage for current species
    reg [31:0] curr_Y, curr_I, curr_S, curr_B;

    // Sweep variables
    reg signed [63:0] current_trees;
    reg [63:0] max_trees;
    reg [3:0] sweep_idx;

    // Sorting logic (Bubble Sort for small N)
    reg sorting;
    reg [3:0] sort_i, sort_j;
    reg [31:0] temp_time;
    reg signed [31:0] temp_delta;

    // Input register storage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            curr_Y <= 0;
            curr_I <= 0;
            curr_S <= 0;
            curr_B <= 0;
        end else if (state == LOAD_SPECIES && species_valid && species_ready) begin
            curr_Y <= param_y;
            curr_I <= param_i;
            curr_S <= param_s;
            curr_B <= param_b;
        end
    end

    // Main State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            species_ready <= 0;
            done <= 0;
            result_max_trees <= 0;
            species_cnt <= 0;
            total_events <= 0;
            sorting <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD_SPECIES;
                        species_ready <= 1;
                        species_cnt <= 0;
                        total_events <= 0;
                    end
                end

                LOAD_SPECIES: begin
                    if (species_valid && species_ready) begin
                        // Process current species
                        // We will generate events in next state
                        state <= GENERATE_EVENTS;
                        species_ready <= 0;
                        event_idx <= 0; // Reset for event generation
                    end else if (species_cnt >= num_species) begin
                        // Done loading all species, move to sorting
                        state <= SORT_EVENTS;
                        sorting <= 1;
                        sort_i <= 0;
                        sort_j <= 0;
                        species_ready <= 0;
                    end
                end

                GENERATE_EVENTS: begin
                    if (event_idx == 0) begin
                        // Add event for S at B
                        event_time[total_events] <= curr_B;
                        event_delta[total_events] <= curr_S;
                        total_events <= total_events + 1;
                        event_idx <= 1;
                    end else if (event_idx == 1) begin
                        // Event at B+1: +I
                        event_time[total_events] <= curr_B + 1;
                        event_delta[total_events] <= curr_I;
                        total_events <= total_events + 1;
                        event_idx <= 2;
                    end else if (event_idx == 2) begin
                        // Event at B+Y+1: -2I
                        event_time[total_events] <= curr_B + curr_Y + 1;
                        event_delta[total_events] <= - (curr_I + curr_I);
                        total_events <= total_events + 1;
                        event_idx <= 3;
                    end else if (event_idx == 3) begin
                        // Event at B+2Y+1: +I
                        event_time[total_events] <= curr_B + 2*curr_Y + 1;
                        event_delta[total_events] <= curr_I;
                        total_events <= total_events + 1;
                        event_idx <= 4;
                        // Move to next species
                        species_cnt <= species_cnt + 1;
                        state <= LOAD_SPECIES;
                        species_ready <= 1; // Request next species
                    end
                end

                SORT_EVENTS: begin
                    if (sorting) begin
                        if (sort_i < total_events - 1) begin
                            if (sort_j < total_events - 1 - sort_i) begin
                                if (event_time[sort_j] > event_time[sort_j+1]) begin
                                    // Swap time
                                    temp_time <= event_time[sort_j];
                                    event_time[sort_j] <= event_time[sort_j+1];
                                    event_time[sort_j+1] <= temp_time;
                                    // Swap delta
                                    temp_delta <= event_delta[sort_j];
                                    event_delta[sort_j] <= event_delta[sort_j+1];
                                    event_delta[sort_j+1] <= temp_delta;
                                end
                                sort_j <= sort_j + 1;
                            end else begin
                                sort_j <= 0;
                                sort_i <= sort_i + 1;
                            end
                        end else begin
                            sorting <= 0;
                            state <= SWEEP;
                            sweep_idx <= 0;
                            current_trees <= 0;
                            max_trees <= 0;
                        end
                    end
                end

                SWEEP: begin
                    if (sweep_idx < total_events) begin
                        // Update current trees with delta at this event time
                        current_trees <= current_trees + event_delta[sweep_idx];
                        // Handle equal times: update but don't check max yet if next time is same
                        if (sweep_idx < total_events - 1 && event_time[sweep_idx] == event_time[sweep_idx+1]) begin
                            // Just update, don't check max yet
                        end else begin
                            // Check max
                            if (current_trees > max_trees) begin
                                max_trees <= current_trees;
                            end
                        end
                        sweep_idx <= sweep_idx + 1;
                    end else begin
                        // Done sweeping
                        state <= FINISHED;
                        done <= 1;
                        result_max_trees <= max_trees;
                    end
                end

                FINISHED: begin
                    // Wait for reset or new start
                    if (!start) begin
                        // Optional: reset done when start goes low? 
                        // Usually done stays high until reset.
                    end
                end

            endcase
        end
    end
endmodule