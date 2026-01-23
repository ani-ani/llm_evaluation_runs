module remove_vowels (
    input clk,
    input rst_n,
    input start,
    input [7:0] char_in,
    input [3:0] length,
    output reg [7:0] char_out,
    output reg out_valid,
    output reg done
);

localparam IDLE = 3'd0, READ_CHAR =1, PROCESS_CHAR=2, WRITE_CHAR=3, DONE=4;
reg [2:0] state, next_state;
reg [3:0] index;
reg [7:0] char_out;
reg out_valid;
reg done;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        index <= 4'd0;
        done <= 1'b0;
        char_out <= 8'd0;
        out_valid <= 1'b0;
    end else begin
        state <= next_state;
        if (next_state == DONE) begin
            done <= 1'b1;
        end
        if (state == PROCESS_CHAR && next_state == WRITE_CHAR) begin
            index <= index + 1;
        end
    end
end

always_comb begin
    next_state = state;
    char_out = 8'd0;
    out_valid = 1'b0;

    case (state)
        IDLE: begin
            if (start) begin
                next_state = READ_CHAR;
            end
        end
        READ_CHAR: begin
            next_state = PROCESS_CHAR;
        end
        PROCESS_CHAR: begin
            if (index < length) begin
                if (char_in == 'a' || char_in == 'A' || char_in == 'e' || char_in == 'E' || char_in == 'i' || char_in == 'I' || char_in == 'o' || char_in == 'O' || char_in == 'u' || char_in == 'U') begin
                end else begin
                    char_out = char_in;
                    out_valid = 1'b1;
                end
                next_state = WRITE_CHAR;
            end else begin
                next_state = DONE;
            end
        end
        WRITE_CHAR: begin
            if (index < length) begin
                next_state = PROCESS_CHAR;
            end else begin
                next_state = DONE;
            end
        end
        DONE: begin
        end
    endcase
end

endmodule