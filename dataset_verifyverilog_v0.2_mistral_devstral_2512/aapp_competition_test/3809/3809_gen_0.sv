module boat_crossing_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [6:0] k,
    input [7:0] weight_encoded,
    output reg [7:0] min_rides,
    output reg [31:0] num_ways,
    output reg done
);

    // Constants
    localparam MOD = 32'h3B9ACA00; // 10^9+7
    localparam MAX_QUEUE = 512;
    localparam MAX_PEOPLE = 8;

    // State machine states
    typedef enum logic [3:0] {
        IDLE,
        PARSE,
        INIT_BFS,
        BFS_PROCESS,
        CHECK_NEXT,
        UPDATE_STATE,
        COUNT_WAYS,
        DONE_STATE
    } state_t;

    // BRAM for visited states
    reg [7:0] visited_min_rides [0:50][0:50][0:1];
    reg [31:0] visited_ways [0:50][0:50][0:1];

    // Queue for BFS
    reg [7:0] queue_c50 [0:MAX_QUEUE-1];
    reg [7:0] queue_c100 [0:MAX_QUEUE-1];
    reg queue_side [0:MAX_QUEUE-1];
    reg [8:0] queue_head = 0;
    reg [8:0] queue_tail = 0;

    // Current state being processed
    reg [7:0] current_c50, current_c100;
    reg current_side;

    // Counts of people
    reg [3:0] count_50, count_100;

    // State machine
    state_t state = IDLE;

    // Combinations lookup table (nCr)
    reg [7:0] c [0:8][0:8];

    // Initialize combinations table
    integer i, j;
    initial begin
        for (i = 0; i <= 8; i = i + 1) begin
            c[i][0] = 1;
            for (j = 1; j <= i; j = j + 1) begin
                c[i][j] = c[i-1][j-1] + c[i-1][j];
            end
        end
    end

    // Parse weights
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            min_rides <= 8'hFF;
            num_ways <= 32'h0;
            queue_head <= 0;
            queue_tail <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= PARSE;
                        done <= 0;
                    end
                end

                PARSE: begin
                    // Count 50kg and 100kg people
                    count_50 = 0;
                    count_100 = 0;
                    for (i = 0; i < n; i = i + 1) begin
                        if (weight_encoded[i]) begin
                            count_100 = count_100 + 1;
                        end else begin
                            count_50 = count_50 + 1;
                        end
                    end
                    state <= INIT_BFS;
                end

                INIT_BFS: begin
                    // Initialize visited array
                    for (i = 0; i <= 50; i = i + 1) begin
                        for (j = 0; j <= 50; j = j + 1) begin
                            visited_min_rides[i][j][0] = 8'hFF;
                            visited_min_rides[i][j][1] = 8'hFF;
                            visited_ways[i][j][0] = 32'h0;
                            visited_ways[i][j][1] = 32'h0;
                        end
                    end

                    // Initialize queue with starting state
                    queue_c50[0] = count_50;
                    queue_c100[0] = count_100;
                    queue_side[0] = 1'b0;
                    queue_head = 0;
                    queue_tail = 1;

                    // Mark starting state as visited
                    visited_min_rides[count_50][count_100][0] = 0;
                    visited_ways[count_50][count_100][0] = 1;

                    state <= BFS_PROCESS;
                end

                BFS_PROCESS: begin
                    if (queue_head != queue_tail) begin
                        // Dequeue current state
                        current_c50 = queue_c50[queue_head];
                        current_c100 = queue_c100[queue_head];
                        current_side = queue_side[queue_head];
                        queue_head = queue_head + 1;

                        // Check if we've reached the target state
                        if (current_c50 == 0 && current_c100 == 0 && current_side == 1'b1) begin
                            state <= COUNT_WAYS;
                        end else begin
                            state <= CHECK_NEXT;
                        end
                    end else begin
                        // Queue is empty, no solution
                        state <= DONE_STATE;
                    end
                end

                CHECK_NEXT: begin
                    // Try all valid boat loads
                    // 1x50
                    if (k >= 50 && current_c50 > 0) begin
                        // Enqueue new state
                        if (current_side == 1'b0) begin
                            // Moving from left to right
                            if (visited_min_rides[current_c50-1][current_c100][1] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][0] + 1 < visited_min_rides[current_c50-1][current_c100][1]) begin
                                visited_min_rides[current_c50-1][current_c100][1] = visited_min_rides[current_c50][current_c100][0] + 1;
                                visited_ways[current_c50-1][current_c100][1] = visited_ways[current_c50][current_c100][0];
                                queue_c50[queue_tail] = current_c50 - 1;
                                queue_c100[queue_tail] = current_c100;
                                queue_side[queue_tail] = 1'b1;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50-1][current_c100][1] == visited_min_rides[current_c50][current_c100][0] + 1) begin
                                visited_ways[current_c50-1][current_c100][1] = (visited_ways[current_c50-1][current_c100][1] + visited_ways[current_c50][current_c100][0]) % MOD;
                            end
                        end else begin
                            // Moving from right to left
                            if (visited_min_rides[current_c50+1][current_c100][0] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][1] + 1 < visited_min_rides[current_c50+1][current_c100][0]) begin
                                visited_min_rides[current_c50+1][current_c100][0] = visited_min_rides[current_c50][current_c100][1] + 1;
                                visited_ways[current_c50+1][current_c100][0] = visited_ways[current_c50][current_c100][1];
                                queue_c50[queue_tail] = current_c50 + 1;
                                queue_c100[queue_tail] = current_c100;
                                queue_side[queue_tail] = 1'b0;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50+1][current_c100][0] == visited_min_rides[current_c50][current_c100][1] + 1) begin
                                visited_ways[current_c50+1][current_c100][0] = (visited_ways[current_c50+1][current_c100][0] + visited_ways[current_c50][current_c100][1]) % MOD;
                            end
                        end
                    end

                    // 2x50
                    if (k >= 100 && current_c50 >= 2) begin
                        if (current_side == 1'b0) begin
                            if (visited_min_rides[current_c50-2][current_c100][1] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][0] + 1 < visited_min_rides[current_c50-2][current_c100][1]) begin
                                visited_min_rides[current_c50-2][current_c100][1] = visited_min_rides[current_c50][current_c100][0] + 1;
                                visited_ways[current_c50-2][current_c100][1] = visited_ways[current_c50][current_c100][0];
                                queue_c50[queue_tail] = current_c50 - 2;
                                queue_c100[queue_tail] = current_c100;
                                queue_side[queue_tail] = 1'b1;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50-2][current_c100][1] == visited_min_rides[current_c50][current_c100][0] + 1) begin
                                visited_ways[current_c50-2][current_c100][1] = (visited_ways[current_c50-2][current_c100][1] + visited_ways[current_c50][current_c100][0]) % MOD;
                            end
                        end else begin
                            if (visited_min_rides[current_c50+2][current_c100][0] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][1] + 1 < visited_min_rides[current_c50+2][current_c100][0]) begin
                                visited_min_rides[current_c50+2][current_c100][0] = visited_min_rides[current_c50][current_c100][1] + 1;
                                visited_ways[current_c50+2][current_c100][0] = visited_ways[current_c50][current_c100][1];
                                queue_c50[queue_tail] = current_c50 + 2;
                                queue_c100[queue_tail] = current_c100;
                                queue_side[queue_tail] = 1'b0;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50+2][current_c100][0] == visited_min_rides[current_c50][current_c100][1] + 1) begin
                                visited_ways[current_c50+2][current_c100][0] = (visited_ways[current_c50+2][current_c100][0] + visited_ways[current_c50][current_c100][1]) % MOD;
                            end
                        end
                    end

                    // 1x100
                    if (k >= 100 && current_c100 > 0) begin
                        if (current_side == 1'b0) begin
                            if (visited_min_rides[current_c50][current_c100-1][1] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][0] + 1 < visited_min_rides[current_c50][current_c100-1][1]) begin
                                visited_min_rides[current_c50][current_c100-1][1] = visited_min_rides[current_c50][current_c100][0] + 1;
                                visited_ways[current_c50][current_c100-1][1] = visited_ways[current_c50][current_c100][0];
                                queue_c50[queue_tail] = current_c50;
                                queue_c100[queue_tail] = current_c100 - 1;
                                queue_side[queue_tail] = 1'b1;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50][current_c100-1][1] == visited_min_rides[current_c50][current_c100][0] + 1) begin
                                visited_ways[current_c50][current_c100-1][1] = (visited_ways[current_c50][current_c100-1][1] + visited_ways[current_c50][current_c100][0]) % MOD;
                            end
                        end else begin
                            if (visited_min_rides[current_c50][current_c100+1][0] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][1] + 1 < visited_min_rides[current_c50][current_c100+1][0]) begin
                                visited_min_rides[current_c50][current_c100+1][0] = visited_min_rides[current_c50][current_c100][1] + 1;
                                visited_ways[current_c50][current_c100+1][0] = visited_ways[current_c50][current_c100][1];
                                queue_c50[queue_tail] = current_c50;
                                queue_c100[queue_tail] = current_c100 + 1;
                                queue_side[queue_tail] = 1'b0;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50][current_c100+1][0] == visited_min_rides[current_c50][current_c100][1] + 1) begin
                                visited_ways[current_c50][current_c100+1][0] = (visited_ways[current_c50][current_c100+1][0] + visited_ways[current_c50][current_c100][1]) % MOD;
                            end
                        end
                    end

                    // 1x50 + 1x100
                    if (k >= 150 && current_c50 > 0 && current_c100 > 0) begin
                        if (current_side == 1'b0) begin
                            if (visited_min_rides[current_c50-1][current_c100-1][1] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][0] + 1 < visited_min_rides[current_c50-1][current_c100-1][1]) begin
                                visited_min_rides[current_c50-1][current_c100-1][1] = visited_min_rides[current_c50][current_c100][0] + 1;
                                visited_ways[current_c50-1][current_c100-1][1] = visited_ways[current_c50][current_c100][0];
                                queue_c50[queue_tail] = current_c50 - 1;
                                queue_c100[queue_tail] = current_c100 - 1;
                                queue_side[queue_tail] = 1'b1;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50-1][current_c100-1][1] == visited_min_rides[current_c50][current_c100][0] + 1) begin
                                visited_ways[current_c50-1][current_c100-1][1] = (visited_ways[current_c50-1][current_c100-1][1] + visited_ways[current_c50][current_c100][0]) % MOD;
                            end
                        end else begin
                            if (visited_min_rides[current_c50+1][current_c100+1][0] == 8'hFF || 
                                visited_min_rides[current_c50][current_c100][1] + 1 < visited_min_rides[current_c50+1][current_c100+1][0]) begin
                                visited_min_rides[current_c50+1][current_c100+1][0] = visited_min_rides[current_c50][current_c100][1] + 1;
                                visited_ways[current_c50+1][current_c100+1][0] = visited_ways[current_c50][current_c100][1];
                                queue_c50[queue_tail] = current_c50 + 1;
                                queue_c100[queue_tail] = current_c100 + 1;
                                queue_side[queue_tail] = 1'b0;
                                queue_tail = queue_tail + 1;
                            end else if (visited_min_rides[current_c50+1][current_c100+1][0] == visited_min_rides[current_c50][current_c100][1] + 1) begin
                                visited_ways[current_c50+1][current_c100+1][0] = (visited_ways[current_c50+1][current_c100+1][0] + visited_ways[current_c50][current_c100][1]) % MOD;
                            end
                        end
                    end

                    state <= BFS_PROCESS;
                end

                COUNT_WAYS: begin
                    min_rides = visited_min_rides[0][0][1];
                    num_ways = visited_ways[0][0][1];
                    done = 1;
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    // Stay in DONE state until reset
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule