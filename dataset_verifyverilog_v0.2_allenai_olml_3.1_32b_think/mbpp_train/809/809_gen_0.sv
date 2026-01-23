module tuple_compare (
    input [7:0] tuple1 [0:7],
    input [7:0] tuple2 [0:7],
    input [2:0] length,
    output reg result
);
always @(*) begin
    result = 1'b1;
    int i;
    for (i=0; i < length; i++) begin
        if (tuple2[i] >= tuple1[i]) begin
            result = 1'b0;
        end
    end
end
endmodule