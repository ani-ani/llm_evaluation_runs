module quote_extractor(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] input_str,
    output reg [63:0] result_0,
    output reg [63:0] result_1,
    output reg [63:0] result_2,
    output reg [63:0] result_3,
    output reg [1:0] result_count,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] SEARCH_START = 4'd1;
    localparam [3:0] CAPTURE = 4'd2;
    localparam [3:0] SEARCH_END = 4'd3;
    localparam [3:0] COMPLETE = 4'd4;

    reg [3:0] state, next_state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd32;

    reg [3:0] char_index;
    reg [1:0] output_index;
    reg [2:0] char_pos;
    reg inside_quotes;

    reg [7:0] current_char;

    // Result registers
    reg [63:0] result_0_reg;
    reg [63:0] result_1_reg;
    reg [63:0] result_2_reg;
    reg [63:0] result_3_reg;
    reg [1:0] result_count_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 4'd0;
            char_index <= 4'd0;
            output_index <= 2'd0;
            char_pos <= 3'd0;
            inside_quotes <= 1'b0;
            current_char <= 8'd0;

            result_0 <= 64'd0;
            result_1 <= 64'd0;
            result_2 <= 64'd0;
            result_3 <= 64'd0;
            result_count <= 2'd0;
            done <= 1'b0;

            result_0_reg <= 64'd0;
            result_1_reg <= 64'd0;
            result_2_reg <= 64'd0;
            result_3_reg <= 64'd0;
            result_count_reg <= 2'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 4'd1;

            // Extract current character
            current_char <= input_str[char_index * 8 +: 8];

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result_count <= 2'd0;
                    if (start) begin
                        char_index <= 4'd0;
                        output_index <= 2'd0;
                        char_pos <= 3'd0;
                        inside_quotes <= 1'b0;
                        next_state <= SEARCH_START;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SEARCH_START: begin
                    if (current_char == 8'd34) begin
                        inside_quotes <= 1'b1;
                        next_state <= CAPTURE;
                    end else begin
                        char_index <= char_index + 4'd1;
                        if (char_index >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                            next_state <= COMPLETE;
                        end else begin
                            next_state <= SEARCH_START;
                        end
                    end
                end

                CAPTURE: begin
                    if (current_char == 8'd34) begin
                        inside_quotes <= 1'b0;
                        next_state <= SEARCH_END;
                    end else begin
                        // Store character in appropriate result register
                        case (output_index)
                            2'd0: result_0_reg[char_pos * 8 +: 8] <= current_char;
                            2'd1: result_1_reg[char_pos * 8 +: 8] <= current_char;
                            2'd2: result_2_reg[char_pos * 8 +: 8] <= current_char;
                            2'd3: result_3_reg[char_pos * 8 +: 8] <= current_char;
                            default: ;
                        endcase

                        char_pos <= char_pos + 3'd1;
                        char_index <= char_index + 4'd1;

                        if (char_pos >= 3'd8 || char_index >= 4'd16 || cycle_count >= MAX_CYCLES) begin
                            next_state <= SEARCH_END;
                        end else begin
                            next_state <= CAPTURE;
                        end
                    end
                end

                SEARCH_END: begin
                    if (current_char == 8'd34) begin
                        // Found another quote, increment output index
                        output_index <= output_index + 2'd1;
                        char_pos <= 3'd0;
                        inside_quotes <= 1'b1;
                        next_state <= CAPTURE;
                    end else begin
                        char_index <= char_index + 4'd1;
                        if (char_index >= 4'd16 || cycle_count >= MAX_CYCLES || output_index >= 2'd4) begin
                            next_state <= COMPLETE;
                        end else begin
                            next_state <= SEARCH_START;
                        end
                    end
                end

                COMPLETE: begin
                    // Update result outputs
                    result_0 <= result_0_reg;
                    result_1 <= result_1_reg;
                    result_2 <= result_2_reg;
                    result_3 <= result_3_reg;
                    result_count <= output_index;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end

endmodule