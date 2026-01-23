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

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PARSE   = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    localparam [2:0] ERROR   = 3'd3;

    reg [2:0] state;
    reg [3:0] char_idx;
    reg [2:0] current_token_idx;
    reg [3:0] token_char_idx;
    reg in_token;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            done <= 1'b0;
            error <= 1'b0;
            token_count <= 3'd0;
            char_idx <= 4'd0;
            current_token_idx <= 3'd0;
            token_char_idx <= 4'd0;
            in_token <= 1'b0;
            
            // Clear tokens array
            for (i = 0; i < MAX_TOKENS; i = i + 1) begin
                for (j = 0; j < MAX_TOKEN_LEN; j = j + 1) begin
                    tokens[i][j] <= {CHAR_WIDTH{1'b0}};
                end
            end
        end
        else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        state <= PARSE;
                        char_idx <= 4'd0;
                        current_token_idx <= 3'd0;
                        token_char_idx <= 4'd0;
                        in_token <= 1'b0;
                        token_count <= 3'd0;
                        
                        // Initialize output tokens
                        for (i = 0; i < MAX_TOKENS; i = i + 1) begin
                            for (j = 0; j < MAX_TOKEN_LEN; j = j + 1) begin
                                tokens[i][j] <= {CHAR_WIDTH{1'b0}};
                            end
                        end
                    end
                end

                PARSE: begin
                    if (char_idx < MAX_INPUT_LEN) begin
                        // Detect end of string (null terminator)
                        if (input_string[char_idx] == {CHAR_WIDTH{1'b0}}) begin
                            if (in_token) begin
                                if (current_token_idx >= MAX_TOKENS) begin
                                    error <= 1'b1;
                                    state <= ERROR;
                                end
                                else begin
                                    token_count <= token_count + 3'd1;
                                    current_token_idx <= current_token_idx + 3'd1;
                                end
                            end
                            state <= FINISH;
                        end
                        else if (input_string[char_idx] == 8'h20) begin  // Space character
                            if (in_token) begin
                                if (current_token_idx >= MAX_TOKENS) begin
                                    error <= 1'b1;
                                    state <= ERROR;
                                end
                                else begin
                                    token_count <= token_count + 3'd1;
                                    current_token_idx <= current_token_idx + 3'd1;
                                    token_char_idx <= 4'd0;
                                    in_token <= 1'b0;
                                end
                            end
                            char_idx <= char_idx + 4'd1;
                        end
                        else begin  // Normal character
                            if (!in_token) begin
                                in_token <= 1'b1;
                            end
                            
                            if (in_token && (token_char_idx < MAX_TOKEN_LEN) && (current_token_idx < MAX_TOKENS)) begin
                                tokens[current_token_idx][token_char_idx] <= input_string[char_idx];
                                token_char_idx <= token_char_idx + 4'd1;
                            end
                            else if (token_char_idx >= MAX_TOKEN_LEN) begin
                                error <= 1'b1;
                                state <= ERROR;
                            end
                            char_idx <= char_idx + 4'd1;
                        end
                    end
                    else begin
                        state <= FINISH;
                        if (in_token) begin
                            if (current_token_idx >= MAX_TOKENS) begin
                                error <= 1'b1;
                                state <= ERROR;
                            end
                            else begin
                                token_count <= token_count + 3'd1;
                            end
                        end
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                ERROR: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule