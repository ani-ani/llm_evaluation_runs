module fix_spaces(input clk, input rst_n, input start, input [127:0] text_in, output reg [127:0] text_out, output reg done);
reg [1:0] state;
reg [3:0] char_count;
reg [2:0] space_counter;
reg [127:0] output_buffer;
reg [1:0] done_delay;

initial begin
    state <= 2'b00;
    char_count <= 4'b0000;
    space_counter <= 3'b000;
    output_buffer <= 128'b0;
    done_delay <= 2'b00;
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 2'b00;
        char_count <= 4'b0000;
        space_counter <= 3'b000;
        output_buffer <= 128'b0;
        done_delay <= 2'b00;
    end else begin
        case(state)
            2'b00: if (start) state <= 2'b01;
            2'b01: if (char_count < 16) begin
                output_buffer <= text_in;
                char_count <= char_count + 1;
            end else begin
                state <= 2'b10;
                done_delay <= 2'b01;
            end
            2'b10: if (done_delay == 2'b01) done <= 1'b1;
        endcase
    end
end

assign text_out = output_buffer;
endmodule