module example (input wire clk, input wire reset, output reg [7:0] counter);
    reg [7:0] count;

    always @(posedge clk or posedge reset) begin
        if (reset)
            count <= 8'd0;
        else
            count <= count + 1;
    end

    assign counter = count;
endmodule