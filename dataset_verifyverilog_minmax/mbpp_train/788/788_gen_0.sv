module example (input clk, input reset, output reg [7:0] counter);
    reg [7:0] count;
    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= 8'h00;
        else
            count <= count + 1;
    end
    assign counter = count;
endmodule