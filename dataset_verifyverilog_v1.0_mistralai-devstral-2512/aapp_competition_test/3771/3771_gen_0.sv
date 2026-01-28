module FrogPondSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [7:0] MAX_H = 16;
    localparam [7:0] MAX_W = 16;
    localparam [7:0] MAX_NODES = MAX_H + MAX_W + 2;
    localparam [31:0] INF = 32'h7FFF_FFFF;

    // Grid storage (ROM)
    reg [7:0] grid [0:MAX_H-1][0:MAX_W-1];

    // State machine
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE_GRID = 3'd1;
    localparam [2:0] CHECK_IMPOSSIBLE = 3'd2;
    localparam [2:0] BUILD_GRAPH = 3'd3;
    localparam [2:0] COMPUTE_FLOW = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    reg [2:0] state;
    reg [7:0] row_s, col_s, row_t, col_t;
    reg [7:0] r, c;
    reg [7:0] i, j, k;

    // Graph representation
    reg [15:0] capacity [0:MAX_NODES-1][0:MAX_NODES-1];
    reg [7:0] level [0:MAX_NODES-1];
    reg [7:0] ptr [0:MAX_NODES-1];

    // Dinic algorithm variables
    reg [31:0] flow;
    reg [31:0] temp_flow;
    reg [7:0] u, v;
    reg [7:0] stack [0:MAX_NODES-1];
    reg [7:0] stack_ptr;

    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;

            // Initialize grid (example grid - replace with actual ROM initialization)
            for (r = 0; r < MAX_H; r = r + 1) begin
                for (c = 0; c < MAX_W; c = c + 1) begin
                    grid[r][c] <= 8'd0;
                end
            end

            // Initialize graph
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                for (j = 0; j < MAX_NODES; j = j + 1) begin
                    capacity[i][j] <= 16'd0;
                end
            end

            row_s <= 8'd0;
            col_s <= 8'd0;
            row_t <= 8'd0;
            col_t <= 8'd0;
            r <= 8'd0;
            c <= 8'd0;
            i <= 8'd0;
            j <= 8'd0;
            k <= 8'd0;
            u <= 8'd0;
            v <= 8'd0;
            stack_ptr <= 8'd0;
            flow <= 32'd0;
            temp_flow <= 32'd0;

            for (i = 0; i < MAX_NODES; i = i + 1) begin
                level[i] <= 8'd0;
                ptr[i] <= 8'd0;
            end

        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= PARSE_GRID;
                        r <= 8'd0;
                        c <= 8'd0;
                    end
                end

                PARSE_GRID: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 32'd0;
                    end else begin
                        if (r < MAX_H) begin
                            if (c < MAX_W) begin
                                if (grid[r][c] == 8'h53) begin // 'S'
                                    row_s <= r;
                                    col_s <= c;
                                end else if (grid[r][c] == 8'h54) begin // 'T'
                                    row_t <= r;
                                    col_t <= c;
                                end
                                c <= c + 8'd1;
                            end else begin
                                c <= 8'd0;
                                r <= r + 8'd1;
                            end
                        end else begin
                            state <= CHECK_IMPOSSIBLE;
                        end
                    end
                end

                CHECK_IMPOSSIBLE: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 32'd0;
                    end else begin
                        if (row_s == row_t || col_s == col_t) begin
                            result <= 32'd4294967295; // -1 in 32-bit
                            state <= FINISH;
                        end else begin
                            state <= BUILD_GRAPH;
                            i <= 8'd0;
                            j <= 8'd0;
                        end
                    end
                end

                BUILD_GRAPH: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= 32'd0;
                    end else begin
                        if (i < MAX_NODES) begin
                            if (j < MAX_NODES) begin
                                capacity[i][j] <= 16'd0;
                                j <= j + 8'd1;
                            end else begin
                                j <= 8'd0;
                                i <= i + 8'd1;
                            end
                        end else begin
                            // Add source edges
                            capacity[0][row_s + 1] <= 16'h7FFF;
                            capacity[0][col_s + MAX_H + 1] <= 16'h7FFF;
                            // Add sink edges
                            capacity[row_t + 1][MAX_NODES - 1] <= 16'h7FFF;
                            capacity[col_t + MAX_H + 1][MAX_NODES - 1] <= 16'h7FFF;
                            // Add leaf edges
                            for (r = 0; r < MAX_H; r = r + 1) begin
                                for (c = 0; c < MAX_W; c = c + 1) begin
                                    if (grid[r][c] == 8'h6F) begin // 'o'
                                        capacity[r + 1][c + MAX_H + 1] <= 16'd1;
                                        capacity[c + MAX_H + 1][r + 1] <= 16'd1;
                                    end
                                end
                            end
                            state <= COMPUTE_FLOW;
                            flow <= 32'd0;
                        end
                    end
                end

                COMPUTE_FLOW: begin
                    cycle_count <= cycle_count + 16'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        result <= flow;
                    end else begin
                        // BFS for level graph
                        for (i = 0; i < MAX_NODES; i = i + 1) begin
                            level[i] <= 8'd255;
                        end
                        level[0] <= 8'd0;
                        stack[0] <= 0;
                        stack_ptr <= 8'd1;
                        i <= 8'd0;
                        while (i < stack_ptr) begin
                            u <= stack[i];
                            i <= i + 8'd1;
                            for (v = 0; v < MAX_NODES; v = v + 1) begin
                                if (capacity[u][v] > 16'd0 && level[v] == 8'd255) begin
                                    level[v] <= level[u] + 8'd1;
                                    stack[stack_ptr] <= v;
                                    stack_ptr <= stack_ptr + 8'd1;
                                end
                            end
                        end

                        if (level[MAX_NODES - 1] == 8'd255) begin
                            state <= FINISH;
                            result <= flow;
                        end else begin
                            for (i = 0; i < MAX_NODES; i = i + 1) begin
                                ptr[i] <= 8'd0;
                            end
                            u <= 0;
                            temp_flow <= 32'd0;
                            while (u != MAX_NODES - 1) begin
                                if (ptr[u] < MAX_NODES) begin
                                    v <= ptr[u];
                                    if (capacity[u][v] > 16'd0 && level[v] == level[u] + 8'd1) begin
                                        if (temp_flow == 32'd0 || temp_flow > capacity[u][v]) begin
                                            temp_flow <= capacity[u][v];
                                        end
                                        ptr[u] <= v + 8'd1;
                                    end else begin
                                        ptr[u] <= v + 8'd1;
                                    end
                                end else begin
                                    if (temp_flow > 32'd0) begin
                                        capacity[u][v] <= capacity[u][v] - temp_flow;
                                        capacity[v][u] <= capacity[v][u] + temp_flow;
                                        flow <= flow + temp_flow;
                                        u <= v;
                                        temp_flow <= 32'd0;
                                    end else begin
                                        level[u] <= 8'd255;
                                        u <= stack[stack_ptr - 1];
                                        stack_ptr <= stack_ptr - 8'd1;
                                    end
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule