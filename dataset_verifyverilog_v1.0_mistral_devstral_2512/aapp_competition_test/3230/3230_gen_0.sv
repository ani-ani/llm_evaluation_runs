module tram_explosion #(
    parameter MAX_R = 4,
    parameter MAX_C = 4,
    parameter MAX_X = 4,
    parameter MAX_L = 4,
    parameter CLK_LIMIT = 100
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [MAX_R*MAX_C*2-1:0] grid,
    output reg [3:0] explosions,
    output reg done
);

// State definitions
localparam [3:0] IDLE = 4'd0;
localparam [3:0] INIT = 4'd1;
localparam [3:0] FIND_CLOSEST = 4'd2;
localparam [3:0] CHECK_CONFLICTS = 4'd3;
localparam [3:0] RESOLVE_EXPLOSIONS = 4'd4;
localparam [3:0] RESOLVE_SEATING = 4'd5;
localparam [3:0] UPDATE_GRID = 4'd6;
localparam [3:0] CHECK_IF_MORE_ROUNDS = 4'd7;
localparam [3:0] DONE = 4'd8;

reg [3:0] state, next_state;
reg [3:0] explosion_cnt, next_explosion_cnt;
reg [7:0] clock_counter, next_clock_counter;
reg [MAX_R*MAX_C*2-1:0] current_grid, next_current_grid;

// X and L positions and counts
reg [3:0] x_pos [0:MAX_X-1];
reg [2:0] x_count, next_x_count;
reg [3:0] l_pos [0:MAX_L-1];
reg [2:0] l_count, next_l_count;

// For current round: for each X, closest L and distance
reg [3:0] x_target_l [0:MAX_X-1];
reg [15:0] x_target_dist [0:MAX_X-1];

// For each L, list of X targeting it (bitmask)
reg [MAX_X-1:0] l_target_mask [0:MAX_L-1];
reg [15:0] l_target_min_dist [0:MAX_L-1];

// Helper function to get cell value
function [1:0] get_cell;
    input [MAX_R*MAX_C*2-1:0] grid_val;
    input [5:0] index;
    begin
        get_cell = grid_val[index*2 +: 2];
    end
endfunction

// Helper function to compute squared distance
function [15:0] compute_dist;
    input [3:0] pos1, pos2;
    integer r1, c1, r2, c2;
    begin
        r1 = pos1 / MAX_C;
        c1 = pos1 % MAX_C;
        r2 = pos2 / MAX_C;
        c2 = pos2 % MAX_C;
        compute_dist = (r1 - r2)*(r1 - r2) + (c1 - c2)*(c1 - c2);
    end
endfunction

integer i, j, k;

