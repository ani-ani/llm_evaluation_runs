module linear_congruence_solver (
    input clk,
    input rst_n,
    input start,
    input [7:0] expr_char_0,
    input [7:0] expr_char_1,
    input [7:0] expr_char_2,
    input [7:0] expr_char_3,
    input [7:0] expr_char_4,
    input [7:0] expr_char_5,
    input [7:0] expr_char_6,
    input [7:0] expr_char_7,
    input [19:0] P,
    input [19:0] M,
    output reg [19:0] result_x,
    output reg done,
    output reg error
);

// State definitions
localparam IDLE = 2'd0, PARSE = 2'd1, COMPUTE = 2'd2, DONE = 2'd3, ERROR = 2'd4;

// Registers for parsing
reg [7:0] expr_chars_reg [7:0];
reg [31:0] current_index;
reg [31:0] temp_num;
reg is_parsing_number;
reg [31:0] parsing_A, parsing_B;
reg [2:0] state;
reg [19:0] A, B, C;
reg [19:0] result_x_reg;
reg done_reg, error_reg;

// EEA variables
reg [31:0] old_r, r, old_s, s, old_t, t;
reg [2:0] eea_state;
reg [31:0] quotient;
reg eea_done;

// Initialize registers
always @(posedge clk) begin
    if (!rst_n) begin
        expr_chars_reg <= 8'b0;
        current_index <= 32'd0;
        temp_num <= 32'd0;
        is_parsing_number <= 1'b0;
        parsing_A <= 32'd0;
        parsing_B <= 32'd0;
        state <= IDLE;
        A <= 32'd0;
        B <= 32'd0;
        C <= 32'd0;
        result_x_reg <= 32'd0;
        done_reg <= 1'b0;
        error_reg <= 1'b0;
        old_r <= 32'd0;
        r <= 32'd0;
        old_s <= 32'd0;
        s <= 32'd0;
        old_t <= 32'd0;
        t <= 32'd0;
        eea_state <= 3'd0;
        eea_done <= 1'b0;
        quotient <= 32'd0;
    end else begin
        if (state == IDLE) begin
            if (start) begin
                // Latch expression characters
                expr_chars_reg <= {expr_char_0, expr_char_1, expr_char_2, expr_char_3, expr_char_4, expr_char_5, expr_char_6, expr_char_7};
                current_index <= 32'd0;
                temp_num <= 32'd0;
                is_parsing_number <= 1'b0;
                parsing_A <= 32'd0;
                parsing_B <= 32'd0;
                state <= PARSE;
            end
        end else if (state == PARSE) begin
            if (current_index < 8) begin
                // Process current character
                char = expr_chars_reg[current_index];
                if (char >= '0' && char <= '9') begin
                    temp_num = temp_num * 10 + (char - '0');
                    is_parsing_number = 1'b1;
                    current_index = current_index + 1;
                end else if (char == '*') begin
                    if (current_index + 1 < 8 && expr_chars_reg[current_index + 1] == 'x') begin
                        parsing_A = parsing_A + temp_num;
                        temp_num = 32'd0;
                        is_parsing_number = 1'b0;
                        current_index = current_index + 2;
                    end else begin
                        // Invalid syntax, set error
                        error_reg = 1'b1;
                        state = DONE;
                    end
                end else if (char == 'x') begin
                    if (is_parsing_number) begin
                        // Invalid, no '*' before x
                        error_reg = 1'b1;
                        state = DONE;
                    end else begin
                        parsing_A = parsing_A + 1;
                        current_index = current_index + 1;
                    end
                end else if (char == '+') begin
                    // Ignore, move to next
                    current_index = current_index + 1;
                end else begin
                    // Ignore other characters
                    current_index = current_index + 1;
                end
            end else begin
                // End of parsing, check for remaining number
                if (is_parsing_number) begin
                    parsing_B = parsing_B + temp_num;
                end
                // Assign parsed values
                A = parsing_A;
                B = parsing_B;
                // Move to compute state
                state = COMPUTE;
                // Compute C = (P - B) mod M
                C = (P - B + M) % M;
                if (C < 0) C += M; // Ensure non-negative
                C = C % M;
            end
        end else if (state == COMPUTE) begin
            // Compute GCD and EEA
            if (A == 0) begin
                // Special case: equation is B ≡ P mod M
                if ((P - B) % M != 0) begin
                    error_reg = 1'b1;
                    state = DONE;
                end else begin
                    // Any x is solution, choose 0
                    result_x_reg = 32'd0;
                    state = DONE;
                    done_reg = 1'b1;
                end
            end else begin
                // Initialize EEA variables
                old_r <= A;
                r <= M;
                old_s <= 32'd1;
                s <= 32'd0;
                old_t <= 32'd0;
                t <= 32'd1;
                eea_state <= 3'd0;
                eea_done <= 1'b0;
                // Proceed with EEA
                if (r == 0) begin
                    // M divides A, then solution exists if C is 0
                    if (C != 0) begin
                        error_reg = 1'b1;
                        state = DONE;
                    end else begin
                        // Infinite solutions, choose x=0
                        result_x_reg = 32'd0;
                        state = DONE;
                        done_reg = 1'b1;
                    end
                end else begin
                    // Start EEA iterations
                    eea_state <= 3'd1; // START_EEA
                end
            end
        end else if (state == DONE) begin
            if (error_reg) begin
                error = 1'b1;
            end else begin
                result_x = result_x_reg;
                done = done_reg;
                error = error_reg;
            end
        end
    end
endmodule