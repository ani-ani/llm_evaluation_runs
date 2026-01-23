module chess_domino_max_sum (
    input clk,
    input rst_n,
    input start,
    input [2:0] row_index,
    input [31:0] board_value,
    input [3:0] K,
    input [2:0] N,
    output reg [31:0] max_sum,
    output reg done,
    output reg valid
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam COMPUTE = 3'b010;
    localparam DONE = 3'b100;

    // Board storage (8x3)
    reg [31:0] board [0:7][0:2];
    reg [2:0] load_row;
    reg [1:0] load_col;

    // DP state
    reg [31:0] dp [0:8][0:8][0:7]; // dp[k][state][row]
    reg [31:0] dp_next [0:8][0:7];

    // State machine
    reg [2:0] state;
    reg [2:0] current_row;
    reg [3:0] current_k;
    reg [2:0] current_state;

    // Control signals
    reg load_complete;
    reg compute_complete;

    // Initialize outputs
    initial begin
        max_sum = 32'b0;
        done = 1'b0;
        valid = 1'b0;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_row <= 0;
            load_col <= 0;
            current_row <= 0;
            current_k <= 0;
            current_state <= 0;
            load_complete <= 0;
            compute_complete <= 0;
            done <= 0;
            valid <= 0;
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_row <= 0;
                        load_col <= 0;
                        load_complete <= 0;
                    end
                end
                LOAD: begin
                    if (load_row == N && load_col == 0) begin
                        state <= COMPUTE;
                        load_complete <= 1;
                        current_row <= 0;
                        current_k <= 0;
                        current_state <= 0;
                    end
                end
                COMPUTE: begin
                    if (current_row == N && current_k == K) begin
                        state <= DONE;
                        compute_complete <= 1;
                    end
                end
                DONE: begin
                    if (start) begin
                        state <= IDLE;
                        done <= 0;
                        valid <= 0;
                    end
                end
            endcase
        end
    end

    // Load board values
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 3; j++) begin
                    board[i][j] <= 0;
                end
            end
        end else if (state == LOAD && load_row < N) begin
            if (load_col == 0) begin
                board[load_row][0] <= board_value;
                load_col <= 1;
            end else if (load_col == 1) begin
                board[load_row][1] <= board_value;
                load_col <= 2;
            end else begin
                board[load_row][2] <= board_value;
                load_col <= 0;
                load_row <= load_row + 1;
            end
        end
    end

    // DP computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (int k = 0; k <= 8; k++) begin
                for (int s = 0; s < 8; s++) begin
                    dp[k][s][0] <= 0;
                end
            end
        end else if (state == COMPUTE && !compute_complete) begin
            // Initialize dp_next
            for (int k = 0; k <= 8; k++) begin
                for (int s = 0; s < 8; s++) begin
                    dp_next[k][s] <= -32'h80000000;
                end
            end

            // Process current row
            if (current_row < N) begin
                for (int k = 0; k <= K; k++) begin
                    for (int s = 0; s < 8; s++) begin
                        if (dp[k][s][current_row] != -32'h80000000) begin
                            // Try all possible placements
                            // 1. No domino in this row
                            if (dp_next[k][s] < dp[k][s][current_row]) begin
                                dp_next[k][s] <= dp[k][s][current_row];
                            end

                            // 2. Horizontal dominoes
                            // Horizontal in columns 0-1
                            if (k < K && (s & 3'b110) == 0) begin
                                reg [31:0] sum = dp[k][s][current_row] + board[current_row][0] + board[current_row][1];
                                if (dp_next[k+1][s] < sum) begin
                                    dp_next[k+1][s] <= sum;
                                end
                            end

                            // Horizontal in columns 1-2
                            if (k < K && (s & 3'b011) == 0) begin
                                reg [31:0] sum = dp[k][s][current_row] + board[current_row][1] + board[current_row][2];
                                if (dp_next[k+1][s] < sum) begin
                                    dp_next[k+1][s] <= sum;
                                end
                            end

                            // 3. Vertical dominoes
                            if (current_row < N-1) begin
                                // Vertical in column 0
                                if (k < K && (s & 3'b001) == 0) begin
                                    reg [31:0] sum = dp[k][s][current_row] + board[current_row][0] + board[current_row+1][0];
                                    if (dp_next[k+1][s | 3'b001] < sum) begin
                                        dp_next[k+1][s | 3'b001] <= sum;
                                    end
                                end

                                // Vertical in column 1
                                if (k < K && (s & 3'b010) == 0) begin
                                    reg [31:0] sum = dp[k][s][current_row] + board[current_row][1] + board[current_row+1][1];
                                    if (dp_next[k+1][s | 3'b010] < sum) begin
                                        dp_next[k+1][s | 3'b010] <= sum;
                                    end
                                end

                                // Vertical in column 2
                                if (k < K && (s & 3'b100) == 0) begin
                                    reg [31:0] sum = dp[k][s][current_row] + board[current_row][2] + board[current_row+1][2];
                                    if (dp_next[k+1][s | 3'b100] < sum) begin
                                        dp_next[k+1][s | 3'b100] <= sum;
                                    end
                                end
                            end
                        end
                    end
                end

                // Update dp for next row
                for (int k = 0; k <= K; k++) begin
                    for (int s = 0; s < 8; s++) begin
                        dp[k][s][current_row+1] <= dp_next[k][s];
                    end
                end

                // Move to next row
                current_row <= current_row + 1;
            end else begin
                // Final row processing
                for (int k = 0; k <= K; k++) begin
                    for (int s = 0; s < 8; s++) begin
                        if (dp[k][s][N] != -32'h80000000) begin
                            if (k == K && s == 0) begin
                                if (max_sum < dp[k][s][N]) begin
                                    max_sum <= dp[k][s][N];
                                end
                            end
                        end
                    end
                end
                compute_complete <= 1;
            end
        end
    end

    // Output control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            valid <= 0;
        end else if (state == DONE) begin
            done <= 1;
            valid <= 1;
        end else begin
            done <= 0;
            valid <= 0;
        end
    end

endmodule