module CountOnesModule (
    input [7:0] arr,
    output reg [7:0] result
);
    // Combinational logic to count set bits in arr
    always @(*) begin
        result = 8'd0;
        result = result + arr[0];
        result = result + arr[1];
        result = result + arr[2];
        result = result + arr[3];
        result = result + arr[4];
        result = result + arr[5];
        result = result + arr[6];
        result = result + arr[7];
    end
endmodule