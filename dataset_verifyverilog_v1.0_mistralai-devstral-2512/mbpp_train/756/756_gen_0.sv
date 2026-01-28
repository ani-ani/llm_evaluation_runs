module pattern_matcher(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_char,
    input wire char_valid,
    input wire [3:0] input_string_len,
    output reg match,
    output reg done,
    output reg [3:0] char_index
);

    // State declarations
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_CHAR    = 3'd1;
    localparam [2:0] WAIT_FOR_B    = 3'd2;
    localparam [2:0] PATTERN_FOUND = 3'd3;
    localparam [2:0] PATTERN_FAIL  = 3'd4;
    localparam [2:0] DONE_STATE    = 3'd5;

    reg [2:0] state, next_state;
    reg [3:0] char_counter;
    reg [7:0] char_a = 8'd97;  // ASCII 'a'
    reg [7:0] char_b = 8'd98;  // ASCII 'b'

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            match <= 1'b0;
            done <= 1'b0;
            char_index <= 4'd0;
            char_counter <= 4'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    match <= 1'b0;
                    done <= 1'b0;
                    char_index <= 4'd0;
                    char_counter <= 4'd0;
                    if (start) begin
                        next_state <= CHECK_CHAR;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECK_CHAR: begin
                    if (char_valid) begin
                        char_index <= char_counter;
                        if (input_char == char_a) begin
                            next_state <= WAIT_FOR_B;
                        end else if (input_char == char_b) begin
                            next_state <= PATTERN_FAIL;
                        end else begin
                            next_state <= PATTERN_FAIL;
                        end
                        char_counter <= char_counter + 4'd1;
                        if (char_counter == input_string_len) begin
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        next_state <= CHECK_CHAR;
                    end
                end

                WAIT_FOR_B: begin
                    if (char_valid) begin
                        char_index <= char_counter;
                        if (input_char == char_b) begin
                            next_state <= PATTERN_FOUND;
                        end else if (input_char == char_a) begin
                            next_state <= WAIT_FOR_B;
                        end else begin
                            next_state <= PATTERN_FAIL;
                        end
                        char_counter <= char_counter + 4'd1;
                        if (char_counter == input_string_len) begin
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        next_state <= WAIT_FOR_B;
                    end
                end

                PATTERN_FOUND: begin
                    match <= 1'b1;
                    if (char_valid) begin
                        char_index <= char_counter;
                        char_counter <= char_counter + 4'd1;
                        if (char_counter == input_string_len) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= PATTERN_FOUND;
                        end
                    end else begin
                        next_state <= PATTERN_FOUND;
                    end
                end

                PATTERN_FAIL: begin
                    if (char_valid) begin
                        char_index <= char_counter;
                        if (input_char == char_a) begin
                            next_state <= WAIT_FOR_B;
                        end else begin
                            next_state <= PATTERN_FAIL;
                        end
                        char_counter <= char_counter + 4'd1;
                        if (char_counter == input_string_len) begin
                            next_state <= DONE_STATE;
                        end
                    end else begin
                        next_state <= PATTERN_FAIL;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    match <= 1'b0;
                    done <= 1'b0;
                    char_index <= 4'd0;
                    char_counter <= 4'd0;
                end
            endcase
        end
    end

endmodule