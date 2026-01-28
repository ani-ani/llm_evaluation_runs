module binary_town_voting(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] k,
    input wire [6:0] v,
    input wire [15:0] prob_0, prob_1, prob_2, prob_3, prob_4,
    input wire [15:0] prob_5, prob_6, prob_7, prob_8, prob_9,
    input wire [7:0] ballots_0, ballots_1, ballots_2, ballots_3, ballots_4,
    input wire [7:0] ballots_5, ballots_6, ballots_7, ballots_8, ballots_9,
    input wire [3:0] num_voters,
    output reg [7:0] optimal_ballots,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD_PROBS = 3'd1;
    localparam [2:0] DP_COMPUTE = 3'd2;
    localparam [2:0] EVALUATE   = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] voter_idx;
    reg [7:0] sum_idx;
    reg [7:0] bv_idx;
    reg [7:0] batch_idx;
    reg [15:0] prob_table [0:255];
    reg [15:0] current_prob;
    reg [15:0] best_score;
    reg [7:0] best_ballots;
    reg [7:0] temp_sum;
    reg [7:0] temp_ballot;
    reg [15:0] temp_prob;
    reg [15:0] temp_score;
    reg [7:0] temp_count;
    reg [7:0] temp_mask;
    reg [7:0] temp_total;
    reg [7:0] temp_popcount;
    reg [15:0] temp_accum;
    reg [7:0] i;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            voter_idx <= 8'd0;
            sum_idx <= 8'd0;
            bv_idx <= 8'd0;
            batch_idx <= 8'd0;
            optimal_ballots <= 8'd0;
            done <= 1'b0;
            best_score <= 16'd0;
            best_ballots <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                prob_table[i] <= 16'd0;
            end
            prob_table[0] <= 16'd256; // 1.0 in Q8.8
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD_PROBS;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD_PROBS: begin
                if (voter_idx == num_voters) begin
                    next_state = DP_COMPUTE;
                end else begin
                    next_state = LOAD_PROBS;
                end
            end

            DP_COMPUTE: begin
                if (sum_idx == 8'd255) begin
                    if (voter_idx == num_voters) begin
                        next_state = EVALUATE;
                    end else begin
                        next_state = DP_COMPUTE;
                    end
                end else begin
                    next_state = DP_COMPUTE;
                end
            end

            EVALUATE: begin
                if (bv_idx == 8'd255) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = EVALUATE;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // LOAD_PROBS state logic
    always @(posedge clk) begin
        if (state == LOAD_PROBS) begin
            if (voter_idx < num_voters) begin
                // Load voter data
                case (voter_idx)
                    4'd0: begin temp_ballot = ballots_0; temp_prob = prob_0; end
                    4'd1: begin temp_ballot = ballots_1; temp_prob = prob_1; end
                    4'd2: begin temp_ballot = ballots_2; temp_prob = prob_2; end
                    4'd3: begin temp_ballot = ballots_3; temp_prob = prob_3; end
                    4'd4: begin temp_ballot = ballots_4; temp_prob = prob_4; end
                    4'd5: begin temp_ballot = ballots_5; temp_prob = prob_5; end
                    4'd6: begin temp_ballot = ballots_6; temp_prob = prob_6; end
                    4'd7: begin temp_ballot = ballots_7; temp_prob = prob_7; end
                    4'd8: begin temp_ballot = ballots_8; temp_prob = prob_8; end
                    4'd9: begin temp_ballot = ballots_9; temp_prob = prob_9; end
                    default: begin temp_ballot = 8'd0; temp_prob = 16'd0; end
                endcase
                voter_idx <= voter_idx + 8'd1;
            end
        end
    end

    // DP_COMPUTE state logic
    always @(posedge clk) begin
        if (state == DP_COMPUTE) begin
            if (sum_idx < 8'd256) begin
                // Compute new probability
                temp_sum = sum_idx - temp_ballot;
                temp_prob = (prob_table[sum_idx] * (256 - temp_prob[15:8])) + 
                           (prob_table[temp_sum] * temp_prob[15:8]);
                prob_table[sum_idx] <= temp_prob[15:0];
                sum_idx <= sum_idx + 8'd1;
            end else begin
                sum_idx <= 8'd0;
                voter_idx <= voter_idx + 8'd1;
            end
        end
    end

    // EVALUATE state logic
    always @(posedge clk) begin
        if (state == EVALUATE) begin
            if (batch_idx < 4) begin
                // Process 4 sums in parallel
                temp_sum = (batch_idx * 4) + sum_idx;
                if (temp_sum < 256) begin
                    temp_total = (temp_sum + bv_idx) & 255;
                    temp_mask = (1 << k) - 1;
                    temp_popcount = 0;
                    for (i = 0; i < k; i = i + 1) begin
                        if (temp_total[i]) begin
                            temp_popcount = temp_popcount + 1;
                        end
                    end
                    temp_accum = temp_accum + (prob_table[temp_sum] * temp_popcount);
                end
                batch_idx <= batch_idx + 1;
            end else begin
                batch_idx <= 0;
                if (sum_idx == 8'd63) begin
                    // End of batch
                    temp_score = temp_accum >> 8; // Fixed-point scaling
                    if (temp_score > best_score) begin
                        best_score <= temp_score;
                        best_ballots <= bv_idx;
                    end
                    sum_idx <= 0;
                    bv_idx <= bv_idx + 1;
                    temp_accum <= 0;
                end else begin
                    sum_idx <= sum_idx + 1;
                    temp_accum <= 0;
                end
            end
        end
    end

    // DONE_STATE logic
    always @(posedge clk) begin
        if (state == DONE_STATE) begin
            optimal_ballots <= best_ballots;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule