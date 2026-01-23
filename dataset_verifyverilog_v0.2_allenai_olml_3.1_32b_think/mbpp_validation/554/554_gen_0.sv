module example (input wire clk, input wire rst, output reg [7:0] count);

    reg [7:0] count_reg;

    always @(posedge clk or posedge rst) begin
        if (rst)
            count_reg <= 8'd0;
        else
            count_reg <= count_reg + 1;
    end

    always @(*) begin
        count = count_reg;
    end
endmodule