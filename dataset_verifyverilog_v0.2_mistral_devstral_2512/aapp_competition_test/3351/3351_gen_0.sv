module yahtzee_solver (
    input clk,
    input rst_n,
    input start,
    input [5:0] num_rolls,
    input [2:0] dice_in [0:64],
    output reg [11:0] max_score,
    output reg done
);

    // State definitions
    typedef enum logic [2:0] {
        IDLE,
        RESET,
        ROUND_LOOP,
        ROLL_STRATEGY,
        SCORE_CALC,
        UPDATE_DP,
        DONE
    } state_t;

    state_t state, next_state;

    // DP table: [round][dice_index] -> max_score
    reg [11:0] dp [0:12][0:64];

    // Current round and dice index
    reg [3:0] current_round;
    reg [5:0] current_dice_index;

    // Current hand and re-roll masks
    reg [2:0] current_hand [0:4];
    reg [4:0] keep_mask1, keep_mask2;

    // Temporary score calculation
    reg [11:0] temp_score;

    // Counters for re-roll strategies
    reg [4:0] mask1_counter;
    reg [4:0] mask2_counter;

    // Category score calculation
    function automatic [11:0] calculate_score;
        input [2:0] hand [0:4];
        input [3:0] category;
        reg [11:0] score;
        reg [5:0] counts [1:6];
        integer i, j;

        // Initialize counts
        for (i = 1; i <= 6; i = i + 1) begin
            counts[i] = 0;
        end

        // Count dice values
        for (i = 0; i < 5; i = i + 1) begin
            counts[hand[i]] = counts[hand[i]] + 1;
        end

        // Calculate score based on category
        case (category)
            0: score = counts[1] * 1; // Ones
            1: score = counts[2] * 2; // Twos
            2: score = counts[3] * 3; // Threes
            3: score = counts[4] * 4; // Fours
            4: score = counts[5] * 5; // Fives
            5: score = counts[6] * 6; // Sixes
            6: begin // 3-of-a-Kind
                for (i = 1; i <= 6; i = i + 1) begin
                    if (counts[i] >= 3) begin
                        score = hand[0] + hand[1] + hand[2] + hand[3] + hand[4];
                    end
                end
            end
            7: begin // 4-of-a-Kind
                for (i = 1; i <= 6; i = i + 1) begin
                    if (counts[i] >= 4) begin
                        score = hand[0] + hand[1] + hand[2] + hand[3] + hand[4];
                    end
                end
            end
            8: begin // Full House
                reg has_three = 0, has_two = 0;
                for (i = 1; i <= 6; i = i + 1) begin
                    if (counts[i] == 3) has_three = 1;
                    if (counts[i] == 2) has_two = 1;
                end
                if (has_three && has_two) score = 25;
            end
            9: begin // Small Straight
                reg [5:0] straight_mask = 0;
                for (i = 0; i < 5; i = i + 1) begin
                    straight_mask[hand[i]] = 1;
                end
                if (straight_mask[5:2] == 4'b1111 || straight_mask[6:3] == 4'b1111 || straight_mask[4:1] == 4'b1111) score = 30;
            end
            10: begin // Long Straight
                reg [5:0] straight_mask = 0;
                for (i = 0; i < 5; i = i + 1) begin
                    straight_mask[hand[i]] = 1;
                end
                if (straight_mask[5:1] == 5'b11111 || straight_mask[6:2] == 5'b11111) score = 40;
            end
            11: score = hand[0] + hand[1] + hand[2] + hand[3] + hand[4]; // Chance
            12: begin // Yahtzee
                for (i = 1; i <= 6; i = i + 1) begin
                    if (counts[i] == 5) score = 50;
                end
            end
        endcase

        calculate_score = score;
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            max_score <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = RESET;
            end
            RESET: begin
                next_state = ROUND_LOOP;
            end
            ROUND_LOOP: begin
                if (current_round == 12) begin
                    next_state = DONE;
                end else begin
                    next_state = ROLL_STRATEGY;
                end
            end
            ROLL_STRATEGY: begin
                if (mask1_counter == 31 && mask2_counter == 31) begin
                    next_state = UPDATE_DP;
                end else begin
                    next_state = SCORE_CALC;
                end
            end
            SCORE_CALC: begin
                next_state = ROLL_STRATEGY;
            end
            UPDATE_DP: begin
                next_state = ROUND_LOOP;
            end
            DONE: begin
                done = 1;
            end
        endcase
    end

    // State actions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            current_round <= 0;
            current_dice_index <= 0;
            mask1_counter <= 0;
            mask2_counter <= 0;
            keep_mask1 <= 0;
            keep_mask2 <= 0;
            temp_score <= 0;
        end else begin
            case (state)
                RESET: begin
                    // Initialize DP table
                    integer i, j;
                    for (i = 0; i < 13; i = i + 1) begin
                        for (j = 0; j < 65; j = j + 1) begin
                            dp[i][j] = 0;
                        end
                    end
                    current_round <= 0;
                    current_dice_index <= 0;
                end
                ROUND_LOOP: begin
                    if (current_round < 12) begin
                        current_dice_index <= current_dice_index + 1;
                        if (current_dice_index >= num_rolls) begin
                            current_round <= current_round + 1;
                            current_dice_index <= 0;
                        end
                    end
                end
                ROLL_STRATEGY: begin
                    if (mask1_counter == 31) begin
                        mask1_counter <= 0;
                        mask2_counter <= mask2_counter + 1;
                    end else begin
                        mask1_counter <= mask1_counter + 1;
                    end
                    keep_mask1 <= mask1_counter;
                    keep_mask2 <= mask2_counter;
                end
                SCORE_CALC: begin
                    // Simulate re-rolls and calculate score
                    reg [2:0] temp_hand [0:4];
                    integer i, j, k, dice_ptr;

                    // First roll: use dice from input
                    dice_ptr = current_dice_index;
                    for (i = 0; i < 5; i = i + 1) begin
                        if (keep_mask1[i]) begin
                            temp_hand[i] = dice_in[dice_ptr];
                            dice_ptr = dice_ptr + 1;
                        end
                    end

                    // Second roll: re-roll non-kept dice
                    for (i = 0; i < 5; i = i + 1) begin
                        if (!keep_mask1[i]) begin
                            if (dice_ptr < num_rolls) begin
                                temp_hand[i] = dice_in[dice_ptr];
                                dice_ptr = dice_ptr + 1;
                            end
                        end
                    end

                    // Third roll: re-roll non-kept dice from second roll
                    for (i = 0; i < 5; i = i + 1) begin
                        if (!keep_mask2[i]) begin
                            if (dice_ptr < num_rolls) begin
                                temp_hand[i] = dice_in[dice_ptr];
                                dice_ptr = dice_ptr + 1;
                            end
                        end
                    end

                    // Calculate score for current category
                    temp_score = calculate_score(temp_hand, current_round);
                end
                UPDATE_DP: begin
                    // Update DP table with best score
                    if (temp_score > dp[current_round][current_dice_index]) begin
                        dp[current_round][current_dice_index] = temp_score;
                    end
                    mask1_counter <= 0;
                    mask2_counter <= 0;
                end
                DONE: begin
                    // Find maximum score in last round
                    integer i;
                    max_score = 0;
                    for (i = 0; i < 65; i = i + 1) begin
                        if (dp[12][i] > max_score) begin
                            max_score = dp[12][i];
                        end
                    end
                end
            endcase
        end
    end

endmodule