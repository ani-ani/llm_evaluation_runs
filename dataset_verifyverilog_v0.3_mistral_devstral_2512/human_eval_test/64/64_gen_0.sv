module vowels_count(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [4:0] length,
    output reg [4:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK_CHAR = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [3:0] index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 5'd0;
            done <= 1'b0;
            index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        result <= 5'd0;
                        index <= 4'd0;
                        state <= CHECK_CHAR;
                    end
                end

                CHECK_CHAR: begin
                    // Check if current character is a vowel (case-insensitive)
                    if ((char_in == 8'd97 || char_in == 8'd65) ||  // 'a' or 'A'
                        (char_in == 8'd101 || char_in == 8'd69) || // 'e' or 'E'
                        (char_in == 8'd105 || char_in == 8'd73) || // 'i' or 'I'
                        (char_in == 8'd111 || char_in == 8'd79) || // 'o' or 'O'
                        (char_in == 8'd117 || char_in == 8'd85))   // 'u' or 'U'
                    begin
                        result <= result + 5'd1;
                    end
                    // Check if 'y' or 'Y' and last character
                    else if ((char_in == 8'd121 || char_in == 8'd89) && 
                             (index == length - 1))
                    begin
                        result <= result + 5'd1;
                    end

                    // Increment index
                    index <= index + 4'd1;

                    // Check if done processing
                    if (index == length) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule