module reberland_suffix (input clk, input rst_n, input start, input [4:0] char_in, input [3:0] len_in, output reg valid, output reg [4:0] suffix_out, output reg [3:0] suffix_len, output reg done);
always @(posedge clk) begin
    if (!rst_n) begin
        valid <= 1'b0;
        suffix_out <= 5'b0;
        suffix_len <= 3'b0;
        done <= 1'b0;
    end
end
endmodule