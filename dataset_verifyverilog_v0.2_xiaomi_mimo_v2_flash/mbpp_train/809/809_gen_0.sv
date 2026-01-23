module tuple_compare (
    input [7:0] tuple1 [0:7],
    input [7:0] tuple2 [0:7],
    input [2:0] length,
    output reg result
);

    integer i;
    reg temp_result;

    always @(*) begin
        result = 1'b1;
        if (length == 3'd0) begin
            result = 1'b1;
        end else begin
            for (i = 0; i < 8; i = i + 1) begin
                if (i < length) begin
                    if (tuple2[i] >= tuple1[i]) begin
                        result = 1'b0;
                    end
                end
            end
        end
    end

endmodule