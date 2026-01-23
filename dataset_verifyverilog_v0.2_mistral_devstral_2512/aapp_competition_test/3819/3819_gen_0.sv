module card_game_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] hand [0:7],
    input [7:0] pile [0:7],
    output reg [7:0] result,
    output reg done
);

    // Parameters
    localparam IDLE = 3'b000;
    localparam LOAD = 3'b001;
    localparam CHECK_SEQ = 3'b010;
    localparam CALCULATE_COST = 3'b011;
    localparam DONE = 3'b100;

    // State register
    reg [2:0] state, next_state;

    // Registered inputs
    reg [7:0] hand_reg [0:7];
    reg [7:0] pile_reg [0:7];

    // Internal registers
    reg [7:0] max_cost;
    reg [7:0] direct_win_cost;
    reg [7:0] seq_length;
    reg [7:0] current_card;
    reg [7:0] pos [1:8];
    reg [7:0] i, j;
    reg [7:0] temp_cost;
    reg [7:0] counter;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD;
            end
            LOAD: next_state = CHECK_SEQ;
            CHECK_SEQ: begin
                if (counter == 8) next_state = CALCULATE_COST;
            end
            CALCULATE_COST: begin
                if (counter == 8) next_state = DONE;
            end
            DONE: begin
                if (!start) next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Load inputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 8; i = i + 1) begin
                hand_reg[i] <= 0;
                pile_reg[i] <= 0;
            end
        end else if (state == LOAD) begin
            for (i = 0; i < 8; i = i + 1) begin
                hand_reg[i] <= hand[i];
                pile_reg[i] <= pile[i];
            end
        end
    end

    // Check sequence
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            seq_length <= 0;
            direct_win_cost <= 0;
            counter <= 0;
        end else if (state == CHECK_SEQ) begin
            if (counter == 0) begin
                // Find position of '1' in pile
                for (i = 0; i < 8; i = i + 1) begin
                    if (pile_reg[i] == 1) begin
                        direct_win_cost <= i;
                        break;
                    end
                end
                // If '1' not in pile, direct_win_cost remains 0 (invalid)
                if (direct_win_cost != 0) begin
                    // Check sequence starting from '1'
                    seq_length <= 1;
                    for (i = direct_win_cost + 1; i < 8; i = i + 1) begin
                        if (pile_reg[i] == seq_length + 1) begin
                            seq_length <= seq_length + 1;
                        end else begin
                            break;
                        end
                    end
                end else begin
                    seq_length <= 0;
                end
            end
            counter <= counter + 1;
        end
    end

    // Calculate cost
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            max_cost <= 0;
            counter <= 0;
        end else if (state == CALCULATE_COST) begin
            if (counter == 0) begin
                // Initialize positions
                for (i = 1; i <= 8; i = i + 1) begin
                    pos[i] <= 0;
                end
                // Find positions of cards in pile
                for (i = 0; i < 8; i = i + 1) begin
                    if (pile_reg[i] != 0) begin
                        pos[pile_reg[i]] <= i;
                    end
                end
                // Check if direct win is valid
                if (direct_win_cost != 0 && seq_length == 8 - direct_win_cost) begin
                    // Check remaining cards in hand
                    reg valid;
                    valid = 1;
                    for (i = seq_length + 1; i <= 8; i = i + 1) begin
                        reg found;
                        found = 0;
                        for (j = 0; j < 8; j = j + 1) begin
                            if (hand_reg[j] == i) begin
                                found = 1;
                                break;
                            end
                        end
                        if (!found) begin
                            valid = 0;
                            break;
                        end
                    end
                    if (valid) begin
                        max_cost <= direct_win_cost;
                    end else begin
                        max_cost <= 0;
                    end
                end else begin
                    max_cost <= 0;
                end
            end else begin
                // Calculate max cost
                current_card <= counter;
                if (pos[current_card] == 0) begin
                    // Card is in hand
                    temp_cost <= 0 - current_card + 1 + 8;
                end else begin
                    // Card is in pile
                    temp_cost <= pos[current_card] - current_card + 1 + 8;
                end
                if (temp_cost > max_cost) begin
                    max_cost <= temp_cost;
                end
            end
            counter <= counter + 1;
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 0;
            result <= 0;
        end else if (state == DONE) begin
            done <= 1;
            result <= max_cost;
        end else begin
            done <= 0;
        end
    end

endmodule