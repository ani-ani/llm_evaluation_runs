module betting_game (
    input clk,
    input rst_n,
    input start,
    input [3:0] N_in,
    input [2:0] D_in,
    input [2:0] C_in,
    input [15:0] cesar_card,
    input [15:0] raul_card,
    output reg [31:0] result,
    output reg done,
    output reg valid
);

    // State machine states
    localparam [1:0] IDLE = 2'b00;
    localparam [1:0] INITIALIZE = 2'b01;
    localparam [1:0] COMPUTE = 2'b10;
    localparam [1:0] DONE = 2'b11;
    reg [1:0] state = IDLE;

    // DP table: 16 bits for Cesar, 16 bits for Raul
    reg [31:0] dp_table [0:65535];
    reg [31:0] new_dp_table [0:65535];

    // Parameters
    reg [3:0] N;
    reg [2:0] D;
    reg [2:0] C;

    // Precomputed combinations
    reg [31:0] comb [0:15][0:4];

    // Current state in computation
    reg [15:0] current_cesar;
    reg [15:0] current_raul;
    reg [15:0] next_cesar;
    reg [15:0] next_raul;

    // Iteration control
    reg [15:0] iteration;
    reg [15:0] max_iterations = 1000;

    // Convergence detection
    reg [31:0] max_diff;
    reg [31:0] convergence_threshold = 1; // Q16.16 threshold

    // Helper variables
    reg [15:0] i, j, k;
    reg [15:0] ball;
    reg [15:0] drawn_balls;
    reg [15:0] remaining_balls;
    reg [31:0] prob;
    reg [31:0] sum;
    reg [31:0] temp;

    // Precompute combinations
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            result <= 0;
        end else if (start && state == IDLE) begin
            state <= INITIALIZE;
            done <= 0;
            valid <= 0;
        end
    end

    // Initialize combinations
    always @(posedge clk) begin
        if (state == INITIALIZE) begin
            // Initialize combinations table
            for (i = 0; i <= 15; i = i + 1) begin
                for (j = 0; j <= 4; j = j + 1) begin
                    if (j == 0) begin
                        comb[i][j] <= 1;
                    end else if (j == 1) begin
                        comb[i][j] <= i + 1;
                    end else if (j > i) begin
                        comb[i][j] <= 0;
                    end else begin
                        comb[i][j] <= comb[i-1][j-1] + comb[i-1][j];
                    end
                end
            end

            // Initialize parameters
            N <= N_in;
            D <= D_in;
            C <= C_in;

            // Initialize DP table
            for (i = 0; i < 65536; i = i + 1) begin
                dp_table[i] <= 0;
                new_dp_table[i] <= 0;
            end

            // Set terminal states (win conditions)
            for (i = 0; i < 65536; i = i + 1) begin
                if (count_ones(i & cesar_card) == C) begin
                    dp_table[i] <= 0; // Cesar wins
                end else if (count_ones(i >> 16 & raul_card) == C) begin
                    dp_table[i] <= 0; // Raul wins
                end
            end

            state <= COMPUTE;
            iteration <= 0;
        end
    end

    // Compute expected values
    always @(posedge clk) begin
        if (state == COMPUTE) begin
            max_diff <= 0;

            // Iterate through all states
            for (i = 0; i < 65536; i = i + 1) begin
                current_cesar <= i[15:0];
                current_raul <= i[31:16];

                // Check if terminal state
                if (count_ones(current_cesar & cesar_card) == C || 
                    count_ones(current_raul & raul_card) == C) begin
                    new_dp_table[i] <= 0;
                end else begin
                    sum <= 0;

                    // Generate all possible combinations of D balls
                    for (j = 0; j < N; j = j + 1) begin
                        if (j < D) begin
                            drawn_balls <= 1 << j;
                        end else begin
                            drawn_balls <= 0;
                        end

                        // Calculate probability of this combination
                        prob <= (comb[N-1][D-1] << 16) / comb[N][D];

                        // Update next state
                        next_cesar <= current_cesar | (drawn_balls & cesar_card);
                        next_raul <= current_raul | (drawn_balls & raul_card);

                        // Calculate expected value
                        temp <= (prob * dp_table[{next_raul, next_cesar}]) >> 16;
                        sum <= sum + temp;
                    end

                    // E[state] = 1 + sum of probabilities * E[next_state]
                    new_dp_table[i] <= 65536 + sum;

                    // Check convergence
                    if (new_dp_table[i] > dp_table[i]) begin
                        temp <= new_dp_table[i] - dp_table[i];
                    end else begin
                        temp <= dp_table[i] - new_dp_table[i];
                    end

                    if (temp > max_diff) begin
                        max_diff <= temp;
                    end
                end
            end

            // Update DP table
            for (i = 0; i < 65536; i = i + 1) begin
                dp_table[i] <= new_dp_table[i];
            end

            // Check for convergence or max iterations
            iteration <= iteration + 1;
            if (max_diff <= convergence_threshold || iteration >= max_iterations) begin
                state <= DONE;
                result <= dp_table[0]; // Initial state (no marks)
                done <= 1;
                valid <= 1;
            end
        end else if (state == DONE && !start) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
        end
    end

    // Helper function to count ones
    function [3:0] count_ones;
        input [15:0] value;
        reg [3:0] count;
        integer k;
        begin
            count = 0;
            for (k = 0; k < 16; k = k + 1) begin
                if (value[k]) begin
                    count = count + 1;
                end
            end
            count_ones = count;
        end
    endfunction

endmodule