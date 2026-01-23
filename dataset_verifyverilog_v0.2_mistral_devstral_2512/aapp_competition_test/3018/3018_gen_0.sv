module dice_reroll_optimizer (
    input clk,
    input rst_n,
    input start,
    input [7:0] K,
    input [7:0] target,
    input [5:0] initial_rolls [7:0],
    output reg [3:0] optimal_k,
    output reg done
);

    // State definitions
    typedef enum logic [3:0] {
        IDLE,
        COMPUTE_SUM,
        CALCULATE_PROBABILITIES,
        EVALUATE_OPTIONS,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [7:0] total_sum;
    reg [3:0] k_counter;
    reg [3:0] s_counter;
    reg [3:0] i_counter;
    reg [3:0] j_counter;
    reg [3:0] m_counter;
    reg [3:0] best_k;
    reg [31:0] max_probability;
    reg [31:0] current_probability;
    reg [31:0] dp [0:8][6:38]; // dp[k][s] for k dice, sum s (6 to 38)
    reg [31:0] temp_dp [6:38];
    reg [31:0] remaining_sum;
    reg [31:0] temp_prob;
    reg [31:0] temp_max;

    // Precomputed probability lookup tables for small k
    reg [31:0] prob_1 [6:38];
    reg [31:0] prob_2 [6:38];
    reg [31:0] prob_3 [6:38];

    // Initialize lookup tables
    integer idx, s;
    initial begin
        // Initialize prob_1 (single die)
        for (s = 1; s <= 6; s = s + 1) begin
            prob_1[s] = 16'd16666; // 1/6 in Q16.16
        end
        for (s = 7; s <= 38; s = s + 1) begin
            prob_1[s] = 16'd0;
        end

        // Initialize prob_2 (two dice)
        for (s = 2; s <= 12; s = s + 1) begin
            if (s <= 7) begin
                prob_2[s] = 16'd16666 * (s - 1);
            end else begin
                prob_2[s] = 16'd16666 * (13 - s);
            end
        end
        for (s = 13; s <= 38; s = s + 1) begin
            prob_2[s] = 16'd0;
        end

        // Initialize prob_3 (three dice)
        for (s = 3; s <= 18; s = s + 1) begin
            if (s <= 10) begin
                prob_3[s] = 16'd16666 * ((s - 1) * (s - 2) / 2);
            end else if (s <= 14) begin
                prob_3[s] = 16'd16666 * (21 - s * 2);
            end else begin
                prob_3[s] = 16'd16666 * ((20 - s) * (21 - s) / 2);
            end
        end
        for (s = 19; s <= 38; s = s + 1) begin
            prob_3[s] = 16'd0;
        end
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            done <= 1'b0;
            optimal_k <= 4'd0;
            total_sum <= 8'd0;
            k_counter <= 4'd0;
            s_counter <= 4'd0;
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            m_counter <= 4'd0;
            best_k <= 4'd0;
            max_probability <= 32'd0;
            current_probability <= 32'd0;
            remaining_sum <= 32'd0;
            temp_prob <= 32'd0;
            temp_max <= 32'd0;

            // Initialize dp table
            for (idx = 0; idx <= 8; idx = idx + 1) begin
                for (s = 6; s <= 38; s = s + 1) begin
                    dp[idx][s] <= 32'd0;
                end
            end
        end else begin
            current_state <= next_state;
        end
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPUTE_SUM;
                end
            end

            COMPUTE_SUM: begin
                // Compute sum of initial dice rolls
                if (i_counter < K) begin
                    total_sum = total_sum + initial_rolls[i_counter];
                    i_counter = i_counter + 1;
                end else begin
                    i_counter = 4'd0;
                    next_state = CALCULATE_PROBABILITIES;
                end
            end

            CALCULATE_PROBABILITIES: begin
                // Compute probability distributions for k dice
                if (k_counter < K) begin
                    if (k_counter == 1'b0) begin
                        // Base case: 0 dice
                        dp[0][0] = 32'd16777216; // 1.0 in Q16.16
                        k_counter = k_counter + 1;
                    end else if (k_counter == 1'b1) begin
                        // Use lookup table for k=1
                        for (s = 6; s <= 38; s = s + 1) begin
                            dp[1][s] = prob_1[s];
                        end
                        k_counter = k_counter + 1;
                    end else if (k_counter == 2'b10) begin
                        // Use lookup table for k=2
                        for (s = 6; s <= 38; s = s + 1) begin
                            dp[2][s] = prob_2[s];
                        end
                        k_counter = k_counter + 1;
                    end else if (k_counter == 3'b11) begin
                        // Use lookup table for k=3
                        for (s = 6; s <= 38; s = s + 1) begin
                            dp[3][s] = prob_3[s];
                        end
                        k_counter = k_counter + 1;
                    end else begin
                        // Compute dp[k] from dp[k-1]
                        if (s_counter < 38) begin
                            if (j_counter < 6) begin
                                temp_dp[s_counter + j_counter + 1] = temp_dp[s_counter + j_counter + 1] + dp[k_counter - 1][s_counter] * prob_1[j_counter + 1];
                                j_counter = j_counter + 1;
                            end else begin
                                j_counter = 4'd0;
                                s_counter = s_counter + 1;
                            end
                        end else begin
                            // Copy temp_dp to dp[k_counter]
                            for (s = 6; s <= 38; s = s + 1) begin
                                dp[k_counter][s] = temp_dp[s];
                            end
                            s_counter = 4'd0;
                            j_counter = 4'd0;
                            k_counter = k_counter + 1;
                        end
                    end
                end else begin
                    k_counter = 4'd0;
                    next_state = EVALUATE_OPTIONS;
                end
            end

            EVALUATE_OPTIONS: begin
                // Evaluate all k from 0 to K
                if (k_counter <= K) begin
                    if (i_counter < K) begin
                        if (j_counter < k_counter) begin
                            // Compute remaining sum by excluding j_counter dice
                            if (m_counter < K) begin
                                if (m_counter != i_counter) begin
                                    remaining_sum = remaining_sum + initial_rolls[m_counter];
                                end
                                m_counter = m_counter + 1;
                            end else begin
                                // Compute probability for this remaining sum
                                temp_prob = dp[k_counter][target - remaining_sum];
                                if (temp_prob > current_probability) begin
                                    current_probability = temp_prob;
                                end
                                m_counter = 4'd0;
                                remaining_sum = 32'd0;
                                j_counter = j_counter + 1;
                            end
                        end else begin
                            j_counter = 4'd0;
                            // Compare with max_probability
                            if (current_probability > max_probability || (current_probability == max_probability && k_counter < best_k)) begin
                                max_probability = current_probability;
                                best_k = k_counter;
                            end
                            current_probability = 32'd0;
                            i_counter = i_counter + 1;
                        end
                    end else begin
                        i_counter = 4'd0;
                        k_counter = k_counter + 1;
                    end
                end else begin
                    optimal_k = best_k;
                    next_state = DONE;
                end
            end

            DONE: begin
                done = 1'b1;
                if (!start) begin
                    next_state = IDLE;
                    done = 1'b0;
                end
            end

            default: next_state = IDLE;
        endcase
    end

endmodule