// State register
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        explosion_cnt <= 4'd0;
        clock_counter <= 8'd0;
        current_grid <= {MAX_R*MAX_C*2{1'b0}};
        x_count <= 3'd0;
        l_count <= 3'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;
        explosion_cnt <= next_explosion_cnt;
        clock_counter <= next_clock_counter;
        current_grid <= next_current_grid;
        x_count <= next_x_count;
        l_count <= next_l_count;
    end
end

// Next state and datapath
always @(*) begin
    next_state = state;
    next_explosion_cnt = explosion_cnt;
    next_clock_counter = clock_counter + 8'd1;
    next_current_grid = current_grid;
    next_x_count = x_count;
    next_l_count = l_count;
    
    done = 1'b0;
    
    case (state)
        IDLE: begin
            next_clock_counter = 8'd0;
            next_explosion_cnt = 4'd0;
            if (start) begin
                next_current_grid = grid;
                next_state = INIT;
            end
        end
        
        INIT: begin
            // Extract X and L positions from current_grid
            next_x_count = 3'd0;
            next_l_count = 3'd0;
            for (i = 0; i < MAX_R*MAX_C; i = i + 1) begin
                if (get_cell(current_grid, i) == 2'b01 && next_x_count < MAX_X) begin
                    x_pos[next_x_count] = i;
                    next_x_count = next_x_count + 3'd1;
                end else if (get_cell(current_grid, i) == 2'b10 && next_l_count < MAX_L) begin
                    l_pos[next_l_count] = i;
                    next_l_count = next_l_count + 3'd1;
                end
            end
            next_state = FIND_CLOSEST;
        end
        
        FIND_CLOSEST: begin
            // For each X, find the closest L
            for (i = 0; i < MAX_X; i = i + 1) begin
                if (i < x_count) begin
                    x_target_dist[i] = 16'hFFFF;
                    x_target_l[i] = 4'd0;
                    for (j = 0; j < MAX_L; j = j + 1) begin
                        if (j < l_count) begin
                            if (compute_dist(x_pos[i], l_pos[j]) < x_target_dist[i]) begin
                                x_target_dist[i] = compute_dist(x_pos[i], l_pos[j]);
                                x_target_l[i] = j;
                            end
                        end
                    end
                end
            end
            next_state = CHECK_CONFLICTS;
        end
        
        CHECK_CONFLICTS: begin
            // Initialize l_target_mask and l_target_min_dist
            for (j = 0; j < MAX_L; j = j + 1) begin
                l_target_mask[j] = {MAX_X{1'b0}};
                l_target_min_dist[j] = 16'hFFFF;
            end
            // For each X, add to its target L's mask
            for (i = 0; i < x_count; i = i + 1) begin
                j = x_target_l[i];
                l_target_mask[j] = l_target_mask[j] | (1 << i);
                if (x_target_dist[i] < l_target_min_dist[j]) begin
                    l_target_min_dist[j] = x_target_dist[i];
                end
            end
            next_state = RESOLVE_EXPLOSIONS;
        end
        
        RESOLVE_EXPLOSIONS: begin
            // Check for explosions
            for (j = 0; j < l_count; j = j + 1) begin
                integer x_count_for_l = 0;
                reg [MAX_X-1:0] mask = l_target_mask[j];
                for (i = 0; i < MAX_X; i = i + 1) begin
                    if (mask[i]) x_count_for_l = x_count_for_l + 1;
                end
                if (x_count_for_l >= 2) begin
                    integer all_equal = 1;
                    for (i = 0; i < MAX_X; i = i + 1) begin
                        if (mask[i] && x_target_dist[i] != l_target_min_dist[j]) begin
                            all_equal = 0;
                        end
                    end
                    if (all_equal) begin
                        next_explosion_cnt = explosion_cnt + 4'd1;
                    end
                end
            end
            next_state = RESOLVE_SEATING;
        end
        
        RESOLVE_SEATING: begin
            // Resolve seating and update counts
            reg [MAX_X-1:0] removed_x;
            reg [MAX_L-1:0] removed_l;
            removed_x = {MAX_X{1'b0}};
            removed_l = {MAX_L{1'b0}};
            
            for (j = 0; j < l_count; j = j + 1) begin
                integer x_count_for_l = 0;
                reg [MAX_X-1:0] mask = l_target_mask[j];
                for (i = 0; i < MAX_X; i = i + 1) begin
                    if (mask[i]) x_count_for_l = x_count_for_l + 1;
                end
                if (x_count_for_l >= 2) begin
                    integer all_equal = 1;
                    for (i = 0; i < MAX_X; i = i + 1) begin
                        if (mask[i] && x_target_dist[i] != l_target_min_dist[j]) begin
                            all_equal = 0;
                        end
                    end
                    if (all_equal) begin
                        // Explosion: remove all X in mask and this L
                        for (i = 0; i < MAX_X; i = i + 1) begin
                            if (mask[i]) removed_x[i] = 1'b1;
                        end
                        removed_l[j] = 1'b1;
                    end else begin
                        // No explosion: find unique closest X
                        integer winner_i = -1;
                        integer winner_count = 0;
                        for (i = 0; i < MAX_X; i = i + 1) begin
                            if (mask[i] && x_target_dist[i] == l_target_min_dist[j]) begin
                                winner_i = i;
                                winner_count = winner_count + 1;
                            end
                        end
                        if (winner_count == 1) begin
                            removed_x[winner_i] = 1'b1;
                            removed_l[j] = 1'b1;
                        end
                    end
                end else if (x_count_for_l == 1) begin
                    for (i = 0; i < MAX_X; i = i + 1) begin
                        if (mask[i]) begin
                            removed_x[i] = 1'b1;
                            removed_l[j] = 1'b1;
                            break;
                        end
                    end
                end
            end
            
            // Update counts
            next_x_count = 3'd0;
            next_l_count = 3'd0;
            for (i = 0; i < x_count; i = i + 1) begin
                if (!removed_x[i]) begin
                    x_pos[next_x_count] = x_pos[i];
                    next_x_count = next_x_count + 3'd1;
                end
            end
            for (j = 0; j < l_count; j = j + 1) begin
                if (!removed_l[j]) begin
                    l_pos[next_l_count] = l_pos[j];
                    next_l_count = next_l_count + 3'd1;
                end
            end
            next_state = UPDATE_GRID;
        end
        
        UPDATE_GRID: begin
            // Update grid (simplified: we don't need to track exact grid for counting)
            next_state = CHECK_IF_MORE_ROUNDS;
        end
        
        CHECK_IF_MORE_ROUNDS: begin
            if (next_x_count > 3'd0 && next_l_count > 3'd0 && clock_counter < CLK_LIMIT - 1) begin
                next_state = FIND_CLOSEST;
            end else begin
                next_state = DONE;
            end
        end
        
        DONE: begin
            done = 1'b1;
            next_state = IDLE;
        end
        
        default: next_state = IDLE;
    endcase
    
    if (clock_counter >= CLK_LIMIT) begin
        next_state = DONE;
    end
end

// Output explosion count
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        explosions <= 4'd0;
    end else begin
        if (state == DONE) begin
            explosions <= explosion_cnt;
        end
    end
end

endmodule