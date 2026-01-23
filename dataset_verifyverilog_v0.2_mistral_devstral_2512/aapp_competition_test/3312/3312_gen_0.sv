module johnny5_optimizer (
    input clk,
    input rst_n,
    input start,
    input [1:0] start_x,
    input [1:0] start_y,
    input [3:0] start_energy,
    input [1:0] can_count,
    input [7:0] can_info [0:3],
    output reg [7:0] max_score,
    output reg done
);

    parameter T_MAX = 8;
    parameter GRID_SIZE = 4;
    parameter MAX_ENERGY = 16;
    parameter MAX_CANS = 4;
    parameter X_BITS = 2;
    parameter Y_BITS = 2;
    parameter TIME_BITS = 4;
    parameter ENERGY_BITS = 4;

    typedef enum logic [3:0] {
        IDLE,
        PARSE_CANS,
        DP_INIT,
        DP_TIME_LOOP,
        DP_STATE_LOOP,
        DP_ACTION_LOOP,
        FIND_MAX,
        DONE
    } state_t;

    state_t current_state, next_state;

    logic [TIME_BITS-1:0] time_counter;
    logic [X_BITS-1:0] x_counter;
    logic [Y_BITS-1:0] y_counter;
    logic [ENERGY_BITS-1:0] energy_counter;
    logic [1:0] action_counter;

    logic [7:0] cans_at_time [0:T_MAX-1] [0:GRID_SIZE-1] [0:GRID_SIZE-1];
    logic [7:0] dp_current [0:GRID_SIZE-1] [0:GRID_SIZE-1] [0:MAX_ENERGY-1];
    logic [7:0] dp_next [0:GRID_SIZE-1] [0:GRID_SIZE-1] [0:MAX_ENERGY-1];

    logic [7:0] current_max;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            time_counter <= 0;
            x_counter <= 0;
            y_counter <= 0;
            energy_counter <= 0;
            action_counter <= 0;
            max_score <= 0;
            done <= 0;
            current_max <= 0;

            for (int t = 0; t < T_MAX; t++) begin
                for (int x = 0; x < GRID_SIZE; x++) begin
                    for (int y = 0; y < GRID_SIZE; y++) begin
                        cans_at_time[t][x][y] <= 0;
                    end
                end
            end

            for (int x = 0; x < GRID_SIZE; x++) begin
                for (int y = 0; y < GRID_SIZE; y++) begin
                    for (int e = 0; e < MAX_ENERGY; e++) begin
                        dp_current[x][y][e] <= 0;
                        dp_next[x][y][e] <= 0;
                    end
                end
            end
        end else begin
            current_state <= next_state;

            case (current_state)
                PARSE_CANS: begin
                    if (time_counter == T_MAX-1 && x_counter == GRID_SIZE-1 && y_counter == GRID_SIZE-1) begin
                        next_state <= DP_INIT;
                    end else if (y_counter == GRID_SIZE-1) begin
                        if (x_counter == GRID_SIZE-1) begin
                            time_counter <= time_counter + 1;
                        end else begin
                            x_counter <= x_counter + 1;
                        end
                        y_counter <= 0;
                    end else begin
                        y_counter <= y_counter + 1;
                    end
                end

                DP_INIT: begin
                    if (x_counter == GRID_SIZE-1 && y_counter == GRID_SIZE-1 && energy_counter == MAX_ENERGY-1) begin
                        next_state <= DP_TIME_LOOP;
                        time_counter <= 0;
                    end else if (energy_counter == MAX_ENERGY-1) begin
                        if (y_counter == GRID_SIZE-1) begin
                            x_counter <= x_counter + 1;
                        end else begin
                            y_counter <= y_counter + 1;
                        end
                        energy_counter <= 0;
                    end else begin
                        energy_counter <= energy_counter + 1;
                    end
                end

                DP_TIME_LOOP: begin
                    if (time_counter == T_MAX-1) begin
                        next_state <= FIND_MAX;
                    end else begin
                        next_state <= DP_STATE_LOOP;
                    end
                end

                DP_STATE_LOOP: begin
                    if (x_counter == GRID_SIZE-1 && y_counter == GRID_SIZE-1 && energy_counter == MAX_ENERGY-1) begin
                        next_state <= DP_TIME_LOOP;
                        time_counter <= time_counter + 1;
                        x_counter <= 0;
                        y_counter <= 0;
                        energy_counter <= 0;
                    end else if (energy_counter == MAX_ENERGY-1) begin
                        if (y_counter == GRID_SIZE-1) begin
                            x_counter <= x_counter + 1;
                        end else begin
                            y_counter <= y_counter + 1;
                        end
                        energy_counter <= 0;
                    end else begin
                        energy_counter <= energy_counter + 1;
                    end
                end

                DP_ACTION_LOOP: begin
                    if (action_counter == 4) begin
                        next_state <= DP_STATE_LOOP;
                        action_counter <= 0;
                    end else begin
                        action_counter <= action_counter + 1;
                    end
                end

                FIND_MAX: begin
                    if (x_counter == GRID_SIZE-1 && y_counter == GRID_SIZE-1 && energy_counter == MAX_ENERGY-1) begin
                        next_state <= DONE;
                        max_score <= current_max;
                        done <= 1;
                    end else if (energy_counter == MAX_ENERGY-1) begin
                        if (y_counter == GRID_SIZE-1) begin
                            x_counter <= x_counter + 1;
                        end else begin
                            y_counter <= y_counter + 1;
                        end
                        energy_counter <= 0;
                    end else begin
                        energy_counter <= energy_counter + 1;
                    end
                end

                DONE: begin
                    if (!start) begin
                        next_state <= IDLE;
                        done <= 0;
                    end
                end

                default: begin
                    if (start) begin
                        next_state <= PARSE_CANS;
                        time_counter <= 0;
                        x_counter <= 0;
                        y_counter <= 0;
                        energy_counter <= 0;
                        action_counter <= 0;
                        current_max <= 0;
                    end
                end
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            // Reset handled in main always block
        end else begin
            case (current_state)
                PARSE_CANS: begin
                    if (time_counter < T_MAX && x_counter < GRID_SIZE && y_counter < GRID_SIZE) begin
                        logic [7:0] cans_here = 0;
                        for (int i = 0; i < MAX_CANS; i++) begin
                            if (i < can_count && can_info[i][5:4] == x_counter && can_info[i][3:2] == y_counter && can_info[i][1:0] == time_counter) begin
                                cans_here <= cans_here + 1;
                            end
                        end
                        cans_at_time[time_counter][x_counter][y_counter] <= cans_here;
                    end
                end

                DP_INIT: begin
                    if (x_counter == start_x && y_counter == start_y && energy_counter == start_energy) begin
                        dp_current[x_counter][y_counter][energy_counter] <= 0;
                    end else begin
                        dp_current[x_counter][y_counter][energy_counter] <= 0;
                    end
                end

                DP_TIME_LOOP: begin
                    // Copy dp_next to dp_current
                    for (int x = 0; x < GRID_SIZE; x++) begin
                        for (int y = 0; y < GRID_SIZE; y++) begin
                            for (int e = 0; e < MAX_ENERGY; e++) begin
                                dp_current[x][y][e] <= dp_next[x][y][e];
                            end
                        end
                    end
                end

                DP_STATE_LOOP: begin
                    if (dp_current[x_counter][y_counter][energy_counter] > 0) begin
                        next_state <= DP_ACTION_LOOP;
                    end
                end

                DP_ACTION_LOOP: begin
                    logic [7:0] current_score = dp_current[x_counter][y_counter][energy_counter];
                    logic [7:0] new_score;
                    logic [3:0] new_energy;
                    logic [1:0] new_x, new_y;

                    case (action_counter)
                        0: begin // Stay
                            new_x = x_counter;
                            new_y = y_counter;
                            new_energy = energy_counter;
                            new_score = current_score + cans_at_time[time_counter][new_x][new_y];
                            if (new_score > dp_next[new_x][new_y][new_energy]) begin
                                dp_next[new_x][new_y][new_energy] <= new_score;
                            end
                        end

                        1: begin // Up
                            if (y_counter > 0 && energy_counter > 0) begin
                                new_x = x_counter;
                                new_y = y_counter - 1;
                                new_energy = energy_counter - 1;
                                new_score = current_score + cans_at_time[time_counter][new_x][new_y];
                                if (new_score > dp_next[new_x][new_y][new_energy]) begin
                                    dp_next[new_x][new_y][new_energy] <= new_score;
                                end
                            end
                        end

                        2: begin // Down
                            if (y_counter < GRID_SIZE-1 && energy_counter > 0) begin
                                new_x = x_counter;
                                new_y = y_counter + 1;
                                new_energy = energy_counter - 1;
                                new_score = current_score + cans_at_time[time_counter][new_x][new_y];
                                if (new_score > dp_next[new_x][new_y][new_energy]) begin
                                    dp_next[new_x][new_y][new_energy] <= new_score;
                                end
                            end
                        end

                        3: begin // Left
                            if (x_counter > 0 && energy_counter > 0) begin
                                new_x = x_counter - 1;
                                new_y = y_counter;
                                new_energy = energy_counter - 1;
                                new_score = current_score + cans_at_time[time_counter][new_x][new_y];
                                if (new_score > dp_next[new_x][new_y][new_energy]) begin
                                    dp_next[new_x][new_y][new_energy] <= new_score;
                                end
                            end
                        end

                        4: begin // Right
                            if (x_counter < GRID_SIZE-1 && energy_counter > 0) begin
                                new_x = x_counter + 1;
                                new_y = y_counter;
                                new_energy = energy_counter - 1;
                                new_score = current_score + cans_at_time[time_counter][new_x][new_y];
                                if (new_score > dp_next[new_x][new_y][new_energy]) begin
                                    dp_next[new_x][new_y][new_energy] <= new_score;
                                end
                            end
                        end
                    endcase
                end

                FIND_MAX: begin
                    if (dp_current[x_counter][y_counter][energy_counter] > current_max) begin
                        current_max <= dp_current[x_counter][y_counter][energy_counter];
                    end
                end
            endcase
        end
    end

endmodule