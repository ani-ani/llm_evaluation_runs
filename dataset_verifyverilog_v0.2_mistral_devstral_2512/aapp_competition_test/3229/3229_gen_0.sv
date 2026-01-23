module RankingSystem (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [2:0] m,
    input [7:0] scores [0:7][0:9],
    output reg [3:0] result_rank,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        SORT_SCORES,
        SUM_TOP4,
        COMPARE_RANKS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [2:0] current_contestant;
    reg [3:0] current_contest;
    reg [3:0] outer_loop;
    reg [3:0] inner_loop;
    reg [7:0] temp_scores [0:7][0:9];
    reg [15:0] aggregate_scores [0:7];
    reg [15:0] my_aggregate;
    reg [3:0] rank_counter;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 0;
            result_rank <= 0;
            current_contestant <= 0;
            current_contest <= 0;
            outer_loop <= 0;
            inner_loop <= 0;
            rank_counter <= 0;
            my_aggregate <= 0;
            for (int i = 0; i < 8; i++) begin
                for (int j = 0; j < 10; j++) begin
                    temp_scores[i][j] <= 0;
                end
                aggregate_scores[i] <= 0;
            end
        end else begin
            current_state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = SORT_SCORES;
                    // Copy scores to temp array
                    for (int i = 0; i < m; i++) begin
                        for (int j = 0; j < n; j++) begin
                            temp_scores[i][j] = scores[i][j];
                        end
                    end
                    current_contestant = 0;
                    current_contest = 0;
                end
            end
            SORT_SCORES: begin
                // Bubble sort for each contestant's scores
                if (outer_loop < n - 1) begin
                    if (inner_loop < n - outer_loop - 1) begin
                        if (temp_scores[current_contestant][inner_loop] < temp_scores[current_contestant][inner_loop + 1]) begin
                            // Swap
                            reg [7:0] temp;
                            temp = temp_scores[current_contestant][inner_loop];
                            temp_scores[current_contestant][inner_loop] = temp_scores[current_contestant][inner_loop + 1];
                            temp_scores[current_contestant][inner_loop + 1] = temp;
                        end
                        inner_loop = inner_loop + 1;
                    end else begin
                        inner_loop = 0;
                        outer_loop = outer_loop + 1;
                    end
                end else begin
                    outer_loop = 0;
                    inner_loop = 0;
                    if (current_contestant < m - 1) begin
                        current_contestant = current_contestant + 1;
                    end else begin
                        next_state = SUM_TOP4;
                        current_contestant = 0;
                    end
                end
            end
            SUM_TOP4: begin
                // Sum top 4 scores for each contestant
                if (current_contest < 4 && current_contest < n) begin
                    aggregate_scores[current_contestant] = aggregate_scores[current_contestant] + temp_scores[current_contestant][current_contest];
                    current_contest = current_contest + 1;
                end else begin
                    current_contest = 0;
                    if (current_contestant < m - 1) begin
                        current_contestant = current_contestant + 1;
                    end else begin
                        next_state = COMPARE_RANKS;
                        current_contestant = 0;
                        my_aggregate = aggregate_scores[0];
                        rank_counter = 0;
                    end
                end
            end
            COMPARE_RANKS: begin
                // Compare contestant 0's score with others
                if (current_contestant < m) begin
                    if (current_contestant != 0 && aggregate_scores[current_contestant] > my_aggregate) begin
                        rank_counter = rank_counter + 1;
                    end
                    current_contestant = current_contestant + 1;
                end else begin
                    next_state = DONE;
                    result_rank = rank_counter + 1;
                    done = 1;
                end
            end
            DONE: begin
                if (!start) begin
                    next_state = IDLE;
                    done = 0;
                end
            end
        endcase
    end

endmodule