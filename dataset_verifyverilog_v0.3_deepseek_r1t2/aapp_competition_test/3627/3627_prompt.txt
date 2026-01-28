module min_energy #(
    parameter MAX_ROWS = 17,  // 15 + top and bottom rows
    parameter MAX_COLS = 15,
    parameter COST_WIDTH = 4,  // signed, -9 to 9
    parameter DP_WIDTH = 12    // enough for max cumulative cost ~2000
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,  // number of cost rows (excluding top and bottom)
    input wire [3:0] C,  // number of columns
    input wire signed [COST_WIDTH-1:0] grid [0:MAX_ROWS-1][0:MAX_COLS-1],
    output reg [DP_WIDTH-1:0] result,
    output reg done
);

    // Internal state
    reg [DP_WIDTH-1:0] dp [0:MAX_ROWS-1][0:MAX_COLS-1];
    reg [DP_WIDTH-1:0] next_dp [0:MAX_ROWS-1][0:MAX_COLS-1];
    reg [4:0] row, col;           // current cell being processed
    reg [8:0] iter;               // iteration counter (0..255)
    reg [2:0] state;

    // State definitions
    localparam IDLE = 3'b000;
    localparam INIT = 3'b001;
    localparam RELAX = 3'b010;
    localparam UPDATE = 3'b011;
    localparam FIND_MIN = 3'b100;
    localparam DONE = 3'b101;

    // Neighbor directions: left, right, up, down
    wire signed [5:0] dr [0:3] = '{0, 0, -1, 1};
    wire signed [5:0] dc [0:3] = '{-1, 1, 0, 0};

    // Helper functions
    function automatic bit in_bounds(input signed [5:0] r, input signed [5:0] c);
        in_bounds = (r >= 0 && r < MAX_ROWS && c >= 0 && c < MAX_COLS);
    endfunction

    function automatic bit is_end(input [4:0] r);
        is_end = (r == 0);  // top row
    endfunction

    function automatic bit is_start(input [4:0] r);
        is_start = (r == R + 1);  // bottom row
    endfunction

    function automatic signed [COST_WIDTH-1:0] get_cost(input [4:0] r, input [4:0] c);
        if (r == 0 || r == R + 1)
            get_cost = 0;
        else
            get_cost = grid[r][c];
    endfunction

    // Combinational block to compute candidate for current cell
    reg [DP_WIDTH-1:0] candidate;
    always @(*) begin
        // Default to current dp value (or INF)
        candidate = dp[row][col];
        
        if (!is_end(row)) begin
            for (integer n = 0; n < 4; n = n + 1) begin
                signed [5:0] nr = row + dr[n];
                signed [5:0] nc = col + dc[n];
                if (in_bounds(nr, nc)) begin
                    // Get cost of entering the neighbor
                    signed [COST_WIDTH-1:0] cost_neighbor = get_cost(nr, nc);
                    // Compute candidate = max(0, cost_neighbor + dp[neighbor])
                    signed [DP_WIDTH:0] sum = cost_neighbor + dp[nr][nc];
                    reg [DP_WIDTH-1:0] cand;
                    if (sum < 0)
                        cand = 0;
                    else
                        cand = sum[DP_WIDTH-1:0];
                    // Take minimum over neighbors
                    if (cand < candidate)
                        candidate = cand;
                end
            end
        end else begin
            candidate = 0;  // end cells need 0 energy
        end
    end

    // Sequential state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            result <= 0;
            state <= IDLE;
            iter <= 0;
            row <= 0;
            col <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        iter <= 0;
                        row <= 0;
                        col <= 0;
                    end
                end

                INIT: begin
                    // Initialize dp and next_dp: end cells 0, others INF
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        if (is_end(row)) begin
                            dp[row][col] <= 0;
                            next_dp[row][col] <= 0;
                        end else begin
                            dp[row][col] <= {DP_WIDTH{1'b1}};  // INF
                            next_dp[row][col] <= {DP_WIDTH{1'b1}};
                        end

                        // Move to next cell
                        if (col == MAX_COLS - 1) begin
                            col <= 0;
                            if (row == MAX_ROWS - 1) begin
                                state <= RELAX;
                                row <= 0;
                                col <= 0;
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end

                RELAX: begin
                    // Update next_dp for current cell using candidate
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        next_dp[row][col] <= candidate;

                        // Move to next cell
                        if (col == MAX_COLS - 1) begin
                            col <= 0;
                            if (row == MAX_ROWS - 1) begin
                                state <= UPDATE;
                                row <= 0;
                                col <= 0;
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end

                UPDATE: begin
                    // Copy next_dp to dp (simulate parallel update)
                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        dp[row][col] <= next_dp[row][col];

                        if (col == MAX_COLS - 1) begin
                            col <= 0;
                            if (row == MAX_ROWS - 1) begin
                                iter <= iter + 1;
                                // Fixed number of iterations: 255 (enough for max grid)
                                if (iter >= 254) begin  // 255 iterations total
                                    state <= FIND_MIN;
                                end else begin
                                    state <= RELAX;
                                    row <= 0;
                                    col <= 0;
                                end
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end

                FIND_MIN: begin
                    // Find minimum dp among start cells
                    if (row == 0 && col == 0) begin
                        result <= {DP_WIDTH{1'b1}};  // Initialize to INF
                    end

                    if (row < MAX_ROWS && col < MAX_COLS) begin
                        if (is_start(row)) begin
                            if (dp[row][col] < result) begin
                                result <= dp[row][col];
                            end
                        end

                        if (col == MAX_COLS - 1) begin
                            col <= 0;
                            if (row == MAX_ROWS - 1) begin
                                state <= DONE;
                            end else begin
                                row <= row + 1;
                            end
                        end else begin
                            col <= col + 1;
                        end
                    end
                end

                DONE: begin
                    done <= 1;
                    // Stay in DONE until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule