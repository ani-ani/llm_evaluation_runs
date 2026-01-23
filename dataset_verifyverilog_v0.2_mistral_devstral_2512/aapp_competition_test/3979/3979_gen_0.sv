module lexicographical_solver (
    input clk,
    input rst_n,
    input start,
    input [3:0] word_len_1,
    input [15:0] word_1 [16],
    input [3:0] word_len_2,
    input [15:0] word_2 [16],
    output reg [15:0] capitalization_mask,
    output reg valid,
    output reg impossible
);

    // State definitions
    typedef enum logic [1:0] {
        IDLE,
        COMPARE,
        PROPAGATE,
        DONE
    } state_t;

    state_t current_state, next_state;

    // Internal registers
    reg [3:0] index;
    reg [15:0] constraints [16]; // For each letter, store constraints
    reg [15:0] dependencies [16]; // For each letter, store dependencies
    reg [15:0] temp_mask;
    reg [3:0] min_len;
    reg conflict;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            index <= 0;
            capitalization_mask <= 0;
            valid <= 0;
            impossible <= 0;
            conflict <= 0;
            temp_mask <= 0;
            for (int i = 0; i < 16; i++) begin
                constraints[i] <= 0;
                dependencies[i] <= 0;
            end
        else
            current_state <= next_state;
    end

    // State machine logic
    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = COMPARE;
                    index = 0;
                    min_len = (word_len_1 < word_len_2) ? word_len_1 : word_len_2;
                    conflict = 0;
                    temp_mask = 0;
                    for (int i = 0; i < 16; i++) begin
                        constraints[i] = 0;
                        dependencies[i] = 0;
                    end
                end
            end
            COMPARE: begin
                if (index < min_len) begin
                    if (word_1[index] != word_2[index]) begin
                        if (word_1[index] > word_2[index]) begin
                            // word1 char must be capitalized, word2 char must not
                            constraints[word_1[index]] = 1'b1;
                            constraints[word_2[index]] = 1'b0;
                        end else begin
                            // Both must have same capitalization
                            dependencies[word_1[index]] = word_2[index];
                            dependencies[word_2[index]] = word_1[index];
                        end
                        next_state = PROPAGATE;
                    end else begin
                        index = index + 1;
                    end
                end else if (word_len_1 > word_len_2) begin
                    // word1 is longer, so its next char must be capitalized
                    constraints[word_1[min_len]] = 1'b1;
                    next_state = PROPAGATE;
                end else if (word_len_1 < word_len_2) begin
                    // word2 is longer, so its next char must not be capitalized
                    constraints[word_2[min_len]] = 1'b0;
                    next_state = PROPAGATE;
                end else begin
                    next_state = DONE;
                end
            end
            PROPAGATE: begin
                // Propagate constraints
                for (int i = 0; i < 16; i++) begin
                    if (constraints[i] == 1'b1) begin
                        // If a letter is capitalized, propagate to dependencies
                        if (dependencies[i] != 0) begin
                            if (constraints[dependencies[i]] == 1'b0) begin
                                conflict = 1'b1;
                            end else begin
                                constraints[dependencies[i]] = 1'b1;
                            end
                        end
                    end else if (constraints[i] == 1'b0) begin
                        // If a letter is not capitalized, propagate to dependencies
                        if (dependencies[i] != 0) begin
                            if (constraints[dependencies[i]] == 1'b1) begin
                                conflict = 1'b1;
                            end else begin
                                constraints[dependencies[i]] = 1'b0;
                            end
                        end
                    end
                end
                // Build the mask
                temp_mask = 0;
                for (int i = 0; i < 16; i++) begin
                    if (constraints[i] == 1'b1) begin
                        temp_mask[i] = 1'b1;
                    end
                end
                next_state = DONE;
            end
            DONE: begin
                if (conflict) begin
                    impossible = 1'b1;
                    valid = 1'b0;
                end else begin
                    capitalization_mask = temp_mask;
                    valid = 1'b1;
                    impossible = 1'b0;
                end
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

endmodule