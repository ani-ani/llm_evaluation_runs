module example (input wire clk, input wire reset, output reg [7:0] data_out);
    reg [7:0] data_in;
    always @(posedge clk or posedge reset) begin
        if (reset)
            data_in <= 8'd0;
        else
            data_in <= data_in + 1;
    end
    assign data_out = data_in;
endmodule