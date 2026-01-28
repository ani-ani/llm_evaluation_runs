module mirror_word_detector(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] char_data [0:15],
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] RESULT  = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;

    // Valid mirror characters lookup
    function is_valid_mirror_char;
        input [7:0] c;
        begin
            case (c)
                8'd65: is_valid_mirror_char = 1'b1;  // 'A'
                8'd72: is_valid_mirror_char = 1'b1;  // 'H'
                8'd73: is_valid_mirror_char = 1'b1;  // 'I'
                8'd77: is_valid_mirror_char = 1'b1;  // 'M'
                8'd79: is_valid_mirror_char = 1'b1;  // 'O'
                8'd84: is_valid_mirror_char = 1'b1;  // 'T'
                8'd85: is_valid_mirror_char = 1'b1;  // 'U'
                8'd86: is_valid_mirror_char = 1'b1;  // 'V'
                8'd87: is_valid_mirror_char = 1'b1;  // 'W'
                8'd88: is_valid_mirror_char = 1'b1;  // 'X'
                8'd89: is_valid_mirror_char = 1'b1;  // 'Y'
                default: is_valid_mirror_char = 1'b0;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        index <= 4'd0;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've processed all necessary pairs
                    if (index >= (len >> 1)) begin
                        state <= RESULT;
                    end else begin
                        // Check symmetry and validity
                        if (char_data[index] != char_data[len - 1 - index] || 
                            !is_valid_mirror_char(char_data[index]) ||
                            !is_valid_mirror_char(char_data[len - 1 - index])) begin
                            result <= 1'b0;
                            state <= RESULT;
                        end else begin
                            index <= index + 4'd1;
                        end
                    end
                end

                RESULT: begin
                    // If we get here without failing, all checks passed
                    if (index >= (len >> 1)) begin
                        result <= 1'b1;
                    end
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule