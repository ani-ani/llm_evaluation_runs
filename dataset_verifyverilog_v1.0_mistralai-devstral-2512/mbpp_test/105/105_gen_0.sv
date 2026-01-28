module TrueCounter(
    input [7:0] arr,
    output reg [7:0] result
);
    always @(*) begin
        result = 8'd0;
        if (arr[0]) result = result + 8'd1;
        if (arr[1]) result = result + 8'd1;
        if (arr[2]) result = result + 8'd1;
        if (arr[3]) result = result + 8'd1;
        if (arr[4]) result = result + 8'd1;
        if (arr[5]) result = result + 8'd1;
        if (arr[6]) result = result + 8'd1;
        if (arr[7]) result = result + 8'd1;
    end
endmodule