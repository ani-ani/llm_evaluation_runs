module counter (clk, reset, enable, count);
    input clk, reset, enable;
    output reg [3:0] count;
    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= 4'd0;
        else if (enable)
            count <= count + 1;
    end
endmodule