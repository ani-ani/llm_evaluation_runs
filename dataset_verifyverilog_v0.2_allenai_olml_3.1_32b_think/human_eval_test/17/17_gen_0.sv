module parse_music (input clk, input rst_n, input start, input [127:0] music_string, input [4:0] length, output reg [3:0] result, output reg result_valid, output reg done);
parameter O_CHAR = 8'h6F;
parameter BAR_CHAR = 8'h7C;
parameter DOT_CHAR = 8'h2E;
parameter SPACE_CHAR = 8'h20;
reg [1:0] state;
reg [3:0] index;
reg [3:0] result;
reg result_valid;
assign done = (state == 2);
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'd0;
        index <= 4'd0;
        result <= 4'd0;
        result_valid <= 1'b0;
    end else begin
        case(state)
            2'd0: begin
                if (start == 1'b1) begin
                    state <= 2'd1;
                    index <= 4'd0;
                    result <= 4'd0;
                    result_valid <= 1'b0;
                end else begin
                    state <= 2'd0;
                end
            end
            2'd1: begin
                wire [7:0] current_char;
                current_char = music_string[(index + 1)*8 - 1 : index*8];

                if (index >= length) begin
                    state <= 2'd2;
                    result <= 4'd0;
                    result_valid <= 1'b0;
                end else begin
                    if (current_char == SPACE_CHAR) begin
                        index <= index + 1;
                        state <= 2'd1;
                        result <= 4'd0;
                        result_valid <= 1'b0;
                    end else begin
                        wire [3:0] note_value;
                        note_value = 4'd0;

                        if (current_char == O_CHAR) begin
                            if (index + 1 < length) begin
                                wire [7:0] next_char;
                                next_char = music_string[((index + 1) + 1)*8 - 1 : (index + 1)*8];
                                if (next_char == BAR_CHAR) begin
                                    note_value = 4'd2;
                                    index <= index + 2;
                                end else begin
                                    note_value = 4'd4;
                                    index <= index + 1;
                                end
                            end else begin
                                note_value = 4'd4;
                                index <= index + 1;
                            end
                        end else if (current_char == DOT_CHAR) begin
                            if (index + 1 < length) begin
                                wire [7:0] next_char;
                                next_char = music_string[((index + 1) + 1)*8 - 1 : (index + 1)*8];
                                if (next_char == BAR_CHAR) begin
                                    note_value = 4'd1;
                                    index <= index + 2;
                                end else begin
                                    index <= index + 1;
                                end
                            end else begin
                                index <= index + 1;
                            end
                        end else begin
                            index <= index + 1;
                        end

                        if (note_value != 4'd0) begin
                            result <= note_value;
                            result_valid <= 1'b1;
                        end else begin
                            result <= 4'd0;
                            result_valid <= 1'b0;
                        end
                        state <= 2'd1;
                    end
                end
            end
            2'd2: state <= 2'd2;
        endcase
    end
end
endmodule