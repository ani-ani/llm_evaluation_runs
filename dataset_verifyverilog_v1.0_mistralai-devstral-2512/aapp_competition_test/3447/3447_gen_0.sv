module SMSKeypressCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire dictionary_valid,
    input wire [9:0][7:0] word_in,
    input wire [3:0] len_in,
    input wire query_valid,
    output reg done,
    output reg [7:0] result_char,
    output reg result_valid
);

    // Constants
    localparam [9:0] MAX_DICT_SIZE = 10'd1000;
    localparam [6:0] MAX_TARGET_LEN = 7'd100;
    localparam [3:0] MAX_WORD_LEN = 4'd10;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_DICT = 3'd1;
    localparam [2:0] LOAD_TARGET = 3'd2;
    localparam [2:0] COMPUTE_DP = 3'd3;
    localparam [2:0] OUTPUT_RESULT = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Dictionary storage
    reg [7:0] dictionary [0:999][0:9];
    reg [3:0] dict_len [0:999];
    reg [7:0] dict_digits [0:999][0:9];
    reg [9:0] dict_count;

    // Target storage
    reg [7:0] target [0:99];
    reg [6:0] target_len;
    reg [7:0] target_digits [0:99];

    // DP arrays
    reg [31:0] dp_cost [0:99];
    reg [9:0] dp_back [0:99];

    // Current state
    reg [2:0] state, next_state;

    // Counters and temporary registers
    reg [9:0] dict_ptr;
    reg [6:0] target_ptr;
    reg [9:0] dict_search_ptr;
    reg [9:0] word_ptr;
    reg [9:0] output_ptr;

    reg [31:0] current_cost;
    reg [31:0] min_cost;
    reg [9:0] min_index;
    reg [9:0] up_down_cost;

    reg [7:0] current_char;
    reg [7:0] current_digit;

    reg [9:0] match_count;
    reg [9:0] match_index;

    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd10000;

    // Character to digit mapping
    function [7:0] char_to_digit;
        input [7:0] c;
        begin
            if (c >= "a" && c <= "c") char_to_digit = "2";
            else if (c >= "d" && c <= "f") char_to_digit = "3";
            else if (c >= "g" && c <= "i") char_to_digit = "4";
            else if (c >= "j" && c <= "l") char_to_digit = "5";
            else if (c >= "m" && c <= "o") char_to_digit = "6";
            else if (c >= "p" && c <= "s") char_to_digit = "7";
            else if (c >= "t" && c <= "v") char_to_digit = "8";
            else if (c >= "w" && c <= "z") char_to_digit = "9";
            else char_to_digit = "0";
        end
    endfunction

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_valid <= 1'b0;
            dict_count <= 10'd0;
            dict_ptr <= 10'd0;
            target_ptr <= 7'd0;
            dict_search_ptr <= 10'd0;
            word_ptr <= 10'd0;
            output_ptr <= 10'd0;
            current_cost <= 32'd0;
            min_cost <= 32'd0;
            min_index <= 10'd0;
            up_down_cost <= 10'd0;
            current_char <= 8'd0;
            current_digit <= 8'd0;
            match_count <= 10'd0;
            match_index <= 10'd0;
            cycle_count <= 10'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = LOAD_DICT;
            end

            LOAD_DICT: begin
                if (dictionary_valid && dict_ptr == dict_count) next_state = LOAD_TARGET;
            end

            LOAD_TARGET: begin
                if (query_valid && target_ptr == target_len) next_state = COMPUTE_DP;
            end

            COMPUTE_DP: begin
                if (target_ptr == target_len) next_state = OUTPUT_RESULT;
            end

            OUTPUT_RESULT: begin
                if (output_ptr == target_len) next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Dictionary loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dict_count <= 10'd0;
            dict_ptr <= 10'd0;
        end else if (state == LOAD_DICT && dictionary_valid) begin
            if (dict_ptr < MAX_DICT_SIZE) begin
                // Store word
                for (word_ptr = 0; word_ptr < 10; word_ptr = word_ptr + 1) begin
                    dictionary[dict_ptr][word_ptr] <= word_in[word_ptr];
                end
                dict_len[dict_ptr] <= len_in;

                // Compute digit sequence
                for (word_ptr = 0; word_ptr < 10; word_ptr = word_ptr + 1) begin
                    dict_digits[dict_ptr][word_ptr] <= char_to_digit(word_in[word_ptr]);
                end

                dict_ptr <= dict_ptr + 10'd1;
                dict_count <= dict_ptr;
            end
        end
    end

    // Target loading
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_ptr <= 7'd0;
        end else if (state == LOAD_TARGET && query_valid) begin
            if (target_ptr < MAX_TARGET_LEN) begin
                target[target_ptr] <= word_in[0];
                target_digits[target_ptr] <= char_to_digit(word_in[0]);
                target_ptr <= target_ptr + 7'd1;
            end
        end
    end

    // DP computation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_ptr <= 7'd0;
            current_cost <= 32'd0;
            min_cost <= 32'd0;
            min_index <= 10'd0;
            match_count <= 10'd0;
            match_index <= 10'd0;
            up_down_cost <= 10'd0;
        end else if (state == COMPUTE_DP) begin
            if (target_ptr == 0) begin
                // Initialize first position
                dp_cost[0] <= 32'd0;
                dp_back[0] <= 10'd0;
                target_ptr <= target_ptr + 7'd1;
            end else begin
                // Find minimum cost for current position
                min_cost <= 32'd32'hFFFFFFFF;
                min_index <= 10'd0;

                // Search through dictionary
                for (dict_search_ptr = 0; dict_search_ptr < dict_count; dict_search_ptr = dict_search_ptr + 10'd1) begin
                    // Check if dictionary word matches target prefix
                    match_count <= 10'd0;
                    for (word_ptr = 0; word_ptr < dict_len[dict_search_ptr]; word_ptr = word_ptr + 10'd1) begin
                        if (dict_digits[dict_search_ptr][word_ptr] == target_digits[target_ptr - word_ptr]) begin
                            match_count <= match_count + 10'd1;
                        end
                    end

                    if (match_count == dict_len[dict_search_ptr]) begin
                        // Calculate cost
                        current_cost <= dp_cost[target_ptr - dict_len[dict_search_ptr]] + 32'd1; // 'R' press

                        // Add digit presses
                        for (word_ptr = 0; word_ptr < dict_len[dict_search_ptr]; word_ptr = word_ptr + 10'd1) begin
                            current_cost <= current_cost + 32'd1;
                        end

                        // Calculate up/down cost
                        match_index <= 10'd0;
                        for (word_ptr = 0; word_ptr < dict_count; word_ptr = word_ptr + 10'd1) begin
                            if (dict_digits[word_ptr][0] == dict_digits[dict_search_ptr][0]) begin
                                if (word_ptr < dict_search_ptr) begin
                                    match_index <= match_index + 10'd1;
                                end
                            end
                        end

                        up_down_cost <= match_index;
                        if (dict_count - match_index < match_index) begin
                            up_down_cost <= dict_count - match_index;
                        end

                        current_cost <= current_cost + up_down_cost;

                        // Update minimum
                        if (current_cost < min_cost) begin
                            min_cost <= current_cost;
                            min_index <= dict_search_ptr;
                        end
                    end
                end

                // Store result
                dp_cost[target_ptr] <= min_cost;
                dp_back[target_ptr] <= min_index;
                target_ptr <= target_ptr + 7'd1;
            end
        end
    end

    // Output generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_ptr <= 10'd0;
        end else if (state == OUTPUT_RESULT) begin
            if (output_ptr < target_len) begin
                if (dp_back[output_ptr] != 10'd0) begin
                    // Output the word from dictionary
                    word_ptr <= 10'd0;
                    while (word_ptr < dict_len[dp_back[output_ptr]]) begin
                        result_char <= dictionary[dp_back[output_ptr]][word_ptr];
                        result_valid <= 1'b1;
                        word_ptr <= word_ptr + 10'd1;
                        output_ptr <= output_ptr + 10'd1;
                    end
                end else begin
                    // Output single character
                    result_char <= target[output_ptr];
                    result_valid <= 1'b1;
                    output_ptr <= output_ptr + 10'd1;
                end
            end else begin
                result_valid <= 1'b0;
            end
        end
    end

    // Done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == DONE_STATE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter for safety
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 10'd0;
        end else if (cycle_count < MAX_CYCLES) begin
            cycle_count <= cycle_count + 10'd1;
        end
    end

endmodule