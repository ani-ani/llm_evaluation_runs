module remove_parenthesis(input clk, input rst_n, input start, input [7:0] char_in, input char_valid, output reg [7:0] char_out, output reg char_out_valid, output reg done);
reg [7:0] next_char;
reg char_out_valid_next;
reg [1:0] state_reg;
reg done_reg;

localparam IDLE = 2\'b00;
localparam COPY_CHAR = 2\'b01;
localparam SKIP_CHARS = 2\'b10;
localparam DONE = 2\'b11;

assign char_out = next_char;
assign char_out_valid = char_out_valid_next;
assign done = done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        next_char <= 8\'b0;
        char_out_valid_next <= 1\'b0;
        done_reg <= 1\'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) begin
                    state_reg <= COPY_CHAR;
                end
            end
            COPY_CHAR: begin
                if (char_valid) begin
                    if (char_in == '(') begin
                        state_reg <= SKIP_CHARS;
                    end else if (char_in == 8\'h00) begin
                        next_char <= char_in;
                        char_out_valid_next <= 1\'b1;
                        state_reg <= DONE;
                        done_reg <= 1\'b1;
                    end else begin
                        next_char <= char_in;
                        char_out_valid_next <= 1\'b1;
                    end
                end
            end
            SKIP_CHARS: begin
                if (char_valid) begin
                    if (char_in == ')') begin
                        state_reg <= COPY_CHAR;
                    end else if (char_in == 8\'h00) begin
                        next_char <= char_in;
                        char_out_valid_next <= 1\'b1;
                        state_reg <= DONE;
                        done_reg <= 1\'b1;
                    end
                end
            end
            DONE: begin
                // Remain in DONE
            end
        endcase
    end
end
endmodule