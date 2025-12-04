module counter (input clk, reset, input [7:0] count_limit, output reg [7:0] count);
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            count <= 8'd0;
        end
        else if (count == count_limit) begin
            count <= 8'd0;
        end
        else begin
            count <= count + 1;
        end
    end
endmodule