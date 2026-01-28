module pachinko(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] u,
    input wire [7:0] d,
    input wire [7:0] l,
    input wire [7:0] r,
    input wire [511:0] grid_flat,
    output reg result_valid,
    output reg [15:0] target_prob_0,
    output reg [15:0] target_prob_1,
    output reg [15:0] target_prob_2,
    output reg [15:0] target_prob_3,
    output reg [15:0] target_prob_4,
    output reg [15:0] target_prob_5,
    output reg [15:0] target_prob_6,
    output reg [15:0] target_prob_7,
    output reg [15:0] target_prob_8,
    output reg [15:0] target_prob_9,
    output reg [15:0] target_prob_10,
    output reg [15:0] target_prob_11,
    output reg [15:0] target_prob_12,
    output reg [15:0] target_prob_13,
    output reg [15:0] target_prob_14,
    output reg [15:0] target_prob_15
);

    // Constants
    localparam [3:0] W = 4'd16;
    localparam [3:0] H = 4'd16;
    localparam [8:0] MAX_ITER = 9'd512;

    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD_GRID = 2'd1;
    localparam [1:0] SOLVE = 2'd2;
    localparam [1:0] OUTPUT = 2'd3;

    // Grid storage
    reg [1:0] grid [0:15][0:15];
    reg [15:0] prob [0:15][0:15];

    // Target tracking
    reg [3:0] target_count;
    reg [3:0] target_indices [0:15];

    // Control signals
    reg [1:0] state;
    reg [8:0] iter_count;
    reg [3:0] row, col;
    reg [15:0] u_fixed, d_fixed, l_fixed, r_fixed;
    reg [15:0] sum_prob;
    reg [3:0] target_idx;

    // Normalize probabilities to fixed-point
    always @(*) begin
        u_fixed = (u * 16'd4096) / 100; // Q4.12: 4096 = 1.0
        d_fixed = (d * 16'd4096) / 100;
        l_fixed = (l * 16'd4096) / 100;
        r_fixed = (r * 16'd4096) / 100;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_valid <= 1'b0;
            iter_count <= 9'd0;
            row <= 4'd0;
            col <= 4'd0;
            target_count <= 4'd0;
            sum_prob <= 16'd0;
            target_idx <= 4'd0;

            // Initialize grid and probabilities
            integer i, j;
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    grid[i][j] <= 2'd0;
                    prob[i][j] <= 16'd0;
                end
            end

            // Initialize target probabilities
            target_prob_0 <= 16'd0;
            target_prob_1 <= 16'd0;
            target_prob_2 <= 16'd0;
            target_prob_3 <= 16'd0;
            target_prob_4 <= 16'd0;
            target_prob_5 <= 16'd0;
            target_prob_6 <= 16'd0;
            target_prob_7 <= 16'd0;
            target_prob_8 <= 16'd0;
            target_prob_9 <= 16'd0;
            target_prob_10 <= 16'd0;
            target_prob_11 <= 16'd0;
            target_prob_12 <= 16'd0;
            target_prob_13 <= 16'd0;
            target_prob_14 <= 16'd0;
            target_prob_15 <= 16'd0;

            // Initialize target indices
            for (i = 0; i < 16; i = i + 1) begin
                target_indices[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    if (start) begin
                        state <= LOAD_GRID;
                        row <= 4'd0;
                        col <= 4'd0;
                        target_count <= 4'd0;
                    end
                end

                LOAD_GRID: begin
                    // Load grid from flat input
                    integer addr;
                    addr = row * 16 + col;
                    grid[row][col] <= grid_flat[2*addr + 1:2*addr];

                    // Check if current cell is a target
                    if (grid[row][col] == 2'd2) begin
                        target_indices[target_count] <= row * 16 + col;
                        target_count <= target_count + 4'd1;
                    end

                    // Move to next cell
                    if (col == 15) begin
                        if (row == 15) begin
                            state <= SOLVE;
                            iter_count <= 9'd0;
                            row <= 4'd0;
                            col <= 4'd0;
                        end else begin
                            row <= row + 4'd1;
                            col <= 4'd0;
                        end
                    end else begin
                        col <= col + 4'd1;
                    end
                end

                SOLVE: begin
                    // Compute probability for current cell
                    if (grid[row][col] == 2'd1) begin
                        prob[row][col] <= 16'd0; // Wall
                    end else if (grid[row][col] == 2'd2) begin
                        prob[row][col] <= 16'd4096; // Target (1.0)
                    end else begin
                        // Empty cell: compute weighted sum
                        reg [15:0] up_prob, down_prob, left_prob, right_prob;
                        reg [15:0] total;

                        // Up neighbor
                        if (row == 0 || grid[row-1][col] == 2'd1) begin
                            up_prob = prob[row][col];
                        end else begin
                            up_prob = prob[row-1][col];
                        end

                        // Down neighbor
                        if (row == 15 || grid[row+1][col] == 2'd1) begin
                            down_prob = prob[row][col];
                        end else begin
                            down_prob = prob[row+1][col];
                        end

                        // Left neighbor
                        if (col == 0 || grid[row][col-1] == 2'd1) begin
                            left_prob = prob[row][col];
                        end else begin
                            left_prob = prob[row][col-1];
                        end

                        // Right neighbor
                        if (col == 15 || grid[row][col+1] == 2'd1) begin
                            right_prob = prob[row][col];
                        end else begin
                            right_prob = prob[row][col+1];
                        end

                        // Weighted sum
                        total = (u_fixed * up_prob) + (d_fixed * down_prob) + 
                                (l_fixed * left_prob) + (r_fixed * right_prob);
                        prob[row][col] <= total >> 12; // Scale back to Q4.12
                    end

                    // Move to next cell
                    if (col == 15) begin
                        if (row == 15) begin
                            // End of iteration
                            iter_count <= iter_count + 9'd1;
                            if (iter_count >= MAX_ITER) begin
                                state <= OUTPUT;
                                row <= 4'd0;
                                col <= 4'd0;
                                sum_prob <= 16'd0;
                                target_idx <= 4'd0;
                            end else begin
                                row <= 4'd0;
                                col <= 4'd0;
                            end
                        end else begin
                            row <= row + 4'd1;
                            col <= 4'd0;
                        end
                    end else begin
                        col <= col + 4'd1;
                    end
                end

                OUTPUT: begin
                    // Sum top row probabilities
                    if (col == 0) begin
                        sum_prob <= prob[0][0];
                    end else if (col < 16) begin
                        sum_prob <= sum_prob + prob[0][col];
                    end

                    // Move to next column
                    if (col == 15) begin
                        // Compute average and assign to target probabilities
                        reg [15:0] avg_prob;
                        avg_prob = sum_prob >> 4; // Divide by 16

                        // Assign to target outputs
                        if (target_idx < target_count) begin
                            case (target_idx)
                                4'd0: target_prob_0 <= avg_prob;
                                4'd1: target_prob_1 <= avg_prob;
                                4'd2: target_prob_2 <= avg_prob;
                                4'd3: target_prob_3 <= avg_prob;
                                4'd4: target_prob_4 <= avg_prob;
                                4'd5: target_prob_5 <= avg_prob;
                                4'd6: target_prob_6 <= avg_prob;
                                4'd7: target_prob_7 <= avg_prob;
                                4'd8: target_prob_8 <= avg_prob;
                                4'd9: target_prob_9 <= avg_prob;
                                4'd10: target_prob_10 <= avg_prob;
                                4'd11: target_prob_11 <= avg_prob;
                                4'd12: target_prob_12 <= avg_prob;
                                4'd13: target_prob_13 <= avg_prob;
                                4'd14: target_prob_14 <= avg_prob;
                                4'd15: target_prob_15 <= avg_prob;
                            endcase
                            target_idx <= target_idx + 4'd1;
                        end else begin
                            result_valid <= 1'b1;
                            state <= IDLE;
                        end
                    end else begin
                        col <= col + 4'd1;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule