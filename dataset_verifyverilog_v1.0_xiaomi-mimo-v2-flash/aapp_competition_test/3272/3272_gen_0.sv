module GargoylePuzzleSolver (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_data,
    input wire [3:0] n,
    input wire [3:0] m,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] UNPACK_GRID   = 3'd1;
    localparam [2:0] PRECOMPUTE    = 3'd2;
    localparam [2:0] BUILD_GRAPH   = 3'd3;
    localparam [2:0] SOLVE_SAT     = 3'd4;
    localparam [2:0] FINISH        = 3'd5;

    // Grid constants
    localparam [7:0] CHAR_DOT  = 8'd46;  // '.'
    localparam [7:0] CHAR_HASH = 8'd35;  // '#'
    localparam [7:0] CHAR_SLASH = 8'd47;  // '/'
    localparam [7:0] CHAR_BSLASH = 8'd92;  // '\\'
    localparam [7:0] CHAR_V    = 8'd86;  // 'V'
    localparam [7:0] CHAR_H    = 8'd72;  // 'H'

    // Direction constants (2 bits)
    localparam [1:0] DIR_T = 2'd0;  // Top
    localparam [1:0] DIR_B = 2'd1;  // Bottom
    localparam [1:0] DIR_L = 2'd2;  // Left
    localparam [1:0] DIR_R = 2'd3;  // Right

    // Internal state
    reg [2:0] state, next_state;
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Grid storage (8x8, 8-bit chars)
    reg [7:0] grid_reg [0:63];  // Flattened: index = r*m + c
    reg [3:0] grid_idx;
    reg [3:0] grid_row, grid_col;

    // Gargoyle tracking
    reg [3:0] gargoyle_count;
    reg [3:0] gargoyle_idx;
    reg [3:0] gargoyle_row [0:15];
    reg [3:0] gargoyle_col [0:15];
    reg [15:0] gargoyle_orient [0:15];  // 0=unrotated, 1=rotated

    // Path precomputation
    reg [3:0] path_gargoyle;
    reg [1:0] path_orientation;  // 0 or 1
    reg [1:0] path_face;  // T, B, L, R
    reg [1:0] path_curr_dir;
    reg [3:0] path_curr_r, path_curr_c;
    reg [5:0] path_step_counter;  // Max 64 steps per path
    localparam [5:0] MAX_PATH_STEPS = 6'd64;

    // Hit results: 4 bits per face (0=none, 1..16=gargoyle index, 15=invalid/wall)
    reg [3:0] hit_result [0:63];  // 16 gargoyles * 4 faces

    // 2-SAT graph: 32 nodes (16 gargoyles * 2 states: 0=unrotated, 1=rotated)
    reg [31:0] implication [0:31];  // 32x32 bit matrix
    reg [5:0] sat_node;  // 0..31
    reg [31:0] sat_assignment;  // Bit vector for 16 variables
    reg [3:0] sat_var;
    reg [3:0] sat_min_rotations;
    reg [31:0] sat_visited;
    reg sat_satisfiable;

    // Solver iteration
    reg [15:0] assignment_iter;  // 2^16 max, but we'll prune
    reg [3:0] rotation_count;
    reg [4:0] var_idx;

    // Helper: Direction mapping
    function [1:0] reflect(input [1:0] dir, input [7:0] mirror_char);
        begin
            if (mirror_char == CHAR_SLASH) begin
                case (dir)
                    DIR_T: reflect = DIR_L;
                    DIR_B: reflect = DIR_R;
                    DIR_L: reflect = DIR_T;
                    DIR_R: reflect = DIR_B;
                    default: reflect = dir;
                endcase
            end else if (mirror_char == CHAR_BSLASH) begin
                case (dir)
                    DIR_T: reflect = DIR_R;
                    DIR_B: reflect = DIR_L;
                    DIR_L: reflect = DIR_B;
                    DIR_R: reflect = DIR_T;
                    default: reflect = dir;
                endcase
            end else begin
                reflect = dir;  // No change
            end
        end
    endfunction

    // Helper: Check if cell is out of bounds
    function is_out_of_bounds(input [3:0] r, input [3:0] c);
        begin
            is_out_of_bounds = (r >= n) || (c >= m);
        end
    endfunction

    // Helper: Get gargoyle index from position (0..15, or 15 if not found)
    function [3:0] get_gargoyle_at(input [3:0] r, input [3:0] c);
        reg found;
        reg [3:0] i;
        begin
            found = 1'b0;
            get_gargoyle_at = 4'd15;  // Default: not found
            for (i = 0; i < gargoyle_count; i = i + 1) begin
                if (!found && (gargoyle_row[i] == r) && (gargoyle_col[i] == c)) begin
                    get_gargoyle_at = i;
                    found = 1'b1;
                end
            end
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            result <= 4'd0;
            cycle_counter <= 4'd0;
            gargoyle_count <= 4'd0;
            gargoyle_idx <= 4'd0;
            grid_idx <= 6'd0;
            grid_row <= 4'd0;
            grid_col <= 4'd0;
            path_gargoyle <= 4'd0;
            path_orientation <= 2'd0;
            path_face <= 2'd0;
            path_step_counter <= 6'd0;
            sat_node <= 6'd0;
            sat_var <= 4'd0;
            assignment_iter <= 16'd0;
            sat_satisfiable <= 1'b0;
            sat_min_rotations <= 4'd15;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= UNPACK_GRID;
                        gargoyle_count <= 4'd0;
                        grid_idx <= 6'd0;
                        grid_row <= 4'd0;
                        grid_col <= 4'd0;
                    end
                end

                UNPACK_GRID: begin
                    // Unpack grid_data (64 bits = 8 rows of 8 chars)
                    // We process row by row to avoid deep memory
                    if (grid_row < n) begin
                        // Process current row
                        if (grid_col < m) begin
                            // Extract byte from grid_data
                            grid_reg[grid_row * 8 + grid_col] <= grid_data[grid_col*8 +: 8];
                            // Check if gargoyle
                            if ((grid_data[grid_col*8 +: 8] == CHAR_V) || 
                                (grid_data[grid_col*8 +: 8] == CHAR_H)) begin
                                if (gargoyle_count < 16) begin
                                    gargoyle_row[gargoyle_count] <= grid_row;
                                    gargoyle_col[gargoyle_count] <= grid_col;
                                    gargoyle_count <= gargoyle_count + 4'd1;
                                end
                            end
                            grid_col <= grid_col + 4'd1;
                        end else begin
                            grid_col <= 4'd0;
                            grid_row <= grid_row + 4'd1;
                        end
                    end else begin
                        // Done unpacking
                        state <= PRECOMPUTE;
                        gargoyle_idx <= 4'd0;
                        cycle_counter <= 4'd0;
                    end
                end

                PRECOMPUTE: begin
                    // Simulate light paths for each gargoyle
                    if (gargoyle_idx < gargoyle_count) begin
                        if (path_gargoyle < gargoyle_count) begin
                            if (path_orientation < 2'd2) begin
                                if (path_face < 2'd2) begin  // T/B for V, L/R for H
                                    // Trace one path
                                    if (path_step_counter < MAX_PATH_STEPS) begin
                                        // Step logic
                                        if (path_step_counter == 6'd0) begin
                                            // Start position and direction
                                            path_curr_r <= gargoyle_row[path_gargoyle];
                                            path_curr_c <= gargoyle_col[path_gargoyle];
                                            // Determine start direction based on orientation and face
                                            if (path_orientation == 2'd0) begin  // Unrotated
                                                if (path_face == 2'd0) path_curr_dir <= DIR_B;  // T -> B
                                                else path_curr_dir <= DIR_T;  // B -> T
                                            end else begin  // Rotated
                                                if (path_face == 2'd0) path_curr_dir <= DIR_R;  // L -> R
                                                else path_curr_dir <= DIR_L;  // R -> L
                                            end
                                        end else begin
                                            // Move in direction
                                            case (path_curr_dir)
                                                DIR_T: path_curr_r <= path_curr_r - 4'd1;
                                                DIR_B: path_curr_r <= path_curr_r + 4'd1;
                                                DIR_L: path_curr_c <= path_curr_c - 4'd1;
                                                DIR_R: path_curr_c <= path_curr_c + 4'd1;
                                            endcase
                                        end
                                        path_step_counter <= path_step_counter + 6'd1;
                                    end else begin
                                        // Path exceeded max steps - mark as no hit
                                        hit_result[{path_gargoyle, path_face, path_orientation}] <= 4'd0;
                                        // Reset for next face
                                        path_face <= path_face + 2'd1;
                                        path_step_counter <= 6'd0;
                                    end
                                end else begin
                                    // Next orientation
                                    path_orientation <= path_orientation + 2'd1;
                                    path_face <= 2'd0;
                                end
                            end else begin
                                // Next gargoyle
                                path_gargoyle <= path_gargoyle + 4'd1;
                                path_orientation <= 2'd0;
                                path_face <= 2'd0;
                            end
                        end else begin
                            // Done precomputing all paths
                            state <= BUILD_GRAPH;
                            gargoyle_idx <= 4'd0;
                        end
                    end else begin
                        // Should not reach here
                        state <= BUILD_GRAPH;
                    end
                end

                BUILD_GRAPH: begin
                    // Build implication graph
                    // For each gargoyle face that hits nothing, add constraint
                    // For each pair, if face A hits face B, add implication
                    if (gargoyle_idx < gargoyle_count) begin
                        // Process constraints for this gargoyle
                        // Simplified: just set minimal rotations
                        gargoyle_idx <= gargoyle_idx + 4'd1;
                    end else begin
                        state <= SOLVE_SAT;
                        sat_var <= 4'd0;
                        assignment_iter <= 16'd0;
                        sat_min_rotations <= 4'd15;
                        sat_satisfiable <= 1'b0;
                    end
                end

                SOLVE_SAT: begin
                    // Try all possible assignments (2^n)
                    // With n <= 16, but we prune early
                    if (sat_var < gargoyle_count) begin
                        // Try assignment for current variable
                        // Simplified SAT solver: just count rotations for valid assignments
                        // Check if current assignment is valid (placeholder logic)
                        if (assignment_iter < (16'd1 << gargoyle_count)) begin
                            // Count rotations in current assignment
                            rotation_count <= 4'd0;
                            for (var_idx = 0; var_idx < gargoyle_count; var_idx = var_idx + 1) begin
                                if (assignment_iter[var_idx]) rotation_count <= rotation_count + 4'd1;
                            end
                            // Check validity (simplified: assume all assignments valid)
                            if (!sat_satisfiable || (rotation_count < sat_min_rotations)) begin
                                sat_min_rotations <= rotation_count;
                                sat_satisfiable <= 1'b1;
                            end
                            assignment_iter <= assignment_iter + 16'd1;
                        end else begin
                            state <= FINISH;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    if (sat_satisfiable) begin
                        result <= sat_min_rotations;
                        valid <= 1'b1;
                    end else begin
                        result <= 4'd15;
                        valid <= 1'b0;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule