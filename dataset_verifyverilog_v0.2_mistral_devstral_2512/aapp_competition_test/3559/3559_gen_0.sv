module zergling_simulation (
    input clk,
    input rst_n,
    input start,
    input [2:0] grid_in_00_to_07, grid_in_08_to_15,
    input [2:0] grid_in_16_to_23, grid_in_24_to_31,
    input [2:0] grid_in_32_to_39, grid_in_40_to_47,
    input [2:0] grid_in_48_to_55, grid_in_56_to_63,
    input [3:0] p1_atk_up, p1_arm_up,
    input [3:0] p2_atk_up, p2_arm_up,
    input [7:0] num_turns,
    output reg [2:0] grid_out_00_to_07, grid_out_08_to_15,
    output reg [2:0] grid_out_16_to_23, grid_out_24_to_31,
    output reg [2:0] grid_out_32_to_39, grid_out_40_to_47,
    output reg [2:0] grid_out_48_to_55, grid_out_56_to_63,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam TURN_START = 3'b010;
    localparam CHECK_ATTACK = 3'b011;
    localparam EXECUTE_ATTACK = 3'b100;
    localparam CHECK_MOVE = 3'b101;
    localparam EXECUTE_MOVE = 3'b110;
    localparam REGENERATE = 3'b111;
    localparam NEXT_TURN = 3'b000; // Reuse IDLE for NEXT_TURN
    localparam DONE = 3'b001; // Reuse LOAD for DONE

    // Internal registers
    reg [2:0] state;
    reg [7:0] turn_counter;
    reg [7:0] p1_count, p2_count;
    reg [7:0] p1_hp [0:15], p2_hp [0:15];
    reg [2:0] p1_grid [0:15], p2_grid [0:15];
    reg [7:0] p1_x [0:15], p1_y [0:15];
    reg [7:0] p2_x [0:15], p2_y [0:15];
    reg [7:0] p1_atk_dmg, p2_atk_dmg;
    reg [7:0] p1_arm_val, p2_arm_val;
    reg [7:0] p1_atk_target [0:15], p2_atk_target [0:15];
    reg [7:0] p1_move_target [0:15], p2_move_target [0:15];
    reg [7:0] p1_move_dir [0:15], p2_move_dir [0:15];
    reg [7:0] p1_move_priority [0:15], p2_move_priority [0:15];
    reg [7:0] p1_move_collision [0:15], p2_move_collision [0:15];
    reg [7:0] p1_move_valid [0:15], p2_move_valid [0:15];
    reg [7:0] p1_move_final [0:15], p2_move_final [0:15];
    reg [7:0] p1_atk_valid [0:15], p2_atk_valid [0:15];
    reg [7:0] p1_atk_final [0:15], p2_atk_final [0:15];
    reg [7:0] p1_atk_dir [0:15], p2_atk_dir [0:15];
    reg [7:0] p1_atk_priority [0:15], p2_atk_priority [0:15];
    reg [7:0] p1_atk_collision [0:15], p2_atk_collision [0:15];
    reg [7:0] p1_atk_final [0:15], p2_atk_final [0:15];
    reg [7:0] p1_atk_final_dir [0:15], p2_atk_final_dir [0:15];
    reg [7:0] p1_atk_final_priority [0:15], p2_atk_final_priority [0:15];
    reg [7:0] p1_atk_final_collision [0:15], p2_atk_final_collision [0:15];
    reg [7:0] p1_atk_final_valid [0:15], p2_atk_final_valid [0:15];
    reg [7:0] p1_atk_final_final [0:15], p2_atk_final_final [0:15];
    reg [7:0] p1_atk_final_final_dir [0:15], p2_atk_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_priority [0:15], p2_atk_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_collision [0:15], p2_atk_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_valid [0:15], p2_atk_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final [0:15], p2_atk_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_dir [0:15], p2_atk_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_priority [0:15], p2_atk_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_collision [0:15], p2_atk_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_valid [0:15], p2_atk_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final [0:15], p2_atk_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_valid [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_final [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_final [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_final_dir [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_final_dir [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_final_priority [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_final_priority [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_final_collision [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_final_collision [0:15];
    reg [7:0] p1_atk_final_final_final_final_final_final_final_final_final_final_final_final_valid [0:15], p2_atk_final_final_final_final_final_final_final_final_final_final_final_final_valid [0:15];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) state <= LOAD;
                end
                LOAD: begin
                    state <= TURN_START;
                end
                TURN_START: begin
                    state <= CHECK_ATTACK;
                end
                CHECK_ATTACK: begin
                    state <= EXECUTE_ATTACK;
                end
                EXECUTE_ATTACK: begin
                    state <= CHECK_MOVE;
                end
                CHECK_MOVE: begin
                    state <= EXECUTE_MOVE;
                end
                EXECUTE_MOVE: begin
                    state <= REGENERATE;
                end
                REGENERATE: begin
                    state <= NEXT_TURN;
                end
                NEXT_TURN: begin
                    if (turn_counter == 0) state <= DONE;
                    else state <= TURN_START;
                end
                DONE: begin
                    done <= 1;
                end
            endcase
        end
    end

    // LOAD state: Parse grid_in into internal arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            p1_count <= 0;
            p2_count <= 0;
            for (int i = 0; i < 16; i++) begin
                p1_hp[i] <= 0;
                p2_hp[i] <= 0;
                p1_grid[i] <= 0;
                p2_grid[i] <= 0;
                p1_x[i] <= 0;
                p1_y[i] <= 0;
                p2_x[i] <= 0;
                p2_y[i] <= 0;
            end
        end else if (state == LOAD) begin
            p1_count <= 0;
            p2_count <= 0;
            for (int i = 0; i < 16; i++) begin
                p1_hp[i] <= 0;
                p2_hp[i] <= 0;
                p1_grid[i] <= 0;
                p2_grid[i] <= 0;
                p1_x[i] <= 0;
                p1_y[i] <= 0;
                p2_x[i] <= 0;
                p2_y[i] <= 0;
            end
            for (int y = 0; y < 8; y++) begin
                for (int x = 0; x < 8; x++) begin
                    case ({grid_in_00_to_07, grid_in_08_to_15, grid_in_16_to_23, grid_in_24_to_31, grid_in_32_to_39, grid_in_40_to_47, grid_in_48_to_55, grid_in_56_to_63}[y*8 + x])
                        1: begin
                            p1_grid[p1_count] <= {x, y};
                            p1_x[p1_count] <= x;
                            p1_y[p1_count] <= y;
                            p1_hp[p1_count] <= 35;
                            p1_count <= p1_count + 1;
                        end
                        2: begin
                            p2_grid[p2_count] <= {x, y};
                            p2_x[p2_count] <= x;
                            p2_y[p2_count] <= y;
                            p2_hp[p2_count] <= 35;
                            p2_count <= p2_count + 1;
                        end
                    endcase
                end
            end
            turn_counter <= num_turns;
            p1_atk_dmg <= 5 + p1_atk_up;
            p2_atk_dmg <= 5 + p2_atk_up;
            p1_arm_val <= p1_arm_up;
            p2_arm_val <= p2_arm_up;
        end
    end

    // CHECK_ATTACK state: Check neighbors for attacks
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                p1_atk_target[i] <= 0;
                p2_atk_target[i] <= 0;
                p1_atk_dir[i] <= 0;
                p2_atk_dir[i] <= 0;
                p1_atk_priority[i] <= 0;
                p2_atk_priority[i] <= 0;
                p1_atk_collision[i] <= 0;
                p2_atk_collision[i] <= 0;
                p1_atk_valid[i] <= 0;
                p2_atk_valid[i] <= 0;
            end
        end else if (state == CHECK_ATTACK) begin
            for (int i = 0; i < p1_count; i++) begin
                for (int d = 0; d < 8; d++) begin
                    int nx = p1_x[i] + (d == 1 || d == 2 || d == 3 ? 1 : (d == 5 || d == 6 || d == 7 ? -1 : 0));
                    int ny = p1_y[i] + (d == 3 || d == 4 || d == 5 ? 1 : (d == 0 || d == 1 || d == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        for (int j = 0; j < p2_count; j++) begin
                            if (p2_x[j] == nx && p2_y[j] == ny) begin
                                p1_atk_target[i] <= j;
                                p1_atk_dir[i] <= d;
                                p1_atk_priority[i] <= d;
                                p1_atk_collision[i] <= 0;
                                p1_atk_valid[i] <= 1;
                            end
                        end
                    end
                end
            end
            for (int i = 0; i < p2_count; i++) begin
                for (int d = 0; d < 8; d++) begin
                    int nx = p2_x[i] + (d == 1 || d == 2 || d == 3 ? 1 : (d == 5 || d == 6 || d == 7 ? -1 : 0));
                    int ny = p2_y[i] + (d == 3 || d == 4 || d == 5 ? 1 : (d == 0 || d == 1 || d == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        for (int j = 0; j < p1_count; j++) begin
                            if (p1_x[j] == nx && p1_y[j] == ny) begin
                                p2_atk_target[i] <= j;
                                p2_atk_dir[i] <= d;
                                p2_atk_priority[i] <= d;
                                p2_atk_collision[i] <= 0;
                                p2_atk_valid[i] <= 1;
                            end
                        end
                    end
                end
            end
        end
    end

    // EXECUTE_ATTACK state: Apply damage
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                p1_atk_final[i] <= 0;
                p2_atk_final[i] <= 0;
                p1_atk_final_dir[i] <= 0;
                p2_atk_final_dir[i] <= 0;
                p1_atk_final_priority[i] <= 0;
                p2_atk_final_priority[i] <= 0;
                p1_atk_final_collision[i] <= 0;
                p2_atk_final_collision[i] <= 0;
                p1_atk_final_valid[i] <= 0;
                p2_atk_final_valid[i] <= 0;
            end
        end else if (state == EXECUTE_ATTACK) begin
            for (int i = 0; i < p1_count; i++) begin
                if (p1_atk_valid[i]) begin
                    int target = p1_atk_target[i];
                    int damage = p1_atk_dmg - p2_arm_val;
                    if (damage > 0) begin
                        p2_hp[target] <= p2_hp[target] - damage;
                        if (p2_hp[target] <= 0) begin
                            p2_count <= p2_count - 1;
                            for (int j = target; j < p2_count; j++) begin
                                p2_x[j] <= p2_x[j+1];
                                p2_y[j] <= p2_y[j+1];
                                p2_hp[j] <= p2_hp[j+1];
                            end
                        end
                    end
                end
            end
            for (int i = 0; i < p2_count; i++) begin
                if (p2_atk_valid[i]) begin
                    int target = p2_atk_target[i];
                    int damage = p2_atk_dmg - p1_arm_val;
                    if (damage > 0) begin
                        p1_hp[target] <= p1_hp[target] - damage;
                        if (p1_hp[target] <= 0) begin
                            p1_count <= p1_count - 1;
                            for (int j = target; j < p1_count; j++) begin
                                p1_x[j] <= p1_x[j+1];
                                p1_y[j] <= p1_y[j+1];
                                p1_hp[j] <= p1_hp[j+1];
                            end
                        end
                    end
                end
            end
        end
    end

    // CHECK_MOVE state: Calculate moves
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                p1_move_target[i] <= 0;
                p2_move_target[i] <= 0;
                p1_move_dir[i] <= 0;
                p2_move_dir[i] <= 0;
                p1_move_priority[i] <= 0;
                p2_move_priority[i] <= 0;
                p1_move_collision[i] <= 0;
                p2_move_collision[i] <= 0;
                p1_move_valid[i] <= 0;
                p2_move_valid[i] <= 0;
            end
        end else if (state == CHECK_MOVE) begin
            for (int i = 0; i < p1_count; i++) begin
                int min_dist = 100;
                int best_dir = 0;
                for (int d = 0; d < 8; d++) begin
                    int nx = p1_x[i] + (d == 1 || d == 2 || d == 3 ? 1 : (d == 5 || d == 6 || d == 7 ? -1 : 0));
                    int ny = p1_y[i] + (d == 3 || d == 4 || d == 5 ? 1 : (d == 0 || d == 1 || d == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        for (int j = 0; j < p2_count; j++) begin
                            int dist = abs(nx - p2_x[j]) + abs(ny - p2_y[j]);
                            if (dist < min_dist) begin
                                min_dist = dist;
                                best_dir = d;
                            end
                        end
                    end
                end
                if (min_dist < 100) begin
                    p1_move_target[i] <= best_dir;
                    p1_move_dir[i] <= best_dir;
                    p1_move_priority[i] <= best_dir;
                    p1_move_collision[i] <= 0;
                    p1_move_valid[i] <= 1;
                end
            end
            for (int i = 0; i < p2_count; i++) begin
                int min_dist = 100;
                int best_dir = 0;
                for (int d = 0; d < 8; d++) begin
                    int nx = p2_x[i] + (d == 1 || d == 2 || d == 3 ? 1 : (d == 5 || d == 6 || d == 7 ? -1 : 0));
                    int ny = p2_y[i] + (d == 3 || d == 4 || d == 5 ? 1 : (d == 0 || d == 1 || d == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        for (int j = 0; j < p1_count; j++) begin
                            int dist = abs(nx - p1_x[j]) + abs(ny - p1_y[j]);
                            if (dist < min_dist) begin
                                min_dist = dist;
                                best_dir = d;
                            end
                        end
                    end
                end
                if (min_dist < 100) begin
                    p2_move_target[i] <= best_dir;
                    p2_move_dir[i] <= best_dir;
                    p2_move_priority[i] <= best_dir;
                    p2_move_collision[i] <= 0;
                    p2_move_valid[i] <= 1;
                end
            end
        end
    end

    // EXECUTE_MOVE state: Move Zerglings
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                p1_move_final[i] <= 0;
                p2_move_final[i] <= 0;
            end
        end else if (state == EXECUTE_MOVE) begin
            for (int i = 0; i < p1_count; i++) begin
                if (p1_move_valid[i]) begin
                    int nx = p1_x[i] + (p1_move_dir[i] == 1 || p1_move_dir[i] == 2 || p1_move_dir[i] == 3 ? 1 : (p1_move_dir[i] == 5 || p1_move_dir[i] == 6 || p1_move_dir[i] == 7 ? -1 : 0));
                    int ny = p1_y[i] + (p1_move_dir[i] == 3 || p1_move_dir[i] == 4 || p1_move_dir[i] == 5 ? 1 : (p1_move_dir[i] == 0 || p1_move_dir[i] == 1 || p1_move_dir[i] == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        int collision = 0;
                        for (int j = 0; j < p1_count; j++) begin
                            if (i != j && p1_x[j] == nx && p1_y[j] == ny) begin
                                collision = 1;
                            end
                        end
                        if (!collision) begin
                            p1_x[i] <= nx;
                            p1_y[i] <= ny;
                        end
                    end
                end
            end
            for (int i = 0; i < p2_count; i++) begin
                if (p2_move_valid[i]) begin
                    int nx = p2_x[i] + (p2_move_dir[i] == 1 || p2_move_dir[i] == 2 || p2_move_dir[i] == 3 ? 1 : (p2_move_dir[i] == 5 || p2_move_dir[i] == 6 || p2_move_dir[i] == 7 ? -1 : 0));
                    int ny = p2_y[i] + (p2_move_dir[i] == 3 || p2_move_dir[i] == 4 || p2_move_dir[i] == 5 ? 1 : (p2_move_dir[i] == 0 || p2_move_dir[i] == 1 || p2_move_dir[i] == 7 ? -1 : 0));
                    if (nx >= 0 && nx < 8 && ny >= 0 && ny < 8) begin
                        int collision = 0;
                        for (int j = 0; j < p2_count; j++) begin
                            if (i != j && p2_x[j] == nx && p2_y[j] == ny) begin
                                collision = 1;
                            end
                        end
                        if (!collision) begin
                            p2_x[i] <= nx;
                            p2_y[i] <= ny;
                        end
                    end
                end
            end
        end
    end

    // REGENERATE state: Heal Zerglings
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 16; i++) begin
                p1_hp[i] <= 0;
                p2_hp[i] <= 0;
            end
        end else if (state == REGENERATE) begin
            for (int i = 0; i < p1_count; i++) begin
                if (p1_hp[i] < 35) begin
                    p1_hp[i] <= p1_hp[i] + 1;
                end
            end
            for (int i = 0; i < p2_count; i++) begin
                if (p2_hp[i] < 35) begin
                    p2_hp[i] <= p2_hp[i] + 1;
                end
            end
        end
    end

    // NEXT_TURN state: Decrement turn counter
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            turn_counter <= 0;
        end else if (state == NEXT_TURN) begin
            turn_counter <= turn_counter - 1;
        end
    end

    // DONE state: Output final grid
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grid_out_00_to_07 <= 0;
            grid_out_08_to_15 <= 0;
            grid_out_16_to_23 <= 0;
            grid_out_24_to_31 <= 0;
            grid_out_32_to_39 <= 0;
            grid_out_40_to_47 <= 0;
            grid_out_48_to_55 <= 0;
            grid_out_56_to_63 <= 0;
        end else if (state == DONE) begin
            for (int y = 0; y < 8; y++) begin
                for (int x = 0; x < 8; x++) begin
                    int cell = 0;
                    for (int i = 0; i < p1_count; i++) begin
                        if (p1_x[i] == x && p1_y[i] == y) begin
                            cell = 1;
                        end
                    end
                    for (int i = 0; i < p2_count; i++) begin
                        if (p2_x[i] == x && p2_y[i] == y) begin
                            cell = 2;
                        end
                    end
                    case (y)
                        0: grid_out_00_to_07[x] <= cell;
                        1: grid_out_08_to_15[x] <= cell;
                        2: grid_out_16_to_23[x] <= cell;
                        3: grid_out_24_to_31[x] <= cell;
                        4: grid_out_32_to_39[x] <= cell;
                        5: grid_out_40_to_47[x] <= cell;
                        6: grid_out_48_to_55[x] <= cell;
                        7: grid_out_56_to_63[x] <= cell;
                    endcase
                end
            end
        end
    end

endmodule