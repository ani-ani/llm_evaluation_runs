module QuoteExtractor (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] str,
    input wire [5:0] str_len,
    output reg [255:0] result,
    output reg [3:0] result_len,
    output reg done,
    output reg error
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] CAPTURE = 2'd2;
    localparam [1:0] ERROR = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [5:0] index;          // Current character index (0-63)
    reg in_quote;             // 1 if inside quoted text
    reg [3:0] token_count;    // Number of tokens extracted (0-15)
    reg [3:0] token_index;    // Current token being built (0-15)
    reg [2:0] char_count;     // Characters in current token (0-7)
    reg [31:0] token_buffer;  // 4 chars per cycle max (32-bit buffer)
    reg [255:0] result_reg;   // Accumulated result
    reg error_reg;
    reg start_latched;
    reg [2:0] cycle_counter;  // For CAPTURE state delay

    // Character extraction (combinational)
    reg [7:0] current_char;
    always @(*) begin
        case (index[2:0])
            3'd0: current_char = str[7:0];
            3'd1: current_char = str[15:8];
            3'd2: current_char = str[23:16];
            3'd3: current_char = str[31:24];
            3'd4: current_char = str[39:32];
            3'd5: current_char = str[47:40];
            3'd6: current_char = str[55:48];
            3'd7: current_char = str[63:56];
            default: current_char = 8'd0;
        endcase
    end

    // State machine and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 6'd0;
            in_quote <= 1'b0;
            token_count <= 4'd0;
            token_index <= 4'd0;
            char_count <= 3'd0;
            token_buffer <= 32'd0;
            result_reg <= 256'd0;
            error_reg <= 1'b0;
            done <= 1'b0;
            result <= 256'd0;
            result_len <= 4'd0;
            error <= 1'b0;
            start_latched <= 1'b0;
            cycle_counter <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    start_latched <= 1'b0;
                    if (start) begin
                        start_latched <= 1'b1;
                        // Validate input
                        if (str_len > 64 || str_len == 6'd0) begin
                            state <= ERROR;
                            error_reg <= 1'b1;
                        end else begin
                            index <= 6'd0;
                            in_quote <= 1'b0;
                            token_count <= 4'd0;
                            token_index <= 4'd0;
                            char_count <= 3'd0;
                            token_buffer <= 32'd0;
                            result_reg <= 256'd0;
                            error_reg <= 1'b0;
                            state <= SCAN;
                        end
                    end
                end

                SCAN: begin
                    if (index < str_len) begin
                        // Check for quote character
                        if (current_char == 8'h22) begin
                            in_quote <= ~in_quote;
                            
                            if (in_quote == 1'b0) begin
                                // Entering quoted section
                                if (token_count >= 15) begin
                                    state <= ERROR;
                                    error_reg <= 1'b1;
                                end
                            end else begin
                                // Exiting quoted section
                                if (char_count > 3'd0) begin
                                    // Finalize current token
                                    if (token_count < 15) begin
                                        // Store token in result_reg
                                        case (token_count)
                                            4'd0: result_reg[255:224] <= token_buffer;
                                            4'd1: result_reg[223:192] <= token_buffer;
                                            4'd2: result_reg[191:160] <= token_buffer;
                                            4'd3: result_reg[159:128] <= token_buffer;
                                            4'd4: result_reg[127:96] <= token_buffer;
                                            4'd5: result_reg[95:64] <= token_buffer;
                                            4'd6: result_reg[63:32] <= token_buffer;
                                            4'd7: result_reg[31:0] <= token_buffer;
                                            default: begin end
                                        endcase
                                        token_count <= token_count + 4'd1;
                                    end
                                end
                            end
                            char_count <= 3'd0;
                            token_buffer <= 32'd0;
                        end else if (in_quote) begin
                            // Inside quote - capture character
                            if (char_count < 3'd4) begin
                                token_buffer <= {token_buffer[23:0], current_char};
                                char_count <= char_count + 3'd1;
                            end else begin
                                state <= ERROR;
                                error_reg <= 1'b1;
                            end
                        end
                        index <= index + 6'd1;
                    end else begin
                        // Finished scanning
                        if (in_quote) begin
                            // Unbalanced quotes (missing closing quote)
                            state <= ERROR;
                            error_reg <= 1'b1;
                        end else begin
                            state <= CAPTURE;
                            cycle_counter <= 3'd0;
                        end
                    end
                end

                CAPTURE: begin
                    cycle_counter <= cycle_counter + 3'd1;
                    if (cycle_counter >= 3'd2) begin
                        // Finalize any partially filled token (in case of no closing quote)
                        if (char_count > 3'd0 && token_count < 15) begin
                            case (token_count)
                                4'd0: result_reg[255:224] <= token_buffer;
                                4'd1: result_reg[223:192] <= token_buffer;
                                4'd2: result_reg[191:160] <= token_buffer;
                                4'd3: result_reg[159:128] <= token_buffer;
                                4'd4: result_reg[127:96] <= token_buffer;
                                4'd5: result_reg[95:64] <= token_buffer;
                                4'd6: result_reg[63:32] <= token_buffer;
                                4'd7: result_reg[31:0] <= token_buffer;
                                default: begin end
                            endcase
                            token_count <= token_count + 4'd1;
                        end
                        
                        // Output results
                        result <= result_reg;
                        result_len <= token_count;
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end

                ERROR: begin
                    error <= 1'b1;
                    error_reg <= 1'b1;
                    done <= 1'b0;
                    // Remain in ERROR until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule