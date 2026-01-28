module mst_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N, // Number of planets (1-8)
    // Planet coordinates (8 planets, each with x, y, z)
    input wire [31:0] x0, y0, z0,
    input wire [31:0] x1, y1, z1,
    input wire [31:0] x2, y2, z2,
    input wire [31:0] x3, y3, z3,
    input wire [31:0] x4, y4, z4,
    input wire [31:0] x5, y5, z5,
    input wire [31:0] x6, y6, z6,
    input wire [31:0] x7, y7, z7,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MAX_N = 8;
    parameter DATA_WIDTH = 32;
    parameter INF = 32'h7FFF_FFFF;

    // State definitions
    localparam [3:0] IDLE = 4'b0000;
    localparam [3:0] INIT_DIST = 4'b0001;
    localparam [3:0] FIND_MIN = 4'b0010;
    localparam [3:0] ADD_TO_TREE = 4'b0011;
    localparam [3:0] UPDATE_DIST = 4'b0100;
    localparam [3:0] DONE = 4'b0101;
    localparam [3:0] COST_WAIT = 4'b0110;

    // Registers for coordinates (latched at start)
    reg [DATA_WIDTH-1:0] x_reg [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] y_reg [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] z_reg [0:MAX_N-1];
    reg loaded;

    // State machine registers
    reg [3:0] state, next_state;
    reg [MAX_N-1:0] visited, next_visited;
    reg [DATA_WIDTH-1:0] dist [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] next_dist [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] total_cost, next_total_cost;
    reg [3:0] curr_planet, next_curr_planet;
    reg [3:0] visited_count, next_visited_count;

    // Counters for loops
    reg [3:0] idx, next_idx;
    reg [3:0] init_i, next_init_i;
    reg [3:0] find_j, next_find_j;
    reg [3:0] update_k, next_update_k;

    // Cost computation interface
    reg cost_compute_start, next_cost_compute_start;
    reg [3:0] i_idx, j_idx;
    reg [DATA_WIDTH-1:0] cost_out, next_cost_out;
    reg cost_valid, next_cost_valid;

    // Temporary registers for cost computation pipeline
    reg [DATA_WIDTH-1:0] temp_x_i, temp_y_i, temp_z_i;
    reg [DATA_WIDTH-1:0] temp_x_j, temp_y_j, temp_z_j;
    reg [DATA_WIDTH-1:0] temp_dx, temp_dy, temp_dz;
    reg [DATA_WIDTH-1:0] abs_dx, abs_dy, abs_dz;
    reg [1:0] cost_state, next_cost_state;

    // Helper: latch coordinates on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loaded <= 0;
        end else if (start) begin
            x_reg[0] <= x0; y_reg[0] <= y0; z_reg[0] <= z0;
            x_reg[1] <= x1; y_reg[1] <= y1; z_reg[1] <= z1;
            x_reg[2] <= x2; y_reg[2] <= y2; z_reg[2] <= z2;
            x_reg[3] <= x3; y_reg[3] <= y3; z_reg[3] <= z3;
            x_reg[4] <= x4; y_reg[4] <= y4; z_reg[4] <= z4;
            x_reg[5] <= x5; y_reg[5] <= y5; z_reg[5] <= z5;
            x_reg[6] <= x6; y_reg[6] <= y6; z_reg[6] <= z6;
            x_reg[7] <= x7; y_reg[7] <= y7; z_reg[7] <= z7;
            loaded <= 1;
        end
    end

    // Cost computation unit (sequential, 4 cycles)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cost_state <= 2'b00;
            cost_valid <= 0;
            cost_out <= 0;
        end else begin
            case (cost_state)
                2'b00: begin
                    cost_valid <= 0;
                    if (cost_compute_start) begin
                        temp_x_i <= x_reg[i_idx];
                        temp_y_i <= y_reg[i_idx];
                        temp_z_i <= z_reg[i_idx];
                        temp_x_j <= x_reg[j_idx];
                        temp_y_j <= y_reg[j_idx];
                        temp_z_j <= z_reg[j_idx];
                        cost_state <= 2'b01;
                    end
                end
                2'b01: begin
                    temp_dx <= temp_x_i - temp_x_j;
                    temp_dy <= temp_y_i - temp_y_j;
                    temp_dz <= temp_z_i - temp_z_j;
                    cost_state <= 2'b10;
                end
                2'b10: begin
                    abs_dx <= (temp_dx[31]) ? -temp_dx : temp_dx;
                    abs_dy <= (temp_dy[31]) ? -temp_dy : temp_dy;
                    abs_dz <= (temp_dz[31]) ? -temp_dz : temp_dz;
                    cost_state <= 2'b11;
                end
                2'b11: begin
                    cost_out <= (((abs_dx < abs_dy) ? abs_dx : abs_dy) < abs_dz) ? ((abs_dx < abs_dy) ? abs_dx : abs_dy) : abs_dz;
                    cost_valid <= 1;
                    cost_state <= 2'b00;
                end
            endcase
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            visited <= 0;
            total_cost <= 0;
            curr_planet <= 0;
            visited_count <= 0;
            idx <= 0;
            init_i <= 0;
            find_j <= 0;
            update_k <= 0;
            cost_compute_start <= 0;
            for (integer i = 0; i < MAX_N; i = i + 1) begin
                dist[i] <= INF;
            end
            result <= 0;
            done <= 0;
        end else begin
            next_state = state;
            next_visited = visited;
            next_total_cost = total_cost;
            next_curr_planet = curr_planet;
            next_visited_count = visited_count;
            next_idx = idx;
            next_init_i = init_i;
            next_find_j = find_j;
            next_update_k = update_k;
            next_cost_compute_start = 0;
            next_dist = dist;
            next_cost_out = cost_out;
            next_cost_valid = cost_valid;

            case (state)
                IDLE: begin
                    done <= 0;
                    if (start && loaded) begin
                        for (integer i = 0; i < MAX_N; i = i + 1) begin
                            next_dist[i] = INF;
                        end
                        next_visited = 0;
                        next_total_cost = 0;
                        next_visited_count = 0;
                        next_init_i = 1;
                        if (N == 1) begin
                            next_state = DONE;
                        end else begin
                            next_state = INIT_DIST;
                        end
                    end
                end

                INIT_DIST: begin
                    i_idx = 0;
                    j_idx = init_i;
                    next_cost_compute_start = 1;
                    next_idx = 0;
                    next_state = COST_WAIT;
                end

                FIND_MIN: begin
                    if (find_j < N) begin
                        if (!visited[find_j] && dist[find_j] < next_total_cost) begin
                            next_total_cost = dist[find_j];
                            next_curr_planet = find_j;
                        end
                        next_find_j = find_j + 1;
                    end else begin
                        next_find_j = 0;
                        next_state = ADD_TO_TREE;
                    end
                end

                ADD_TO_TREE: begin
                    next_visited[curr_planet] = 1;
                    next_visited_count = visited_count + 1;
                    next_state = UPDATE_DIST;
                    next_update_k = 0;
                end

                UPDATE_DIST: begin
                    if (update_k < N) begin
                        if (!visited[update_k]) begin
                            i_idx = curr_planet;
                            j_idx = update_k;
                            next_cost_compute_start = 1;
                            next_idx = 1;
                            next_state = COST_WAIT;
                        end else begin
                            next_update_k = update_k + 1;
                        end
                    end else begin
                        if (visited_count == N-1) begin
                            next_state = DONE;
                        end else begin
                            next_state = FIND_MIN;
                            next_total_cost = INF;
                            next_find_j = 0;
                        end
                    end
                end

                COST_WAIT: begin
                    if (cost_valid) begin
                        if (idx == 0) begin
                            next_dist[init_i] = cost_out;
                            if (init_i + 1 < N) begin
                                next_init_i = init_i + 1;
                                next_state = INIT_DIST;
                            end else begin
                                next_init_i = 0;
                                next_state = FIND_MIN;
                                next_total_cost = INF;
                                next_find_j = 0;
                            end
                        end else if (idx == 1) begin
                            if (cost_out < dist[update_k]) begin
                                next_dist[update_k] = cost_out;
                            end
                            next_update_k = update_k + 1;
                            next_state = UPDATE_DIST;
                        end
                    end else begin
                        next_state = COST_WAIT;
                    end
                end

                DONE: begin
                    result <= total_cost;
                    done <= 1;
                    next_state = IDLE;
                end

                default: begin
                    next_state = IDLE;
                end
            endcase

            state <= next_state;
            visited <= next_visited;
            total_cost <= next_total_cost;
            curr_planet <= next_curr_planet;
            visited_count <= next_visited_count;
            idx <= next_idx;
            init_i <= next_init_i;
            find_j <= next_find_j;
            update_k <= next_update_k;
            cost_compute_start <= next_cost_compute_start;
            dist <= next_dist;
            cost_out <= next_cost_out;
            cost_valid <= next_cost_valid;
        end
    end

endmodule