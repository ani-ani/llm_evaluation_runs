module HamiltonianCycleFinder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [3:0] M,
    output reg [63:0] result_x,
    output reg [63:0] result_y,
    output reg valid,
    output reg no_solution
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] SEARCH = 3'd2;
    localparam [2:0] VALID_STATE = 3'd3;
    localparam [2:0] NO_SOLUTION_STATE = 3'd4;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] depth;  // Current depth in path (0 to 63)
    reg [5:0] cycle_count;  // Timeout counter
    reg [5:0] move_index;  // Current move being tried
    reg [3:0] current_x, current_y;  // Current position
    reg [3:0] next_x, next_y;  // Next position to try
    reg [63:0] visited;  // 64-bit visited array
    reg [63:0] path_x;  // Path x coordinates
    reg [63:0] path_y;  // Path y coordinates
    reg found;  // Found solution flag

    // Knight move deltas (8 moves)
    localparam [3:0] DX[0:7] = '{2, 1, -1, -2, -2, -1, 1, 2};
    localparam [3:0] DY[0:7] = '{1, 2, 2, 1, -1, -2, -2, -1};

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            depth <= 6'd0;
            cycle_count <= 6'd0;
            move_index <= 6'd0;
            current_x <= 4'd0;
            current_y <= 4'd0;
            next_x <= 4'd0;
            next_y <= 4'd0;
            visited <= 64'd0;
            path_x <= 64'd0;
            path_y <= 64'd0;
            found <= 1'b0;
            valid <= 1'b0;
            no_solution <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = SEARCH;
            end

            SEARCH: begin
                if (found) begin
                    next_state = VALID_STATE;
                end else if (cycle_count >= 6'd255) begin
                    next_state = NO_SOLUTION_STATE;
                end
            end

            VALID_STATE: begin
                next_state = IDLE;
            end

            NO_SOLUTION_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Search logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                INIT: begin
                    // Initialize path with starting position (0,0)
                    visited[0] <= 1'b1;
                    path_x[3:0] <= 4'd0;
                    path_y[3:0] <= 4'd0;
                    current_x <= 4'd0;
                    current_y <= 4'd0;
                    depth <= 6'd1;
                    cycle_count <= 6'd0;
                    move_index <= 6'd0;
                    found <= 1'b0;
                end

                SEARCH: begin
                    if (depth == (N * M)) begin
                        // Check if we can return to start
                        reg [3:0] last_x = path_x[(depth-1)*4 +: 4];
                        reg [3:0] last_y = path_y[(depth-1)*4 +: 4];
                        reg [3:0] dist = (last_x - 4'd0) + (last_y - 4'd0);
                        if (dist == 4'd2 || dist == 4'd3) begin
                            found <= 1'b1;
                        end
                    end else begin
                        // Try next move
                        if (move_index < 6'd8) begin
                            next_x = current_x + DX[move_index];
                            next_y = current_y + DY[move_index];

                            // Check bounds
                            reg in_bounds = (next_x < N) && (next_y < M);
                            reg not_visited = !visited[next_x * M + next_y];

                            // Check Manhattan distance
                            reg [3:0] dx = next_x - current_x;
                            reg [3:0] dy = next_y - current_y;
                            reg [3:0] manhattan = (dx[3] ? -dx : dx) + (dy[3] ? -dy : dy);
                            reg valid_move = (manhattan == 4'd2 || manhattan == 4'd3);

                            if (in_bounds && not_visited && valid_move) begin
                                // Mark visited and update path
                                visited[next_x * M + next_y] <= 1'b1;
                                path_x[depth*4 +: 4] <= next_x;
                                path_y[depth*4 +: 4] <= next_y;
                                current_x <= next_x;
                                current_y <= next_y;
                                depth <= depth + 6'd1;
                                move_index <= 6'd0;
                            end else begin
                                move_index <= move_index + 6'd1;
                            end
                        end else begin
                            // Backtrack
                            if (depth > 6'd1) begin
                                depth <= depth - 6'd1;
                                current_x <= path_x[depth*4 +: 4];
                                current_y <= path_y[depth*4 +: 4];
                                visited[next_x * M + next_y] <= 1'b0;
                                move_index <= move_index + 6'd1;
                            end else begin
                                // No solution
                                found <= 1'b0;
                            end
                        end
                    end
                    cycle_count <= cycle_count + 6'd1;
                end

                VALID_STATE: begin
                    valid <= 1'b1;
                    result_x <= path_x;
                    result_y <= path_y;
                end

                NO_SOLUTION_STATE: begin
                    no_solution <= 1'b1;
                end

                default: begin
                    valid <= 1'b0;
                    no_solution <= 1'b0;
                end
            endcase
        end
    end

endmodule