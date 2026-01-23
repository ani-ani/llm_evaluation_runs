module pairs_sum_to_zero(
    input [7:0] data_in [0:7],
    input [2:0] length,
    output reg result
);
    integer i, j;
    reg found;
    always @(*) begin
        found = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i >= length) begin
                break;
            end
            for (j = i + 1; j < 8; j = j + 1) begin
                if (j >= length) begin
                    break;
                end
                if (data_in[i] + data_in[j] == 8'd0) begin
                    found = 1'b1;
                end
            end
        end
        result = found;
    end
endmodule