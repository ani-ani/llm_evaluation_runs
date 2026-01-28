module StealthNavigation(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] start_r,
    input wire [3:0] start_c,
    input wire [3:0] target_r,
    input wire [3:0] target_c,
    input wire [255:0] grid_flat,
    input wire [3:0] num_masters,
    input wire [63:0] path_data [0:3],
    output reg [9:0] result,
    output reg done
);

    // Constants
    localparam [7:0] GRID_SIZE = 8'd16;
    localparam [7:0] MAX_PATH_LEN = 8'd8;
    localparam [5:0] MAX_LCM = 6'd64;
    localparam [9:0] MAX_CYCLES = 10'd1024;
    localparam [9:0] IMPOSSIBLE = 10'd1023;

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [9:0] cycle_count;
    reg [9:0] min_turns;
    reg [5:0] time_mod_lcm;
    reg [3:0] current_r, current_c;
    reg [3:0] master_r [0:3], master_c [0:3];
    reg [15:0] queue [0:1023];
    reg [9:0] queue_head, queue_tail;
    reg [15:0] visited [0:16383];
    reg [7:0] i, j, k;
    reg [5:0] t;

    // Grid unpacking
    wire [7:0] grid [0:15][0:15];
    genvar r, c;
    generate
        for (r = 0; r < 16; r = r + 1) begin : GEN_ROW
            for (c = 0; c < 16; c = c + 1) begin : GEN_COL
                assign grid[r][c] = grid_flat[(r * 16) + c];
            end
        end
    endgenerate

    // Master position LUT
    reg [3:0] master_pos_r [0:3][0:63];
    reg [3:0] master_pos_c [0:3][0:63];

    // Danger map
    reg danger_grid [0:15][0:15];

    // BFS queue management
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 10'd0;
            min_turns <= IMPOSSIBLE;
            time_mod_lcm <= 6'd0;
            current_r <= 4'd0;
            current_c <= 4'd0;
            queue_head <= 10'd0;
            queue_tail <= 10'd0;
            done <= 1'b0;
            result <= IMPOSSIBLE;

            // Initialize master positions
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 64; j = j + 1) begin
                    master_pos_r[i][j] <= 4'd0;
                    master_pos_c[i][j] <= 4'd0;
                end
            end

            // Initialize visited array
            for (i = 0; i < 16384; i = i + 1) begin
                visited[i] <= 16'd0;
            end

            // Initialize queue
            for (i = 0; i < 1024; i = i + 1) begin
                queue[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD;
                    end
                end

                LOAD: begin
                    // Load master paths into LUT
                    for (i = 0; i < num_masters; i = i + 1) begin
                        for (j = 0; j < MAX_PATH_LEN; j = j + 1) begin
                            master_pos_r[i][j] <= path_data[i][(j * 8) + 7:(j * 8) + 4];
                            master_pos_c[i][j] <= path_data[i][(j * 8) + 3:(j * 8)];
                        end
                    end
                    next_state <= COMPUTE;
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 10'd1;
                    time_mod_lcm <= (time_mod_lcm + 6'd1) % MAX_LCM;

                    // Generate danger map
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            danger_grid[i][j] <= 1'b0;
                            for (k = 0; k < num_masters; k = k + 1) begin
                                if ((i == master_pos_r[k][time_mod_lcm] || j == master_pos_c[k][time_mod_lcm]) && 
                                    line_of_sight(i, j, master_pos_r[k][time_mod_lcm], master_pos_c[k][time_mod_lcm])) begin
                                    danger_grid[i][j] <= 1'b1;
                                end
                            end
                        end
                    end

                    // BFS processing
                    if (queue_head != queue_tail) begin
                        current_r <= queue[queue_head][11:8];
                        current_c <= queue[queue_head][7:4];
                        time_mod_lcm <= queue[queue_head][3:0];
                        queue_head <= queue_head + 10'd1;

                        // Check if target reached
                        if (current_r == target_r && current_c == target_c) begin
                            min_turns <= cycle_count;
                            next_state <= DONE_STATE;
                        end else begin
                            // Generate neighbors
                            for (i = 0; i < 5; i = i + 1) begin
                                case (i)
                                    0: begin current_r <= current_r; current_c <= current_c; end // Stay
                                    1: begin current_r <= current_r - 4'd1; current_c <= current_c; end // North
                                    2: begin current_r <= current_r + 4'd1; current_c <= current_c; end // South
                                    3: begin current_r <= current_r; current_c <= current_c - 4'd1; end // West
                                    4: begin current_r <= current_r; current_c <= current_c + 4'd1; end // East
                                endcase

                                // Check bounds and walkable
                                if (current_r < 4'd16 && current_c < 4'd16 && grid[current_r][current_c] && !danger_grid[current_r][current_c]) begin
                                    // Check visited
                                    if (!visited[{current_r, current_c, (time_mod_lcm + 6'd1) % MAX_LCM}]) begin
                                        visited[{current_r, current_c, (time_mod_lcm + 6'd1) % MAX_LCM}] <= 1'b1;
                                        queue[queue_tail] <= {current_r, current_c, (time_mod_lcm + 6'd1) % MAX_LCM};
                                        queue_tail <= queue_tail + 10'd1;
                                    end
                                end
                            end
                        end
                    end

                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result <= min_turns;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Line of sight function
    function line_of_sight;
        input [3:0] r1, c1, r2, c2;
        reg [3:0] step_r, step_c;
        reg [3:0] pos_r, pos_c;
        begin
            if (r1 == r2) begin
                step_c = (c1 < c2) ? 4'd1 : 4'd-1;
                pos_c = c1 + step_c;
                while (pos_c != c2) begin
                    if (!grid[r1][pos_c]) begin
                        line_of_sight = 1'b0;
                        return;
                    end
                    pos_c = pos_c + step_c;
                end
            end else if (c1 == c2) begin
                step_r = (r1 < r2) ? 4'd1 : 4'd-1;
                pos_r = r1 + step_r;
                while (pos_r != r2) begin
                    if (!grid[pos_r][c1]) begin
                        line_of_sight = 1'b0;
                        return;
                    end
                    pos_r = pos_r + step_r;
                end
            end else begin
                line_of_sight = 1'b0;
                return;
            end
            line_of_sight = 1'b1;
        end
    endfunction

endmodule