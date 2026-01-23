module odd_position_checker(
    input [7:0] arr [0:7],
    input [2:0] len,
    output result
);

    wire [7:0] valid;
    integer i;

    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            if (i < len) begin
                valid[i] = (arr[i][0] == i[0]);
            end else begin
                valid[i] = 1'b1;
            end
        end
    end

    assign result = valid[0] & valid[1] & valid[2] & valid[3] & valid[4] & valid[5] & valid[6] & valid[7];

endmodule