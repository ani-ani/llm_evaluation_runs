module string_splitter #(
    parameter MAX_INPUT_LEN = 8,
    parameter MAX_TOKENS = 4,
    parameter MAX_TOKEN_LEN = 8,
    parameter CHAR_WIDTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [CHAR_WIDTH-1:0] input_string [MAX_INPUT_LEN-1:0],
    output reg [CHAR_WIDTH-1:0] tokens [MAX_TOKENS-1:0][MAX_TOKEN_LEN-1:0],
    output reg [2:0] token_count,
    output reg done,
    output reg error
);

    // State machine states
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PARSE = 3'd1;
    localparam [2:0] FINISHED = 3'd2;
    localparam [2:0] ERROR_STATE = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] token_idx;
    reg [3:0] char_idx;
    reg [3:0] token_char_idx;
    reg [CHAR_WIDTH-1:0] current_token [MAX_TOKEN_LEN-1:0];
    reg [3:0] current_token_len;
    reg in_token;
    reg error_detected;

    integer i;

    // State register and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            token_count <= 3'd0;
            done <= 1'b0;
            error <= 1'b0;
            token_idx <= 3'd0;
            char_idx <= 4'd0;
            token_char_idx <= 4'd0;
            current_token_len <= 4'd0;
            in_token <= 1'b0;
            error_detected <= 1'b0;
            // Clear output tokens
            for (i = 0; i < MAX_TOKENS; i = i + 1) begin
                tokens[i][0] <= 8'd0; tokens[i][1] <= 8'd0; tokens[i][2] <= 8'd0; tokens[i][3] <= 8'd0;
                tokens[i][4] <= 8'd0; tokens[i][5] <= 8'd0; tokens[i][6] <= 8'd0; tokens[i][7] <= 8'd0;
            end
            // Clear current_token
            for (i = 0; i < MAX_TOKEN_LEN; i = i + 1)
                current_token[i] <= 8'd0;
        end else begin
            state <= next_state;
            
            if (state == IDLE && start) begin
                token_idx <= 3'd0;
                char_idx <= 4'd0;
                token_char_idx <= 4'd0;
                current_token_len <= 4'd0;
                in_token <= 1'b0;
                done <= 1'b0;
                error <= 1'b0;
                error_detected <= 1'b0;
                token_count <= 3'd0;
                for (i = 0; i < MAX_TOKEN_LEN; i = i + 1)
                    current_token[i] <= 8'd0;
            end
            
            if (state == PARSE) begin
                if (char_idx < MAX_INPUT_LEN && !error_detected) begin
                    // Read current character
                    if (input_string[char_idx] != 8'd0) begin
                        if (input_string[char_idx] == 8'h20) begin
                            // Space character
                            if (in_token) begin
                                // End current token
                                if (token_idx < MAX_TOKENS) begin
                                    for (i = 0; i < MAX_TOKEN_LEN; i = i + 1) begin
                                        if (i < current_token_len)
                                            tokens[token_idx][i] <= current_token[i];
                                        else
                                            tokens[token_idx][i] <= 8'd0;
                                    end
                                    token_idx <= token_idx + 3'd1;
                                    token_count <= token_idx + 3'd1;
                                end else begin
                                    error_detected <= 1'b1;
                                end
                                in_token <= 1'b0;
                                token_char_idx <= 4'd0;
                                current_token_len <= 4'd0;
                                // Clear current_token
                                for (i = 0; i < MAX_TOKEN_LEN; i = i + 1)
                                    current_token[i] <= 8'd0;
                            end
                        end else begin
                            // Non-space character
                            in_token <= 1'b1;
                            if (token_char_idx < MAX_TOKEN_LEN) begin
                                current_token[token_char_idx] <= input_string[char_idx];
                                token_char_idx <= token_char_idx + 4'd1;
                                current_token_len <= token_char_idx + 4'd1;
                            end else begin
                                error_detected <= 1'b1;
                            end
                        end
                    end else begin
                        // Null terminator
                        if (in_token) begin
                            // Add final token
                            if (token_idx < MAX_TOKENS) begin
                                for (i = 0; i < MAX_TOKEN_LEN; i = i + 1) begin
                                    if (i < current_token_len)
                                        tokens[token_idx][i] <= current_token[i];
                                    else
                                        tokens[token_idx][i] <= 8'd0;
                                end
                                token_count <= token_idx + 3'd1;
                            end else begin
                                error_detected <= 1'b1;
                            end
                        end
                        next_state <= FINISHED;
                    end
                    char_idx <= char_idx + 4'd1;
                end else begin
                    if (error_detected) begin
                        next_state <= ERROR_STATE;
                    end else if (char_idx >= MAX_INPUT_LEN) begin
                        // Reached end of input buffer
                        if (in_token) begin
                            if (token_idx < MAX_TOKENS) begin
                                for (i = 0; i < MAX_TOKEN_LEN; i = i + 1) begin
                                    if (i < current_token_len)
                                        tokens[token_idx][i] <= current_token[i];
                                    else
                                        tokens[token_idx][i] <= 8'd0;
                                end
                                token_count <= token_idx + 3'd1;
                            end else begin
                                error_detected <= 1'b1;
                                next_state <= ERROR_STATE;
                            end
                        end
                        if (!error_detected)
                            next_state <= FINISHED;
                    end
                end
            end
            
            if (state == FINISHED || state == ERROR_STATE) begin
                done <= 1'b1;
                if (state == ERROR_STATE)
                    error <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PARSE;
                else
                    next_state = IDLE;
            end
            PARSE: begin
                if (error_detected)
                    next_state = ERROR_STATE;
                else if (char_idx >= MAX_INPUT_LEN && !in_token)
                    next_state = FINISHED;
            end
            FINISHED: next_state = FINISHED;
            ERROR_STATE: next_state = ERROR_STATE;
            default: next_state = IDLE;
        endcase
    end

endmodule