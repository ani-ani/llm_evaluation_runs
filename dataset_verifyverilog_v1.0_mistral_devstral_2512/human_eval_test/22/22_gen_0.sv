module filter_integers(
    input [7:0] arr [0:7],
    output [7:0] result [0:7],
    output [3:0] count
);

    reg [7:0] result_reg [0:7];
    reg [3:0] count_reg;
    integer i;
    integer j;

    always @(*) begin
        count_reg = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            result_reg[i] = 8'd0;
        end

        j = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (arr[i] <= 8'd255) begin
                result_reg[j] = arr[i];
                j = j + 1;
            end
        end
        count_reg = j;
    end

    assign result[0] = result_reg[0];
    assign result[1] = result_reg[1];
    assign result[2] = result_reg[2];
    assign result[3] = result_reg[3];
    assign result[4] = result_reg[4];
    assign result[5] = result_reg[5];
    assign result[6] = result_reg[6];
    assign result[7] = result_reg[7];
    assign count = count_reg;

endmodule