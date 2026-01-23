module goldbach_checker (
    input clk,
    input rst_n,
    input [7:0] char_in,
    input char_valid,
    input char_last,
    output reg result,
    output reg done
);

localparam IDLE = 3'd0;
localparam PARSING_TOKEN = 3'd1;
localparam VERIFY_PRIME_1 = 3'd2;
localparam VERIFY_PRIME_2 = 3'd3;
localparam VERIFY_SUM = 3'd4;
localparam VALID = 3'd5;
localparam INVALID = 3'd6;

reg [2:0] state;
reg [15:0] current_token;
reg [7:0] current_token_length;
reg [15:0] token_values [3];
reg [2:0] token_count;
reg leading_zero;
reg error_occurred;
reg done_reg;
localparam MAX_FIRST = 50000;

always @(negedge rst_n) begin
    state <= IDLE;
    current_token <= 0;
    current_token_length <= 0;
    token_count <= 0;
    token_values <= 0;
    leading_zero <= 0;
    error_occurred <= 0;
    done_reg <= 0;
    result <= 0;
end

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        current_token <= 0;
        current_token_length <= 0;
        token_count <= 0;
        token_values <= 0;
        leading_zero <= 0;
        error_occurred <= 0;
        done_reg <= 0;
        result <= 0;
    end else if (char_valid) begin
        if (state == IDLE) begin
            if (char_in == ' ') begin
                // Stay in IDLE
            end else if (char_in >= '0' && char_in <= '9') begin
                state <= PARSING_TOKEN;
                current_token <= char_in - '0';
                current_token_length <= 1;
                leading_zero <= (char_in == '0');
                token_count <= token_count;
            end else begin
                error_occurred <= 1;
                state <= INVALID;
            end
        end
    end
    done <= done_reg;
    if (state == VALID) begin
        result <= 1;
        done_reg <= 1;
    end else if (error_occurred || state == INVALID) begin
        result <= 0;
        done_reg <= 1;
    end
endmodule