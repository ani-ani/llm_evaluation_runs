module zergling_simulation (
    input clk,
    input rst_n,
    input start,
    input [23:0] grid_in_00_to_07,
    input [23:0] grid_in_08_to_15,
    input [23:0] grid_in_16_to_23,
    input [23:0] grid_in_24_to_31,
    input [23:0] grid_in_32_to_39,
    input [23:0] grid_in_40_to_47,
    input [23:0] grid_in_48_to_55,
    input [23:0] grid_in_56_to_63,
    input [3:0] p1_atk_up,
    input [3:0] p1_arm_up,
    input [3:0] p2_atk_up,
    input [3:0] p2_arm_up,
    input [7:0] num_turns,
    output reg [23:0] grid_out_00_to_07,
    output reg [23:0] grid_out_08_to_15,
    output reg [23:0] grid_out_16_to_23,
    output reg [23:0] grid_out_24_to_31,
    output reg [23:0] grid_out_32_to_39,
    output reg [23:0] grid_out_40_to_47,
    output reg [23:0] grid_out_48_to_55,
    output reg [23:0] grid_out_56_to_63,
    output reg done
);

    // Parameters
    parameter MAX_ZERGLINGS = 16;
    parameter GRID_SIZE = 8;
    parameter INIT_HP = 8'd35;
    parameter ATK_BASE = 5;
    
    // States
    localparam IDLE = 0;
    localparam LOAD = 1;
    localparam TURN_START = 2;
    localparam CHECK_ATTACK = 3;
    localparam EXECUTE_ATTACK = 4;
    localparam CHECK_MOVE = 5;
    localparam EXECUTE_MOVE = 6;
    localparam REGENERATE = 7;
    localparam NEXT_TURN = 8;
    localparam DONE = 9;

    // Direction offsets (N, NE, E, SE, S, SW, W, NW)
    // dx: -1, -1, 0, 1, 1, 1, 0, -1
    // dy: 0, -1, -1, -1, 0, 1, 1, 1
    wire signed [3:0] dx [0:7];
    wire signed [3:0] dy [0:7];
    assign dx[0] = 0;  assign dy[0] = -1;
    assign dx[1] = 1;  assign dy[1] = -1;
    assign dx[2] = 1;  assign dy[2] = 0;
    assign dx[3] = 1;  assign dy[3] = 1;
    assign dx[4] = 0;  assign dy[4] = 1;
    assign dx[5] = -1; assign dy[5] = 1;
    assign dx[6] = -1; assign dy[6] = 0;
    assign dx[7] = -1; assign dy[7] = -1;

    // Internal Registers
    reg [3:0] state, next_state;
    reg [7:0] turn_counter;
    reg [3:0] z_idx; // Index for iterating through zerglings
    reg [5:0] cell_idx; // Index for iterating through grid cells
    
    // Zergling Storage (Parallel Arrays)
    reg [5:0] p1_x [0:15];
    reg [5:0] p1_y [0:15];
    reg [7:0] p1_hp [0:15];
    reg p1_active [0:15];
    reg [3:0] p1_count;
    
    reg [5:0] p2_x [0:15];
    reg [5:0] p2_y [0:15];
    reg [7:0] p2_hp [0:15];
    reg p2_active [0:15];
    reg [3:0] p2_count;

    // Temporary Registers for Operations
    reg [2:0] attack_dir; 
    reg attack_found;
    reg [2:0] move_dir;
    reg move_found;
    reg [7:0] min_dist;
    
    // Attack/Move Decision Registers
    // We store decisions for all 16 zerglings of a player before execution
    reg [2:0] p1_dec_dir [0:15]; // 0-7, 3'bx if none
    reg p1_dec_attack [0:15];
    reg [2:0] p2_dec_dir [0:15];
    reg p2_dec_attack [0:15];
    
    // Collision Resolution / Move Target Registers
    // To resolve moves, we calculate target coordinates and check validity
    reg [5:0] p1_target_x [0:15];
    reg [5:0] p1_target_y [0:15];
    reg [5:0] p2_target_x [0:15];
    reg [5:0] p2_target_y [0:15];
    
    // Grid State for current turn (for reading neighbors)
    reg [2:0] grid_map [0:63]; // 0: empty, 1: P1, 2: P2
    reg [7:0] grid_hp [0:63]; // Store HP at grid cell (only valid if occupied)

    // Helper: Coord to Index
    function [5:0] xy2idx(input [2:0] x, input [2:0] y);
        xy2idx = {y, x};
    endfunction
    
    // Helper: Index to X/Y
    function [2:0] idx2x(input [5:0] idx);
        idx2x = idx[2:0];
    endfunction
    function [2:0] idx2y(input [5:0] idx);
        idx2y = idx[5:3];
    endfunction

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) state <= IDLE;
        else state <= next_state;
    end

    // Next State Logic & Main FSM
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            LOAD: next_state = TURN_START;
            TURN_START: begin
                if (p1_count == 0 || p2_count == 0 || turn_counter >= num_turns) next_state = DONE;
                else next_state = CHECK_ATTACK;
            end
            CHECK_ATTACK: begin
                // Iterate z_idx 0 to 15. Logic handled in sequential block.
                // Transition when done.
                if (z_idx == 5'd16) next_state = EXECUTE_ATTACK;
            end
            EXECUTE_ATTACK: next_state = CHECK_MOVE;
            CHECK_MOVE: begin
                if (z_idx == 5'd16) next_state = EXECUTE_MOVE;
            end
            EXECUTE_MOVE: next_state = REGENERATE;
            REGENERATE: next_state = NEXT_TURN;
            NEXT_TURN: next_state = TURN_START;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    // Datapath Logic
    integer i, j, k;
    reg [7:0] dmg;
    reg [2:0] best_dir;
    reg [7:0] current_dist;
    reg conflict;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            turn_counter <= 0;
            z_idx <= 0;
            cell_idx <= 0;
            p1_count <= 0;
            p2_count <= 0;
            // Clear arrays (optional but good practice)
            for (i = 0; i < 16; i = i + 1) begin
                p1_active[i] <= 0;
                p2_active[i] <= 0;
            end
            // Clear outputs
            {grid_out_00_to_07, grid_out_08_to_15, grid_out_16_to_23, grid_out_24_to_31,
             grid_out_32_to_39, grid_out_40_to_47, grid_out_48_to_55, grid_out_56_to_63} <= 0;
        end else begin
            case (state)
                LOAD: begin
                    // Populate grid_map from inputs
                    // Input format assumed: [2:0] for each cell, packed.
                    // grid_in_00_to_07[2:0] -> cell 0
                    // grid_in_00_to_07[5:3] -> cell 1 ...
                    // I will implement the unpacking logic here.
                    // Note: `grid_in_00_to_07` is treated as [23:0] in this corrected view.
                    
                    grid_map[0] <= grid_in_00_to_07[2:0];
                    grid_map[1] <= grid_in_00_to_07[5:3];
                    grid_map[2] <= grid_in_00_to_07[8:6];
                    grid_map[3] <= grid_in_00_to_07[11:9];
                    grid_map[4] <= grid_in_00_to_07[14:12];
                    grid_map[5] <= grid_in_00_to_07[17:15];
                    grid_map[6] <= grid_in_00_to_07[20:18];
                    grid_map[7] <= grid_in_00_to_07[23:21];
                    
                    grid_map[8] <= grid_in_08_to_15[2:0];
                    grid_map[9] <= grid_in_08_to_15[5:3];
                    grid_map[10] <= grid_in_08_to_15[8:6];
                    grid_map[11] <= grid_in_08_to_15[11:9];
                    grid_map[12] <= grid_in_08_to_15[14:12];
                    grid_map[13] <= grid_in_08_to_15[17:15];
                    grid_map[14] <= grid_in_08_to_15[20:18];
                    grid_map[15] <= grid_in_08_to_15[23:21];

                    grid_map[16] <= grid_in_16_to_23[2:0];
                    grid_map[17] <= grid_in_16_to_23[5:3];
                    grid_map[18] <= grid_in_16_to_23[8:6];
                    grid_map[19] <= grid_in_16_to_23[11:9];
                    grid_map[20] <= grid_in_16_to_23[14:12];
                    grid_map[21] <= grid_in_16_to_23[17:15];
                    grid_map[22] <= grid_in_16_to_23[20:18];
                    grid_map[23] <= grid_in_16_to_23[23:21];

                    grid_map[24] <= grid_in_24_to_31[2:0];
                    grid_map[25] <= grid_in_24_to_31[5:3];
                    grid_map[26] <= grid_in_24_to_31[8:6];
                    grid_map[27] <= grid_in_24_to_31[11:9];
                    grid_map[28] <= grid_in_24_to_31[14:12];
                    grid_map[29] <= grid_in_24_to_31[17:15];
                    grid_map[30] <= grid_in_24_to_31[20:18];
                    grid_map[31] <= grid_in_24_to_31[23:21];

                    grid_map[32] <= grid_in_32_to_39[2:0];
                    grid_map[33] <= grid_in_32_to_39[5:3];
                    grid_map[34] <= grid_in_32_to_39[8:6];
                    grid_map[35] <= grid_in_32_to_39[11:9];
                    grid_map[36] <= grid_in_32_to_39[14:12];
                    grid_map[37] <= grid_in_32_to_39[17:15];
                    grid_map[38] <= grid_in_32_to_39[20:18];
                    grid_map[39] <= grid_in_32_to_39[23:21];

                    grid_map[40] <= grid_in_40_to_47[2:0];
                    grid_map[41] <= grid_in_40_to_47[5:3];
                    grid_map[42] <= grid_in_40_to_47[8:6];
                    grid_map[43] <= grid_in_40_to_47[11:9];
                    grid_map[44] <= grid_in_40_to_47[14:12];
                    grid_map[45] <= grid_in_40_to_47[17:15];
                    grid_map[46] <= grid_in_40_to_47[20:18];
                    grid_map[47] <= grid_in_40_to_47[23:21];

                    grid_map[48] <= grid_in_48_to_55[2:0];
                    grid_map[49] <= grid_in_48_to_55[5:3];
                    grid_map[50] <= grid_in_48_to_55[8:6];
                    grid_map[51] <= grid_in_48_to_55[11:9];
                    grid_map[52] <= grid_in_48_to_55[14:12];
                    grid_map[53] <= grid_in_48_to_55[17:15];
                    grid_map[54] <= grid_in_48_to_55[20:18];
                    grid_map[55] <= grid_in_48_to_55[23:21];

                    grid_map[56] <= grid_in_56_to_63[2:0];
                    grid_map[57] <= grid_in_56_to_63[5:3];
                    grid_map[58] <= grid_in_56_to_63[8:6];
                    grid_map[59] <= grid_in_56_to_63[11:9];
                    grid_map[60] <= grid_in_56_to_63[14:12];
                    grid_map[61] <= grid_in_56_to_63[17:15];
                    grid_map[62] <= grid_in_56_to_63[20:18];
                    grid_map[63] <= grid_in_56_to_63[23:21];
                    
                    // Initialize storage
                    // We will populate p1/p2 arrays in TURN_START based on grid_map
                end

                TURN_START: begin
                    // Reconstruct p1/p2 arrays from grid_map (or keep existing if not first turn)
                    // For simulation, we rebuild arrays from grid_map if start signal was recent?
                    // But the prompt says "LOAD: Parse grid_in".
                    // We should do the parsing in LOAD or here.
                    // Let's do it in TURN_START to reset units.
                    
                    // We need to iterate grid_map and populate p1/p2 arrays.
                    // Use cell_idx (0 to 63).
                    if (cell_idx == 0) begin
                        // Reset counts
                        // Actually, we need to clear p1/p2 active flags first? 
                        // If it's the first turn, yes. If subsequent, we just update positions?
                        // No, "LOAD" implies fresh state.
                        // But the state machine goes LOAD -> TURN_START.
                        // LOAD populates grid_map.
                        // TURN_START populates HP arrays.
                        
                        // Let's assume we only populate HP arrays ONCE at the very beginning.
                        // But `start` goes to LOAD.
                        // We need to distinguish "First Load" vs "Reusing state".
                        // The prompt says "LOAD: Parse grid_in". This implies filling HP arrays.
                        // So, let's do it in LOAD state.
                    end
                end

            endcase
        end
    end
    
    // Combinational Logic for Next State and Data Path
    // (Merged into the always block for brevity in synthesis, but separated logically here)
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = LOAD;
            LOAD: next_state = TURN_START; // We do parsing in LOAD sequential block
            TURN_START: begin
                if (turn_counter >= num_turns) next_state = DONE;
                // Check if anyone is alive
                else if (p1_count == 0 || p2_count == 0) next_state = DONE;
                else next_state = CHECK_ATTACK;
            end
            CHECK_ATTACK: if (z_idx == 16) next_state = EXECUTE_ATTACK;
            EXECUTE_ATTACK: next_state = CHECK_MOVE;
            CHECK_MOVE: if (z_idx == 16) next_state = EXECUTE_MOVE;
            EXECUTE_MOVE: next_state = REGENERATE;
            REGENERATE: next_state = NEXT_TURN;
            NEXT_TURN: next_state = TURN_START;
            DONE: next_state = DONE;
        endcase
    end

    // Logic Completion in separate always block to avoid density issues
    integer i, j;
    reg [7:0] dist, min_d;
    reg [2:0] dir;
    reg found;
    reg signed [7:0] diff_x, diff_y;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset Logic (Already handled in combined block, but needed for state transitions)
        end else begin
            case (state)
                LOAD: begin
                    // Populate HP arrays from grid_map
                    p1_count <= 0;
                    p2_count <= 0;
                    for (i = 0; i < 64; i = i + 1) begin
                        if (grid_map[i] == 1) begin
                            if (p1_count < 16) begin
                                p1_x[p1_count] <= i[2:0];
                                p1_y[p1_count] <= i[5:3];
                                p1_hp[p1_count] <= INIT_HP;
                                p1_active[p1_count] <= 1;
                                p1_count <= p1_count + 1;
                            end
                        end else if (grid_map[i] == 2) begin
                            if (p2_count < 16) begin
                                p2_x[p2_count] <= i[2:0];
                                p2_y[p2_count] <= i[5:3];
                                p2_hp[p2_count] <= INIT_HP;
                                p2_active[p2_count] <= 1;
                                p2_count <= p2_count + 1;
                            end
                        end
                    end
                end

                TURN_START: begin
                    z_idx <= 0;
                    cell_idx <= 0;
                    // Rebuild grid_map from current positions (since moves/attacks changed it)
                    // Actually, grid_map is maintained during moves.
                    // We just need to make sure it's consistent.
                    // At the end of REGENERATE, we removed dead units from grid_map.
                    // So grid_map is good for next turn CHECK_ATTACK.
                    // Just need to increment turn.
                end

                CHECK_ATTACK: begin
                    if (z_idx < 16) begin
                        // P1
                        if (p1_active[z_idx]) begin
                            found = 0;
                            dir = 0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!found) begin
                                    if (p1_x[z_idx] + dx[i] >= 0 && p1_x[z_idx] + dx[i] < 8 &&
                                        p1_y[z_idx] + dy[i] >= 0 && p1_y[z_idx] + dy[i] < 8) begin
                                        if (grid_map[xy2idx(p1_x[z_idx] + dx[i], p1_y[z_idx] + dy[i])] == 2) begin
                                            found = 1;
                                            dir = i[2:0];
                                        end
                                    end
                                end
                            end
                            p1_dec_attack[z_idx] <= found;
                            p1_dec_dir[z_idx] <= dir;
                        end
                        // P2
                        if (p2_active[z_idx]) begin
                            found = 0;
                            dir = 0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (!found) begin
                                    if (p2_x[z_idx] + dx[i] >= 0 && p2_x[z_idx] + dx[i] < 8 &&
                                        p2_y[z_idx] + dy[i] >= 0 && p2_y[z_idx] + dy[i] < 8) begin
                                        if (grid_map[xy2idx(p2_x[z_idx] + dx[i], p2_y[z_idx] + dy[i])] == 1) begin
                                            found = 1;
                                            dir = i[2:0];
                                        end
                                    end
                                end
                            end
                            p2_dec_attack[z_idx] <= found;
                            p2_dec_dir[z_idx] <= dir;
                        end
                        z_idx <= z_idx + 1;
                    end
                end

                EXECUTE_ATTACK: begin
                    // Apply damage
                    // We iterate through all active units.
                    // To avoid double counting, we apply damage to victims immediately.
                    // Since we iterate P1 then P2, we must be careful.
                    // If P1 attacks P2, we subtract P2 HP.
                    // If P2 attacks P1, we subtract P1 HP.
                    // Since P1 attacks are calculated and P2 attacks are calculated, we can just loop.
                    
                    // Let's use cell_idx to iterate 0-15 (P1), then 16-31 (P2)
                    if (cell_idx < 16) begin
                        if (p1_active[cell_idx] && p1_dec_attack[cell_idx]) begin
                            // Find victim
                            for (i = 0; i < 16; i = i + 1) begin
                                if (p2_active[i]) begin
                                    if (p2_x[i] == p1_x[cell_idx] + dx[p1_dec_dir[cell_idx]] && 
                                        p2_y[i] == p1_y[cell_idx] + dy[p1_dec_dir[cell_idx]]) begin
                                        // Hit
                                        if (p1_hp[cell_idx] > 0) begin // Attacker alive?
                                            // Dmg calculation
                                            if (ATK_BASE + p1_atk_up > p2_arm_up) begin
                                                if (p2_hp[i] > (ATK_BASE + p1_atk_up - p2_arm_up)) 
                                                    p2_hp[i] <= p2_hp[i] - (ATK_BASE + p1_atk_up - p2_arm_up);
                                                else 
                                                    p2_hp[i] <= 0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        cell_idx <= cell_idx + 1;
                    end else if (cell_idx < 32) begin
                        if (p2_active[cell_idx-16] && p2_dec_attack[cell_idx-16]) begin
                            // Find victim
                            for (i = 0; i < 16; i = i + 1) begin
                                if (p1_active[i]) begin
                                    if (p1_x[i] == p2_x[cell_idx-16] + dx[p2_dec_dir[cell_idx-16]] && 
                                        p1_y[i] == p2_y[cell_idx-16] + dy[p2_dec_dir[cell_idx-16]]) begin
                                        // Hit
                                        if (p2_hp[cell_idx-16] > 0) begin
                                            if (ATK_BASE + p2_atk_up > p1_arm_up) begin
                                                if (p1_hp[i] > (ATK_BASE + p2_atk_up - p1_arm_up)) 
                                                    p1_hp[i] <= p1_hp[i] - (ATK_BASE + p2_atk_up - p1_arm_up);
                                                else 
                                                    p1_hp[i] <= 0;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                        cell_idx <= cell_idx + 1;
                    end
                end

                CHECK_MOVE: begin
                    if (z_idx < 16) begin
                        // P1
                        if (p1_active[z_idx] && !p1_dec_attack[z_idx]) begin
                            min_d = 255;
                            found = 0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (p1_x[z_idx] + dx[i] >= 0 && p1_x[z_idx] + dx[i] < 8 &&
                                    p1_y[z_idx] + dy[i] >= 0 && p1_y[z_idx] + dy[i] < 8) begin
                                    if (grid_map[xy2idx(p1_x[z_idx] + dx[i], p1_y[z_idx] + dy[i])] == 0) begin
                                        // Calc dist to nearest P2
                                        dist = 255;
                                        for (j = 0; j < 16; j = j + 1) begin
                                            if (p2_active[j]) begin
                                                diff_x = p1_x[z_idx] + dx[i] - p2_x[j];
                                                diff_y = p1_y[z_idx] + dy[i] - p2_y[j];
                                                if (abs_val(diff_x) + abs_val(diff_y) < dist) 
                                                    dist = abs_val(diff_x) + abs_val(diff_y);
                                            end
                                        end
                                        if (dist < min_d) begin
                                            min_d = dist;
                                            dir = i[2:0];
                                            found = 1;
                                        end
                                    end
                                end
                            end
                            if (found) begin
                                p1_dec_dir[z_idx] <= dir;
                                p1_dec_attack[z_idx] <= 0;
                            end else begin
                                p1_dec_attack[z_idx] <= 1; // Mark as no-move/invalid to skip
                            end
                        end
                        
                        // P2
                        if (p2_active[z_idx] && !p2_dec_attack[z_idx]) begin
                            min_d = 255;
                            found = 0;
                            for (i = 0; i < 8; i = i + 1) begin
                                if (p2_x[z_idx] + dx[i] >= 0 && p2_x[z_idx] + dx[i] < 8 &&
                                    p2_y[z_idx] + dy[i] >= 0 && p2_y[z_idx] + dy[i] < 8) begin
                                    if (grid_map[xy2idx(p2_x[z_idx] + dx[i], p2_y[z_idx] + dy[i])] == 0) begin
                                        dist = 255;
                                        for (j = 0; j < 16; j = j + 1) begin
                                            if (p1_active[j]) begin
                                                diff_x = p2_x[z_idx] + dx[i] - p1_x[j];
                                                diff_y = p2_y[z_idx] + dy[i] - p1_y[j];
                                                if (abs_val(diff_x) + abs_val(diff_y) < dist) 
                                                    dist = abs_val(diff_x) + abs_val(diff_y);
                                            end
                                        end
                                        if (dist < min_d) begin
                                            min_d = dist;
                                            dir = i[2:0];
                                            found = 1;
                                        end
                                    end
                                end
                            end
                            if (found) begin
                                p2_dec_dir[z_idx] <= dir;
                                p2_dec_attack[z_idx] <= 0;
                            end else begin
                                p2_dec_attack[z_idx] <= 1;
                            end
                        end
                        z_idx <= z_idx + 1;
                    end
                end

                EXECUTE_MOVE: begin
                    // Sequential greedy move with grid_map update
                    if (z_idx < 16) begin
                        // P1
                        if (p1_active[z_idx] && !p1_dec_attack[z_idx] && p1_dec_dir[z_idx] < 8) begin
                            // Check if target is free in grid_map (which tracks current state)
                            if (grid_map[xy2idx(p1_x[z_idx] + dx[p1_dec_dir[z_idx]], p1_y[z_idx] + dy[p1_dec_dir[z_idx]])] == 0) begin
                                // Update grid_map: clear old, set new
                                grid_map[xy2idx(p1_x[z_idx], p1_y[z_idx])] <= 0;
                                grid_map[xy2idx(p1_x[z_idx] + dx[p1_dec_dir[z_idx]], p1_y[z_idx] + dy[p1_dec_dir[z_idx]])] <= 1;
                                // Update pos
                                p1_x[z_idx] <= p1_x[z_idx] + dx[p1_dec_dir[z_idx]];
                                p1_y[z_idx] <= p1_y[z_idx] + dy[p1_dec_dir[z_idx]];
                            end
                        end
                        // P2 (offset 16)
                        if (z_idx < 16) begin // Wait, we need to iterate P2 separately or increment z_idx to 32
                           // Let's handle P2 in next block or separate index
                        end
                        
                        // To handle P1 and P2 in one z_idx loop:
                        // We can do z_idx 0..15 for P1, then 16..31 for P2.
                        // But we only incremented z_idx to 16 in CHECK_MOVE.
                        // So in EXECUTE_MOVE, we start from 0 again? 
                        // No, CHECK_MOVE sets z_idx=16. EXECUTE_MOVE sees z_idx=16.
                        // We should iterate 0..15 here.
                        // We need to reset z_idx or use cell_idx.
                        // Let's use cell_idx.
                        if (cell_idx < 16) begin
                            if (p1_active[cell_idx] && !p1_dec_attack[cell_idx] && p1_dec_dir[cell_idx] < 8) begin
                                if (grid_map[xy2idx(p1_x[cell_idx] + dx[p1_dec_dir[cell_idx]], p1_y[cell_idx] + dy[p1_dec_dir[cell_idx]])] == 0) begin
                                    grid_map[xy2idx(p1_x[cell_idx], p1_y[cell_idx])] <= 0;
                                    grid_map[xy2idx(p1_x[cell_idx] + dx[p1_dec_dir[cell_idx]], p1_y[cell_idx] + dy[p1_dec_dir[cell_idx]])] <= 1;
                                    p1_x[cell_idx] <= p1_x[cell_idx] + dx[p1_dec_dir[cell_idx]];
                                    p1_y[cell_idx] <= p1_y[cell_idx] + dy[p1_dec_dir[cell_idx]];
                                end
                            end
                            cell_idx <= cell_idx + 1;
                        end else if (cell_idx < 32) begin
                            // P2
                            if (p2_active[cell_idx-16] && !p2_dec_attack[cell_idx-16] && p2_dec_dir[cell_idx-16] < 8) begin
                                if (grid_map[xy2idx(p2_x[cell_idx-16] + dx[p2_dec_dir[cell_idx-16]], p2_y[cell_idx-16] + dy[p2_dec_dir[cell_idx-16]])] == 0) begin
                                    grid_map[xy2idx(p2_x[cell_idx-16], p2_y[cell_idx-16])] <= 0;
                                    grid_map[xy2idx(p2_x[cell_idx-16] + dx[p2_dec_dir[cell_idx-16]], p2_y[cell_idx-16] + dy[p2_dec_dir[cell_idx-16]])] <= 2;
                                    p2_x[cell_idx-16] <= p2_x[cell_idx-16] + dx[p2_dec_dir[cell_idx-16]];
                                    p2_y[cell_idx-16] <= p2_y[cell_idx-16] + dy[p2_dec_dir[cell_idx-16]];
                                end
                            end
                            cell_idx <= cell_idx + 1;
                        end
                    end
                end

                REGENERATE: begin
                    if (cell_idx < 16) begin
                        if (p1_active[cell_idx]) begin
                            if (p1_hp[cell_idx] <= 0) begin
                                p1_active[cell_idx] <= 0;
                                grid_map[xy2idx(p1_x[cell_idx], p1_y[cell_idx])] <= 0;
                            end else if (p1_hp[cell_idx] < INIT_HP) begin
                                p1_hp[cell_idx] <= p1_hp[cell_idx] + 1;
                            end
                        end
                        cell_idx <= cell_idx + 1;
                    end else if (cell_idx < 32) begin
                        if (p2_active[cell_idx-16]) begin
                            if (p2_hp[cell_idx-16] <= 0) begin
                                p2_active[cell_idx-16] <= 0;
                                grid_map[xy2idx(p2_x[cell_idx-16], p2_y[cell_idx-16])] <= 0;
                            end else if (p2_hp[cell_idx-16] < INIT_HP) begin
                                p2_hp[cell_idx-16] <= p2_hp[cell_idx-16] + 1;
                            end
                        end
                        cell_idx <= cell_idx + 1;
                    end
                end

                NEXT_TURN: begin
                    turn_counter <= turn_counter + 1;
                    z_idx <= 0;
                    cell_idx <= 0;
                    // Update counts
                    p1_count <= 0;
                    p2_count <= 0;
                    for (i = 0; i < 16; i = i + 1) begin
                        if (p1_active[i]) p1_count <= p1_count + 1;
                        if (p2_active[i]) p2_count <= p2_count + 1;
                    end
                end

                DONE: begin
                    done <= 1;
                    // Pack grid_map to outputs
                    grid_out_00_to_07 <= {grid_map[7], grid_map[6], grid_map[5], grid_map[4], grid_map[3], grid_map[2], grid_map[1], grid_map[0]};
                    grid_out_08_to_15 <= {grid_map[15], grid_map[14], grid_map[13], grid_map[12], grid_map[11], grid_map[10], grid_map[9], grid_map[8]};
                    grid_out_16_to_23 <= {grid_map[23], grid_map[22], grid_map[21], grid_map[20], grid_map[19], grid_map[18], grid_map[17], grid_map[16]};
                    grid_out_24_to_31 <= {grid_map[31], grid_map[30], grid_map[29], grid_map[28], grid_map[27], grid_map[26], grid_map[25], grid_map[24]};
                    grid_out_32_to_39 <= {grid_map[39], grid_map[38], grid_map[37], grid_map[36], grid_map[35], grid_map[34], grid_map[33], grid_map[32]};
                    grid_out_40_to_47 <= {grid_map[47], grid_map[46], grid_map[45], grid_map[44], grid_map[43], grid_map[42], grid_map[41], grid_map[40]};
                    grid_out_48_to_55 <= {grid_map[55], grid_map[54], grid_map[53], grid_map[52], grid_map[51], grid_map[50], grid_map[49], grid_map[48]};
                    grid_out_56_to_63 <= {grid_map[63], grid_map[62], grid_map[61], grid_map[60], grid_map[59], grid_map[58], grid_map[57], grid_map[56]};
                end
            endcase
        end
    end

endmodule
