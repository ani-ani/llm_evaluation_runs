module ExpectedScoreCalculator(
    input clk,
    input rst_n,
    input start,
    input data_valid,
    input data_last,
    input [7:0] data_in,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_INPUT = 3'd1;
    localparam [2:0] BUILD_TRIE = 3'd2;
    localparam [2:0] COMPUTE_DP = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;

    reg [2:0] state, next_state;

    // Input parsing registers
    reg [7:0] total_time;
    reg [7:0] num_questions;
    reg [7:0] current_question;
    reg [7:0] current_word;
    reg [7:0] word_count;
    reg [7:0] word_length;
    reg [7:0] word_buffer [0:3]; // Max 4 words per question
    reg [7:0] answer_id;
    reg [7:0] byte_counter;
    reg [7:0] input_index;

    // Trie structure
    localparam MAX_NODES = 5'd32;
    localparam MAX_CHILDREN = 4'd16;

    // Trie node memory (BRAM)
    reg [7:0] trie_child_ptr [0:MAX_NODES-1] [0:MAX_CHILDREN-1];
    reg [7:0] trie_question_count [0:MAX_NODES-1];

    // Current node management
    reg [4:0] current_node;
    reg [4:0] root_node;
    reg [4:0] node_counter;

    // DP table memory (BRAM)
    reg [15:0] dp_table [0:MAX_NODES-1] [0:8]; // T up to 8

    // DP computation registers
    reg [4:0] dp_time;
    reg [4:0] dp_node;
    reg [15:0] dp_value;
    reg [15:0] max_value;

    // Fixed-point arithmetic helpers
    function [15:0] fixed_divide;
        input [15:0] numerator;
        input [7:0] denominator;
        reg [15:0] result_reg;
        integer i;
        begin
            if (denominator == 0) begin
                result_reg = 16'd0;
            end else begin
                result_reg = 16'd0;
                for (i = 0; i < 16; i = i + 1) begin
                    result_reg = result_reg << 1;
                    if (result_reg[16:1] < denominator) begin
                        result_reg[0] = numerator[15];
                        numerator = numerator << 1;
                    end else begin
                        result_reg[16:1] = result_reg[16:1] - denominator;
                        result_reg[0] = numerator[15];
                        numerator = numerator << 1;
                    end
                end
            end
            fixed_divide = result_reg;
        end
    endfunction

    function [15:0] fixed_multiply;
        input [15:0] a;
        input [15:0] b;
        reg [31:0] temp;
        begin
            temp = a * b;
            fixed_multiply = temp[31:16];
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 16'd0;

            // Reset input parsing
            total_time <= 8'd0;
            num_questions <= 8'd0;
            current_question <= 8'd0;
            current_word <= 8'd0;
            word_count <= 8'd0;
            word_length <= 8'd0;
            byte_counter <= 8'd0;
            input_index <= 8'd0;

            // Reset trie
            node_counter <= 5'd0;
            current_node <= 5'd0;
            root_node <= 5'd0;

            // Reset DP
            dp_time <= 5'd0;
            dp_node <= 5'd0;

            // Initialize trie memory
            integer i, j;
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                trie_question_count[i] <= 8'd0;
                for (j = 0; j < MAX_CHILDREN; j = j + 1) begin
                    trie_child_ptr[i][j] <= 8'd255; // 0xFF means no child
                end
            end

            // Initialize DP table
            for (i = 0; i < MAX_NODES; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    dp_table[i][j] <= 16'd0;
                end
            end

        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = READ_INPUT;
                end
            end

            READ_INPUT: begin
                if (data_last) begin
                    next_state = BUILD_TRIE;
                end
            end

            BUILD_TRIE: begin
                if (current_question == num_questions) begin
                    next_state = COMPUTE_DP;
                end
            end

            COMPUTE_DP: begin
                if (dp_time == total_time && dp_node == node_counter - 1) begin
                    next_state = OUTPUT_RESULT;
                end
            end

            OUTPUT_RESULT: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Input parsing FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else begin
            case (state)
                READ_INPUT: begin
                    if (data_valid) begin
                        case (byte_counter)
                            0: total_time <= data_in;
                            1: num_questions <= data_in;
                            default: begin
                                if (current_question < num_questions) begin
                                    case (word_count)
                                        0: word_length <= data_in;
                                        default: begin
                                            if (word_count <= word_length) begin
                                                word_buffer[word_count - 1] <= data_in;
                                            end
                                            if (word_count == word_length + 1) begin
                                                answer_id <= data_in;
                                            end
                                        end
                                    endcase
                                end
                            end
                        endcase

                        if (data_last) begin
                            byte_counter <= 8'd0;
                            current_question <= 8'd0;
                            word_count <= 8'd0;
                        end else begin
                            byte_counter <= byte_counter + 1;
                            if (byte_counter > 1 && current_question < num_questions) begin
                                if (word_count == 0) begin
                                    word_count <= 1;
                                end else if (word_count <= word_length) begin
                                    word_count <= word_count + 1;
                                end else if (word_count == word_length + 1) begin
                                    word_count <= 0;
                                    current_question <= current_question + 1;
                                end
                            end
                        end
                    end
                end
            endcase
        end
    end

    // Trie building FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else if (state == BUILD_TRIE) begin
            // Build trie from parsed data
            // This is a simplified version - actual implementation would need
            // to process the word_buffer and build the trie structure
            // For synthesis, we'll just mark this as complete
            current_question <= current_question + 1;
            if (current_question == num_questions) begin
                // Trie building complete
            end
        end
    end

    // DP computation FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already reset above
        end else if (state == COMPUTE_DP) begin
            // Compute DP values
            // This is a simplified version - actual implementation would
            // compute the DP recurrence relation
            if (dp_time == 0) begin
                if (dp_node < node_counter) begin
                    dp_table[dp_node][0] <= 16'd0;
                    dp_node <= dp_node + 1;
                end else begin
                    dp_time <= dp_time + 1;
                    dp_node <= 0;
                end
            end else if (dp_time <= total_time) begin
                if (dp_node < node_counter) begin
                    // Compute DP[dp_time][dp_node]
                    // This is a placeholder - actual computation would go here
                    dp_table[dp_node][dp_time] <= 16'd0;
                    dp_node <= dp_node + 1;
                end else begin
                    dp_time <= dp_time + 1;
                    dp_node <= 0;
                end
            end
        end
    end

    // Output result
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            case (state)
                OUTPUT_RESULT: begin
                    result <= dp_table[root_node][total_time];
                    done <= 1'b1;
                end
                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule