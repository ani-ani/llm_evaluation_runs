module Johnny5OilCanGame(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] grid_size,
    input wire [3:0] start_energy,
    input wire [3:0] start_x,
    input wire [3:0] start_y,
    input wire [3:0] can_count,
    input wire [3:0] can_x_in,
    input wire [3:0] can_y_in,
    input wire [3:0] can_time_in,
    input wire can_write,
    output reg [7:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_CANS = 3'd1;
    localparam [2:0] SORT_CANS = 3'd2;
    localparam [2:0] INIT_DP = 3'd3;
    localparam [2:0] PROCESS_CANS = 3'd4;
    localparam [2:0] FIND_MAX = 3'd5;
    localparam [2:0] OUTPUT_RESULT = 3'd6;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] grid_size_reg;
    reg [3:0] start_energy_reg;
    reg [3:0] start_x_reg;
    reg [3:0] start_y_reg;
    reg [3:0] can_count_reg;
    reg [3:0] can_index;
    reg [3:0] can_x [0:7];
    reg [3:0] can_y [0:7];
    reg [3:0] can_time [0:7];
    reg [3:0] current_can;
    reg [3:0] time_idx;
    reg [3:0] x_idx;
    reg [3:0] y_idx;
    reg [3:0] e_idx;
    reg [7:0] max_score;
    reg [3:0] max_time;

    // DP table: 32x16x16x9 (time, x, y, energy)
    reg [7:0] dp [0:31] [0:15] [0:15] [0:8];

    // Sorting registers
    reg [3:0] sort_i;
    reg [3:0] sort_j;
    reg sort_done;

    // Cycle counter for safety
    reg [12:0] cycle_count;
    localparam [12:0] MAX_CYCLES = 13'd5000;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            grid_size_reg <= 4'd0;
            start_energy_reg <= 4'd0;
            start_x_reg <= 4'd0;
            start_y_reg <= 4'd0;
            can_count_reg <= 4'd0;
            can_index <= 4'd0;
            current_can <= 4'd0;
            time_idx <= 4'd0;
            x_idx <= 4'd0;
            y_idx <= 4'd0;
            e_idx <= 4'd0;
            max_score <= 8'd0;
            max_time <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            sort_done <= 1'b0;
            cycle_count <= 13'd0;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 8'd0;

            // Initialize can buffers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                can_x[i] <= 4'd0;
                can_y[i] <= 4'd0;
                can_time[i] <= 4'd0;
            end

            // Initialize DP table
            integer t, x, y, e;
            for (t = 0; t < 32; t = t + 1) begin
                for (x = 0; x < 16; x = x + 1) begin
                    for (y = 0; y < 16; y = y + 1) begin
                        for (e = 0; e < 9; e = e + 1) begin
                            dp[t][x][y][e] <= 8'd255;
                        end
                    end
                end
            end
        end else begin
            state <= next_state;

            // Load input data on start
            if (start) begin
                grid_size_reg <= grid_size;
                start_energy_reg <= start_energy;
                start_x_reg <= start_x;
                start_y_reg <= start_y;
                can_count_reg <= can_count;
                can_index <= 4'd0;
                next_state <= LOAD_CANS;
                busy <= 1'b1;
                done <= 1'b0;
                cycle_count <= 13'd0;
            end

            // Load can data
            if (can_write && state == LOAD_CANS) begin
                can_x[can_index] <= can_x_in;
                can_y[can_index] <= can_y_in;
                can_time[can_index] <= can_time_in;
                can_index <= can_index + 4'd1;
                if (can_index == can_count_reg) begin
                    next_state <= SORT_CANS;
                    sort_i <= 4'd0;
                    sort_j <= 4'd0;
                    sort_done <= 1'b0;
                end
            end

            // State machine
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                end

                LOAD_CANS: begin
                    // Wait for all cans to be loaded
                    if (can_index == can_count_reg) begin
                        next_state <= SORT_CANS;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                        sort_done <= 1'b0;
                    end
                end

                SORT_CANS: begin
                    // Bubble sort cans by time
                    if (!sort_done) begin
                        if (sort_j < can_count_reg - 4'd1) begin
                            if (can_time[sort_j] > can_time[sort_j + 4'd1]) begin
                                // Swap
                                reg [3:0] temp_x, temp_y, temp_time;
                                temp_x = can_x[sort_j];
                                temp_y = can_y[sort_j];
                                temp_time = can_time[sort_j];
                                can_x[sort_j] = can_x[sort_j + 4'd1];
                                can_y[sort_j] = can_y[sort_j + 4'd1];
                                can_time[sort_j] = can_time[sort_j + 4'd1];
                                can_x[sort_j + 4'd1] = temp_x;
                                can_y[sort_j + 4'd1] = temp_y;
                                can_time[sort_j + 4'd1] = temp_time;
                            end
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            if (sort_i < can_count_reg - 4'd1) begin
                                sort_i <= sort_i + 4'd1;
                            end else begin
                                sort_done <= 1'b1;
                                next_state <= INIT_DP;
                                time_idx <= 4'd0;
                                x_idx <= 4'd0;
                                y_idx <= 4'd0;
                                e_idx <= 4'd0;
                            end
                        end
                    end
                end

                INIT_DP: begin
                    // Initialize DP table
                    if (time_idx == 4'd0 && x_idx == start_x_reg && y_idx == start_y_reg && e_idx == start_energy_reg) begin
                        dp[0][start_x_reg][start_y_reg][start_energy_reg] <= 8'd0;
                    end

                    // Increment counters
                    if (e_idx < 8'd8) begin
                        e_idx <= e_idx + 4'd1;
                    end else if (y_idx < 4'd15) begin
                        e_idx <= 4'd0;
                        y_idx <= y_idx + 4'd1;
                    end else if (x_idx < 4'd15) begin
                        e_idx <= 4'd0;
                        y_idx <= 4'd0;
                        x_idx <= x_idx + 4'd1;
                    end else if (time_idx < 5'd31) begin
                        e_idx <= 4'd0;
                        y_idx <= 4'd0;
                        x_idx <= 4'd0;
                        time_idx <= time_idx + 4'd1;
                    end else begin
                        time_idx <= 4'd0;
                        x_idx <= 4'd0;
                        y_idx <= 4'd0;
                        e_idx <= 4'd0;
                        current_can <= 4'd0;
                        next_state <= PROCESS_CANS;
                    end
                end

                PROCESS_CANS: begin
                    // Process each can in sorted order
                    if (current_can < can_count_reg) begin
                        reg [3:0] can_time_current = can_time[current_can];
                        reg [3:0] can_x_current = can_x[current_can];
                        reg [3:0] can_y_current = can_y[current_can];

                        // Process time steps up to can_time_current
                        if (time_idx <= can_time_current) begin
                            // Process current time step
                            if (x_idx < 4'd16) begin
                                if (y_idx < 4'd16) begin
                                    if (e_idx < 4'd9) begin
                                        reg [7:0] current_score = dp[time_idx][x_idx][y_idx][e_idx];

                                        // Only process if current state is valid
                                        if (current_score != 8'd255) begin
                                            // Option 1: Stand still (energy > 0)
                                            if (e_idx > 4'd0) begin
                                                reg [7:0] new_score = current_score;
                                                if (new_score < dp[time_idx + 4'd1][x_idx][y_idx][e_idx]) begin
                                                    dp[time_idx + 4'd1][x_idx][y_idx][e_idx] <= new_score;
                                                end
                                            end

                                            // Option 2: Move in 4 directions (energy > 0)
                                            if (e_idx > 4'd0) begin
                                                reg [3:0] new_e = e_idx - 4'd1;
                                                reg [3:0] new_x, new_y;

                                                // Move up
                                                new_x = x_idx;
                                                new_y = y_idx + 4'd1;
                                                if (new_y < grid_size_reg) begin
                                                    if (current_score < dp[time_idx + 4'd1][new_x][new_y][new_e]) begin
                                                        dp[time_idx + 4'd1][new_x][new_y][new_e] <= current_score;
                                                    end
                                                end

                                                // Move down
                                                new_y = y_idx - 4'd1;
                                                if (new_y >= 4'd0) begin
                                                    if (current_score < dp[time_idx + 4'd1][new_x][new_y][new_e]) begin
                                                        dp[time_idx + 4'd1][new_x][new_y][new_e] <= current_score;
                                                    end
                                                end

                                                // Move right
                                                new_x = x_idx + 4'd1;
                                                new_y = y_idx;
                                                if (new_x < grid_size_reg) begin
                                                    if (current_score < dp[time_idx + 4'd1][new_x][new_y][new_e]) begin
                                                        dp[time_idx + 4'd1][new_x][new_y][new_e] <= current_score;
                                                    end
                                                end

                                                // Move left
                                                new_x = x_idx - 4'd1;
                                                if (new_x >= 4'd0) begin
                                                    if (current_score < dp[time_idx + 4'd1][new_x][new_y][new_e]) begin
                                                        dp[time_idx + 4'd1][new_x][new_y][new_e] <= current_score;
                                                    end
                                                end
                                            end
                                        end

                                        // Increment energy counter
                                        e_idx <= e_idx + 4'd1;
                                    end else begin
                                        e_idx <= 4'd0;
                                        y_idx <= y_idx + 4'd1;
                                    end
                                end else begin
                                    y_idx <= 4'd0;
                                    x_idx <= x_idx + 4'd1;
                                end
                            end else begin
                                x_idx <= 4'd0;
                                y_idx <= 4'd0;
                                e_idx <= 4'd0;
                                time_idx <= time_idx + 4'd1;
                            end

                            // Check if we've reached the can time
                            if (time_idx == can_time_current) begin
                                // Apply can effects
                                integer x, y, e;
                                for (x = 0; x < 16; x = x + 1) begin
                                    for (y = 0; y < 16; y = y + 1) begin
                                        for (e = 0; e < 9; e = e + 1) begin
                                            reg [7:0] current_score = dp[time_idx][x][y][e];
                                            if (current_score != 8'd255) begin
                                                // At can position: +1 point
                                                if (x == can_x_current && y == can_y_current) begin
                                                    reg [7:0] new_score = current_score + 8'd1;
                                                    if (new_score < 8'd255) begin
                                                        dp[time_idx][x][y][e] <= new_score;
                                                    end
                                                end
                                                // Adjacent to can: +1 energy (capped at 8)
                                                else if ((x == can_x_current && (y == can_y_current + 4'd1 || y == can_y_current - 4'd1)) ||
                                                         (y == can_y_current && (x == can_x_current + 4'd1 || x == can_x_current - 4'd1))) begin
                                                    reg [3:0] new_e = (e + 4'd1) > 4'd8 ? 4'd8 : (e + 4'd1);
                                                    if (current_score < dp[time_idx][x][y][new_e]) begin
                                                        dp[time_idx][x][y][new_e] <= current_score;
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end

                                // Move to next can
                                current_can <= current_can + 4'd1;
                                time_idx <= 4'd0;
                                x_idx <= 4'd0;
                                y_idx <= 4'd0;
                                e_idx <= 4'd0;
                            end
                        end else begin
                            // Move to next can
                            current_can <= current_can + 4'd1;
                            time_idx <= 4'd0;
                            x_idx <= 4'd0;
                            y_idx <= 4'd0;
                            e_idx <= 4'd0;
                        end
                    end else begin
                        // All cans processed, find max score
                        max_time <= can_time[can_count_reg - 4'd1];
                        time_idx <= 4'd0;
                        x_idx <= 4'd0;
                        y_idx <= 4'd0;
                        e_idx <= 4'd0;
                        max_score <= 8'd0;
                        next_state <= FIND_MAX;
                    end
                end

                FIND_MAX: begin
                    // Find maximum score in final time step
                    if (time_idx <= max_time) begin
                        if (x_idx < 4'd16) begin
                            if (y_idx < 4'd16) begin
                                if (e_idx < 4'd9) begin
                                    if (dp[time_idx][x_idx][y_idx][e_idx] > max_score) begin
                                        max_score <= dp[time_idx][x_idx][y_idx][e_idx];
                                    end
                                    e_idx <= e_idx + 4'd1;
                                end else begin
                                    e_idx <= 4'd0;
                                    y_idx <= y_idx + 4'd1;
                                end
                            end else begin
                                y_idx <= 4'd0;
                                x_idx <= x_idx + 4'd1;
                            end
                        end else begin
                            x_idx <= 4'd0;
                            y_idx <= 4'd0;
                            e_idx <= 4'd0;
                            time_idx <= time_idx + 4'd1;
                        end
                    end else begin
                        result <= max_score;
                        next_state <= OUTPUT_RESULT;
                    end
                end

                OUTPUT_RESULT: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                busy <= 1'b0;
            end else begin
                cycle_count <= cycle_count + 13'd1;
            end
        end
    end

    // Set busy signal
    always @(*) begin
        if (state == IDLE) begin
            busy = 1'b0;
        end else begin
            busy = 1'b1;
        end
    end

endmodule