module treasure_hunter(input clk, input rst_n, input start, input [5:0] grid [0:63], input [5:0] K, output reg [5:0] days, output reg [5:0] visited_count, output reg done, output reg impossible);
reg [2:0] state;
always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'b000;
        done <= 1'b0;
        impossible <= 1'b0;
        days <= 6'b000;
        visited_count <= 6'b000;
    end else begin
        if (state == 3'b000) begin
            if (start) state <= 3'b001;
        end
    end
end
endmodule