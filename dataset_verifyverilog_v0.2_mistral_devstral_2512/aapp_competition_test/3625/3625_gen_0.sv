module max_harvest (
    input clk,
    input rst_n,
    input start,
    input [31:0] param_y,
    input [31:0] param_i,
    input [31:0] param_s,
    input [31:0] param_b,
    input [3:0] num_species,
    input species_valid,
    output reg species_ready,
    output reg [63:0] result_max_trees,
    output reg done
);

    parameter MAX_SPECIES = 10;
    parameter MAX_EVENTS = 30;

    localparam IDLE = 3'b000;
    localparam LOAD_SPECIES = 3'b001;
    localparam GENERATE_EVENTS = 3'b010;
    localparam SORT_EVENTS = 3'b011;
    localparam SWEEP = 3'b100;
    localparam FINISHED = 3'b101;

    reg [2:0] state;
    reg [3:0] species_cnt;
    reg [3:0] event_idx;
    reg [3:0] total_events;
    reg [31:0] event_time [0:29];
    reg signed [31:0] event_delta [0:29];
    reg [31:0] curr_Y, curr_I, curr_S, curr_B;
    reg signed [63:0] current_trees;
    reg signed [63:0] max_trees;
    reg [3:0] sweep_idx;
    reg sorting;
    reg [3:0] sort_i, sort_j;
    reg [31:0] temp_time;
    reg signed [31:0] temp_delta;

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
                        state <= GENERATE_EVENTS;
                        species_ready <= 0;
                        event_idx <= 0;
                    end else if (species_cnt >= num_species) begin
                        state <= SORT_EVENTS;
                        sorting <= 1;
                        sort_i <= 0;
                        sort_j <= 0;
                        species_ready <= 0;
                    end
                end

                GENERATE_EVENTS: begin
                    if (event_idx == 0) begin
                        event_time[total_events] <= curr_B + 1;
                        event_delta[total_events] <= curr_I;
                        total_events <= total_events + 1;
                        event_idx <= event_idx + 1;
                    end else if (event_idx == 1) begin
                        event_time[total_events] <= curr_B + curr_Y + 1;
                        event_delta[total_events] <= - (curr_I + curr_I);
                        total_events <= total_events + 1;
                        event_idx <= event_idx + 1;
                    end else if (event_idx == 2) begin
                        event_time[total_events] <= curr_B + 2*curr_Y + 1;
                        event_delta[total_events] <= curr_I;
                        total_events <= total_events + 1;
                        event_idx <= event_idx + 1;
                    end else begin
                        species_cnt <= species_cnt + 1;
                        state <= LOAD_SPECIES;
                        species_ready <= 1;
                    end
                end

                SORT_EVENTS: begin
                    if (sorting) begin
                        if (sort_i < total_events - 1) begin
                            if (sort_j < total_events - 1 - sort_i) begin
                                if (event_time[sort_j] > event_time[sort_j+1]) begin
                                    temp_time <= event_time[sort_j];
                                    event_time[sort_j] <= event_time[sort_j+1];
                                    event_time[sort_j+1] <= temp_time;
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
                        current_trees <= current_trees + event_delta[sweep_idx];
                        if (sweep_idx < total_events - 1 && event_time[sweep_idx] == event_time[sweep_idx+1]) begin
                        end else begin
                            if (current_trees > max_trees) begin
                                max_trees <= current_trees;
                            end
                        end
                        sweep_idx <= sweep_idx + 1;
                    end else begin
                        state <= FINISHED;
                        done <= 1;
                        result_max_trees <= max_trees;
                    end
                end

                FINISHED: begin
                end
            endcase
        end
    end
endmodule