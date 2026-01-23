module johnny5_optimizer(
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

    localparam T_MAX = 8;
    localparam GRID_SIZE = 4;
    localparam MAX_ENERGY = 16;

    reg [7:0] dp_table [T_MAX+1][GRID_SIZE][GRID_SIZE][MAX_ENERGY+1];
    reg [2:0] state, next_state;
    reg [1:0] captured_start_x, captured_start_y;
    reg [3:0] captured_start_energy;
    reg [3:0] can_count [4][GRID_SIZE][GRID_SIZE];
    reg [3:0] t_counter, x_counter, y_counter, e_counter;
    reg [2:0] sub_state;

    parameter IDLE = 3'd0, PARSE_CANS = 3'd1, DP_INIT = 3'd2, PROCESSING_DP = 3'd3, FIND_MAX = 3'd4, DONE = 3'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            captured_start_x <= 0;
            captured_start_y <= 0;
            captured_start_energy <= 0;
            for (int i=0; i<4; i++) for (int x=0; x<GRID_SIZE; x++) for (int y=0; y<GRID_SIZE; y++) can_count[i][x][y] <= 0;
            for (int t=0; t<=T_MAX; t++) for (int x=0; x<GRID_SIZE; x++) for (int y=0; y<GRID_SIZE; y++) for (int e=0; e<=MAX_ENERGY; e++) dp_table[t][x][y][e] <= 0;
            t_counter <= 0;
            x_counter <= 0;
            y_counter <= 0;
            e_counter <= 0;
            sub_state <= 0;
            max_score <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            if (state == IDLE && start) begin
                captured_start_x <= start_x;
                captured_start_y <= start_y;
                captured_start_energy <= start_energy;
                next_state <= PARSE_CANS;
            end
            if (state == PARSE_CANS) begin
                if (can_count > 0) begin
                    if (0 < can_count) begin
                        int X = (can_info[0] >> 4) & 3;
                        int Y = (can_info[0] >> 2) & 3;
                        int time_can = can_info[0] & 3;
                        can_count[time_can][X][Y] <= can_count[time_can][X][Y] + 1;
                    end
                    if (1 < can_count) begin
                        int X = (can_info[1] >> 4) & 3;
                        int Y = (can_info[1] >> 2) & 3;
                        int time_can = can_info[1] & 3;
                        can_count[time_can][X][Y] <= can_count[time_can][X][Y] + 1;
                    end
                    if (2 < can_count) begin
                        int X = (can_info[2] >> 4) & 3;
                        int Y = (can_info[2] >> 2) & 3;
                        int time_can = can_info[2] & 3;
                        can_count[time_can][X][Y] <= can_count[time_can][X][Y] + 1;
                    end
                    if (3 < can_count) begin
                        int X = (can_info[3] >> 4) & 3;
                        int Y = (can_info[3] >> 2) & 3;
                        int time_can = can_info[3] & 3;
                        can_count[time_can][X][Y] <= can_count[time_can][X][Y] + 1;
                    end
                end
                next_state <= DP_INIT;
            end
            if (state == DP_INIT) begin
                dp_table[0][captured_start_x][captured_start_y][captured_start_energy] <= can_count[0][captured_start_x][captured_start_y];
                next_state <= PROCESSING_DP;
            end
            if (state == PROCESSING_DP) begin
                if (sub_state == 0) begin
                    if (t_counter < T_MAX) begin
                        t_counter <= t_counter + 1;
                        x_counter <= 0;
                        y_counter <= 0;
                        e_counter <= 0;
                        sub_state <= 1;
                    end else begin
                        next_state <= FIND_MAX;
                        sub_state <= 0;
                    end
                end else if (sub_state == 1) begin
                    if (x_counter < GRID_SIZE) begin
                        x_counter <= x_counter + 1;
                        sub_state <= 2;
                    end else begin
                        x_counter <= 0;
                        y_counter <= y_counter + 1;
                        sub_state <= 2;
                        if (y_counter >= GRID_SIZE) begin
                            y_counter <= 0;
                            e_counter <= e_counter + 1;
                            sub_state <= 3;
                            if (e_counter > MAX_ENERGY) begin
                                e_counter <= 0;
                                sub_state <= 0;
                            end
                        end
                    end
                end else if (sub_state == 2) begin
                    if (y_counter < GRID_SIZE) begin
                        y_counter <= y_counter + 1;
                        sub_state <= 3;
                    end else begin
                        y_counter <= 0;
                        e_counter <= e_counter + 1;
                        sub_state <= 3;
                        if (e_counter > MAX_ENERGY) begin
                            e_counter <= 0;
                            sub_state <= 0;
                        end
                    end
                end else if (sub_state == 3) begin
                    // Compute DP value here
                    e_counter <= e_counter + 1;
                    if (e_counter > MAX_ENERGY) begin
                        e_counter <= 0;
                        sub_state <= 0;
                    end
                end
            end
            if (state == FIND_MAX) begin
                int max_val = 0;
                for (int x=0; x<GRID_SIZE; x++) begin
                    for (int y=0; y<GRID_SIZE; y++) begin
                        for (int e=0; e<=MAX_ENERGY; e++) begin
                            if (dp_table[T_MAX][x][y][e] > max_val) max_val = dp_table[T_MAX][x][y][e];
                        end
                    end
                end
                max_score <= max_val;
                done <= 1;
                next_state <= DONE;
            end
            if (next_state == 0) next_state <= state;
            if (state == PROCESSING_DP && sub_state > 0) sub_state <= sub_state - 1;
        end
    end

    endmodule