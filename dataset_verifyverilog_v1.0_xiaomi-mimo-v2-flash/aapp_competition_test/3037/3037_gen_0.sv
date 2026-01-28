module MrTurtle (
    input clk,
    input rst_n,
    input start,
    input [1:0] cmd_dir0, cmd_dir1, cmd_dir2, cmd_dir3, cmd_dir4,
    input [7:0] cmd_dist0, cmd_dist1, cmd_dist2, cmd_dist3, cmd_dist4,
    input [47:0] target_grid,
    output reg [7:0] min_time,
    output reg [7:0] max_time,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] GEN_PATH  = 3'd1;
    localparam [2:0] CHECK_T   = 3'd2;
    localparam [2:0] FIND_EXT  = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    reg [2:0] state, next_state;
    
    // Path generation registers
    reg [6:0] path_len;          // Max 100 steps
    reg [5:0] x_coord, y_coord;  // 6x8 grid
    reg [2:0] cmd_idx;           // 0-4
    reg [7:0] dist_rem;          // Current distance remaining
    
    // Path storage (100 steps max, packed: {y[2:0], x[2:0]} 6 bits per coord)
    reg [5:0] path_x [0:99];
    reg [5:0] path_y [0:99];
    
    // Comparison registers
    reg [7:0] current_t;
    reg [7:0] min_t_reg;
    reg [7:0] max_t_reg;
    reg match_found;
    reg match_current;
    
    // Grid computation registers
    reg [47:0] marked_grid;
    reg [6:0] step_idx;
    
    // Cycle counter for safety
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd500;
    
    integer i;

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = GEN_PATH;
            end
            GEN_PATH: begin
                if (path_len == 100 || (cmd_idx == 5 && dist_rem == 0)) begin
                    next_state = CHECK_T;
                end else begin
                    next_state = GEN_PATH;
                end
            end
            CHECK_T: begin
                if (current_t > path_len) begin
                    if (match_found) next_state = FIND_EXT;
                    else next_state = FINISH;
                end else begin
                    next_state = CHECK_T;
                end
            end
            FIND_EXT: begin
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // State transition and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            min_time <= 8'd0;
            max_time <= 8'd0;
            valid <= 1'b0;
            done <= 1'b0;
            path_len <= 7'd0;
            x_coord <= 6'd0;
            y_coord <= 6'd5;
            cmd_idx <= 3'd0;
            dist_rem <= 8'd0;
            current_t <= 8'd0;
            min_t_reg <= 8'd0;
            max_t_reg <= 8'd0;
            match_found <= 1'b0;
            match_current <= 1'b0;
            marked_grid <= 48'd0;
            step_idx <= 7'd0;
            cycle_count <= 10'd0;
            for (i = 0; i < 100; i = i + 1) begin
                path_x[i] <= 6'd0;
                path_y[i] <= 6'd0;
            end
        end else begin
            cycle_count <= cycle_count + 10'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 10'd0;
                    if (start) begin
                        path_len <= 7'd0;
                        x_coord <= 6'd0;
                        y_coord <= 6'd5;
                        cmd_idx <= 3'd0;
                        dist_rem <= 8'd0;
                        current_t <= 8'd0;
                        match_found <= 1'b0;
                        for (i = 0; i < 100; i = i + 1) begin
                            path_x[i] <= 6'd0;
                            path_y[i] <= 6'd0;
                        end
                    end
                end
                
                GEN_PATH: begin
                    if (dist_rem == 0 && cmd_idx < 5) begin
                        // Load next command
                        case (cmd_idx)
                            3'd0: dist_rem <= cmd_dist0;
                            3'd1: dist_rem <= cmd_dist1;
                            3'd2: dist_rem <= cmd_dist2;
                            3'd3: dist_rem <= cmd_dist3;
                            3'd4: dist_rem <= cmd_dist4;
                        endcase
                        cmd_idx <= cmd_idx + 3'd1;
                    end
                    
                    if (dist_rem > 0 && path_len < 100) begin
                        // Store current position
                        path_x[path_len] <= x_coord;
                        path_y[path_len] <= y_coord;
                        path_len <= path_len + 7'd1;
                        
                        // Move
                        case (cmd_idx)
                            3'd1: begin
                                case (cmd_dir0)
                                    2'd0: if (y_coord > 0) y_coord <= y_coord - 6'd1;
                                    2'd1: if (y_coord < 5) y_coord <= y_coord + 6'd1;
                                    2'd2: if (x_coord > 0) x_coord <= x_coord - 6'd1;
                                    2'd3: if (x_coord < 7) x_coord <= x_coord + 6'd1;
                                endcase
                            end
                            3'd2: begin
                                case (cmd_dir1)
                                    2'd0: if (y_coord > 0) y_coord <= y_coord - 6'd1;
                                    2'd1: if (y_coord < 5) y_coord <= y_coord + 6'd1;
                                    2'd2: if (x_coord > 0) x_coord <= x_coord - 6'd1;
                                    2'd3: if (x_coord < 7) x_coord <= x_coord + 6'd1;
                                endcase
                            end
                            3'd3: begin
                                case (cmd_dir2)
                                    2'd0: if (y_coord > 0) y_coord <= y_coord - 6'd1;
                                    2'd1: if (y_coord < 5) y_coord <= y_coord + 6'd1;
                                    2'd2: if (x_coord > 0) x_coord <= x_coord - 6'd1;
                                    2'd3: if (x_coord < 7) x_coord <= x_coord + 6'd1;
                                endcase
                            end
                            3'd4: begin
                                case (cmd_dir3)
                                    2'd0: if (y_coord > 0) y_coord <= y_coord - 6'd1;
                                    2'd1: if (y_coord < 5) y_coord <= y_coord + 6'd1;
                                    2'd2: if (x_coord > 0) x_coord <= x_coord - 6'd1;
                                    2'd3: if (x_coord < 7) x_coord <= x_coord + 6'd1;
                                endcase
                            end
                            3'd5: begin
                                case (cmd_dir4)
                                    2'd0: if (y_coord > 0) y_coord <= y_coord - 6'd1;
                                    2'd1: if (y_coord < 5) y_coord <= y_coord + 6'd1;
                                    2'd2: if (x_coord > 0) x_coord <= x_coord - 6'd1;
                                    2'd3: if (x_coord < 7) x_coord <= x_coord + 6'd1;
                                endcase
                            end
                        endcase
                        dist_rem <= dist_rem - 8'd1;
                    end
                end
                
                CHECK_T: begin
                    if (current_t <= path_len) begin
                        // Compute marked grid for current_t
                        if (current_t == 0) begin
                            marked_grid <= 48'd0;
                        end else begin
                            marked_grid <= 48'd0;
                            for (step_idx = 0; step_idx < current_t; step_idx = step_idx + 1) begin
                                // Set bit for coordinate
                                case ({path_y[step_idx][2:0], path_x[step_idx][2:0]})
                                    6'd0:  marked_grid[0] <= 1'b1;
                                    6'd1:  marked_grid[1] <= 1'b1;
                                    6'd2:  marked_grid[2] <= 1'b1;
                                    6'd3:  marked_grid[3] <= 1'b1;
                                    6'd4:  marked_grid[4] <= 1'b1;
                                    6'd5:  marked_grid[5] <= 1'b1;
                                    6'd6:  marked_grid[6] <= 1'b1;
                                    6'd7:  marked_grid[7] <= 1'b1;
                                    6'd8:  marked_grid[8] <= 1'b1;
                                    6'd9:  marked_grid[9] <= 1'b1;
                                    6'd10: marked_grid[10] <= 1'b1;
                                    6'd11: marked_grid[11] <= 1'b1;
                                    6'd12: marked_grid[12] <= 1'b1;
                                    6'd13: marked_grid[13] <= 1'b1;
                                    6'd14: marked_grid[14] <= 1'b1;
                                    6'd15: marked_grid[15] <= 1'b1;
                                    6'd16: marked_grid[16] <= 1'b1;
                                    6'd17: marked_grid[17] <= 1'b1;
                                    6'd18: marked_grid[18] <= 1'b1;
                                    6'd19: marked_grid[19] <= 1'b1;
                                    6'd20: marked_grid[20] <= 1'b1;
                                    6'd21: marked_grid[21] <= 1'b1;
                                    6'd22: marked_grid[22] <= 1'b1;
                                    6'd23: marked_grid[23] <= 1'b1;
                                    6'd24: marked_grid[24] <= 1'b1;
                                    6'd25: marked_grid[25] <= 1'b1;
                                    6'd26: marked_grid[26] <= 1'b1;
                                    6'd27: marked_grid[27] <= 1'b1;
                                    6'd28: marked_grid[28] <= 1'b1;
                                    6'd29: marked_grid[29] <= 1'b1;
                                    6'd30: marked_grid[30] <= 1'b1;
                                    6'd31: marked_grid[31] <= 1'b1;
                                    6'd32: marked_grid[32] <= 1'b1;
                                    6'd33: marked_grid[33] <= 1'b1;
                                    6'd34: marked_grid[34] <= 1'b1;
                                    6'd35: marked_grid[35] <= 1'b1;
                                    6'd36: marked_grid[36] <= 1'b1;
                                    6'd37: marked_grid[37] <= 1'b1;
                                    6'd38: marked_grid[38] <= 1'b1;
                                    6'd39: marked_grid[39] <= 1'b1;
                                    6'd40: marked_grid[40] <= 1'b1;
                                    6'd41: marked_grid[41] <= 1'b1;
                                    6'd42: marked_grid[42] <= 1'b1;
                                    6'd43: marked_grid[43] <= 1'b1;
                                    6'd44: marked_grid[44] <= 1'b1;
                                    6'd45: marked_grid[45] <= 1'b1;
                                    6'd46: marked_grid[46] <= 1'b1;
                                    6'd47: marked_grid[47] <= 1'b1;
                                    default: begin end
                                endcase
                            end
                        end
                        
                        // Compare (1 cycle later)
                        if (current_t > 0) begin
                            if (marked_grid == target_grid) begin
                                match_current <= 1'b1;
                                if (!match_found) begin
                                    min_t_reg <= current_t;
                                end
                            end else begin
                                match_current <= 1'b0;
                            end
                        end
                        
                        if (current_t > 0 && match_current) begin
                            match_found <= 1'b1;
                            max_t_reg <= current_t;
                        end
                        
                        current_t <= current_t + 8'd1;
                    end
                end
                
                FIND_EXT: begin
                    // Already computed min/max in CHECK_T
                    min_time <= min_t_reg;
                    max_time <= max_t_reg;
                    valid <= 1'b1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (!match_found) begin
                        valid <= 1'b0;
                        min_time <= 8'd0;
                        max_time <= 8'd0;
                    end
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule