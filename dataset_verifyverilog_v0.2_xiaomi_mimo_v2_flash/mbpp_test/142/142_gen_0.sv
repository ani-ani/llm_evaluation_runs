module count_samepair (
    input [7:0] list1 [0:7],
    input [7:0] list2 [0:7],
    input [7:0] list3 [0:7],
    output reg [3:0] result
);

    integer i;

    always @(*) begin
        result = 4'b0;
        for (i = 0; i < 8; i = i + 1) begin
            if (list1[i] == list2[i] && list2[i] == list3[i]) begin
                result = result + 1'b1;
            end
        end
    end

endmodule