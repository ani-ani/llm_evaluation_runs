module vowel_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] str_data [0:15],
    input [3:0] str_len,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] vowel_count;
    reg [7:0] current_char;
    reg is_last_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            vowel_count <= 4'd0;
            result <= 4'd0;
            done <= 1'b0;
            current_char <= 8'd0;
            is_last_char <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        vowel_count <= 4'd0;
                    end
                end

                PROCESS: begin
                    current_char <= str_data[index];
                    is_last_char <= (index == (str_len - 1));

                    // Check if current character is a vowel
                    if ((current_char == 8'd97 || current_char == 8'd65) ||  // 'a' or 'A'
                        (current_char == 8'd101 || current_char == 8'd69) ||  // 'e' or 'E'
                        (current_char == 8'd105 || current_char == 8'd73) ||  // 'i' or 'I'
                        (current_char == 8'd111 || current_char == 8'd79) ||  // 'o' or 'O'
                        (current_char == 8'd117 || current_char == 8'd85)) { // 'u' or 'U'
                        vowel_count <= vowel_count + 4'd1;
                    }
                    // Check for 'y' at the end of the string
                    else if (is_last_char && 
                            (current_char == 8'd121 || current_char == 8'd89)) { // 'y' or 'Y'
                        vowel_count <= vowel_count + 4'd1;
                    }

                    // Move to next character or finish
                    if (index == (str_len - 1)) begin
                        state <= FINISH;
                    end else begin
                        index <= index + 4'd1;
                    end
                end

                FINISH: begin
                    result <= vowel_count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule