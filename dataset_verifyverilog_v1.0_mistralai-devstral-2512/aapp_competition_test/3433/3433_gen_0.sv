module maze_escape (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] wall_map,
    input wire [255:0] joe_start_map,
    input wire [255:0] fire_start_map,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] FIRE_BFS  = 3'd1;
    localparam [2:0] JOE_BFS   = 3'd2;
    localparam [2:0] FINISH    = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [7:0] time_counter;
    reg [7:0] min_escape_time;
    reg [3:0] current_row, current_col;
    reg [3:0] next_row, next_col;
    reg [7:0] i, j, k;

    // Fire and Joe BFS arrays (flattened to 256 elements)
    reg [7:0] fire_time [0:255];
    reg joe_visited [0:255];
    reg fire_visited [0:255];

    // Current and next wavefronts
    reg [7:0] current_fire_front [0:255];
    reg [7:0] current_joe_front [0:255];
    reg [7:0] next_fire_front [0:255];
    reg [7:0] next_joe_front [0:255];

    // Helper functions for 2D to 1D conversion
    function [7:0] pos_to_index;
        input [3:0] r, c;
        pos_to_index = r * 16 + c;
    endfunction

    function [3:0] index_to_row;
        input [7:0] idx;
        index_to_row = idx / 16;
    endfunction

    function [3:0] index_to_col;
        input [7:0] idx;
        index_to_col = idx % 16;
    endfunction

    // Initialize arrays
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            time_counter <= 8'd0;
            min_escape_time <= 8'd255;
            result <= 8'd0;
            done <= 1'b0;

            // Initialize fire_time array
            for (i = 0; i < 256; i = i + 1) begin
                fire_time[i] <= 8'd255;
                fire_visited[i] <= 1'b0;
                joe_visited[i] <= 1'b0;
                current_fire_front[i] <= 8'd0;
                current_joe_front[i] <= 8'd0;
                next_fire_front[i] <= 8'd0;
                next_joe_front[i] <= 8'd0;
            end
        end
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize fire sources
                        for (i = 0; i < 256; i = i + 1) begin
                            if (fire_start_map[i]) begin
                                fire_time[i] <= 8'd0;
                                fire_visited[i] <= 1'b1;
                                current_fire_front[i] <= 8'd1;
                            end
                            if (joe_start_map[i]) begin
                                joe_visited[i] <= 1'b1;
                                current_joe_front[i] <= 8'd1;
                            end
                        end
                        state <= FIRE_BFS;
                        time_counter <= 8'd0;
                    end
                end

                FIRE_BFS: begin
                    // Process fire wavefront
                    for (i = 0; i < 256; i = i + 1) begin
                        if (current_fire_front[i]) begin
                            current_row = index_to_row(i);
                            current_col = index_to_col(i);

                            // Check all 4 directions
                            for (j = 0; j < 4; j = j + 1) begin
                                case (j)
                                    0: begin next_row = current_row - 1; next_col = current_col; end
                                    1: begin next_row = current_row + 1; next_col = current_col; end
                                    2: begin next_row = current_row; next_col = current_col - 1; end
                                    3: begin next_row = current_row; next_col = current_col + 1; end
                                endcase

                                // Check bounds and wall
                                if (next_row >= 0 && next_row < 16 && next_col >= 0 && next_col < 16) begin
                                    k = pos_to_index(next_row, next_col);
                                    if (!wall_map[k] && !fire_visited[k]) begin
                                        fire_time[k] <= time_counter + 8'd1;
                                        fire_visited[k] <= 1'b1;
                                        next_fire_front[k] <= 8'd1;
                                    end
                                end
                            end
                        end
                    end

                    // Copy next front to current front
                    for (i = 0; i < 256; i = i + 1) begin
                        current_fire_front[i] <= next_fire_front[i];
                        next_fire_front[i] <= 8'd0;
                    end

                    // Check if fire BFS is done
                    reg fire_done;
                    fire_done = 1'b1;
                    for (i = 0; i < 256; i = i + 1) begin
                        if (current_fire_front[i]) begin
                            fire_done = 1'b0;
                        end
                    end

                    if (fire_done) begin
                        // Initialize Joe BFS
                        for (i = 0; i < 256; i = i + 1) begin
                            if (joe_start_map[i]) begin
                                current_joe_front[i] <= 8'd1;
                            end else begin
                                current_joe_front[i] <= 8'd0;
                            end
                        end
                        state <= JOE_BFS;
                        time_counter <= 8'd0;
                    else begin
                        time_counter <= time_counter + 8'd1;
                    end
                end

                JOE_BFS: begin
                    // Process Joe wavefront
                    for (i = 0; i < 256; i = i + 1) begin
                        if (current_joe_front[i]) begin
                            current_row = index_to_row(i);
                            current_col = index_to_col(i);

                            // Check if current position is a border
                            if (current_row == 0 || current_row == 15 || current_col == 0 || current_col == 15) begin
                                if (time_counter <= fire_time[i]) begin
                                    if (time_counter < min_escape_time) begin
                                        min_escape_time <= time_counter;
                                    end
                                end
                            end

                            // Check all 4 directions
                            for (j = 0; j < 4; j = j + 1) begin
                                case (j)
                                    0: begin next_row = current_row - 1; next_col = current_col; end
                                    1: begin next_row = current_row + 1; next_col = current_col; end
                                    2: begin next_row = current_row; next_col = current_col - 1; end
                                    3: begin next_row = current_row; next_col = current_col + 1; end
                                endcase

                                // Check bounds, wall, and fire time
                                if (next_row >= 0 && next_row < 16 && next_col >= 0 && next_col < 16) begin
                                    k = pos_to_index(next_row, next_col);
                                    if (!wall_map[k] && !joe_visited[k] && (time_counter + 8'd1) < fire_time[k]) begin
                                        joe_visited[k] <= 1'b1;
                                        next_joe_front[k] <= 8'd1;
                                    end
                                end
                            end
                        end
                    end

                    // Copy next front to current front
                    for (i = 0; i < 256; i = i + 1) begin
                        current_joe_front[i] <= next_joe_front[i];
                        next_joe_front[i] <= 8'd0;
                    end

                    // Check if Joe BFS is done
                    reg joe_done;
                    joe_done = 1'b1;
                    for (i = 0; i < 256; i = i + 1) begin
                        if (current_joe_front[i]) begin
                            joe_done = 1'b0;
                        end
                    end

                    if (joe_done) begin
                        state <= FINISH;
                    else begin
                        time_counter <= time_counter + 8'd1;
                    end
                end

                FINISH: begin
                    if (min_escape_time == 8'd255) begin
                        result <= 8'd255;
                    end else begin
                        result <= min_escape_time;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule