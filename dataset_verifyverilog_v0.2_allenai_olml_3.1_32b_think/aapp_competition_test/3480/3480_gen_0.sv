module round_generator (input wire clk, input wire rst_n, input wire start, input wire [7:0] data_char, input wire [7:0] data_time, input wire [1:0] data_type, input wire data_valid, output reg [199:0] line1_out, output reg [199:0] line2_out, output reg output_valid, output reg done);
assign line1_out = {200{8'h5F}};
assign line2_out = {200{8'h5F}};
assign output_valid = 1'b0;
assign done = 1'b0;
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // No registers to reset
    end
end
endmodule