module digit_distance(
    input  reg [16:0] n1,
    input  reg [16:0] n2,
    output reg [5:0] result
);

reg [16:0] diff;
reg [3:0] d0, d1, d2, d3, d4, d5;

always @(*) begin
    if (n1 >= n2)
        diff = n1 - n2;
    else
        diff = n2 - n1;

    d0 = diff % 10;
    d1 = (diff / 10) % 10;
    d2 = (diff / 100) % 10;
    d3 = (diff / 1000) % 10;
    d4 = (diff / 10000) % 10;
    d5 = (diff / 100000) % 10;

    result = d0 + d1 + d2 + d3 + d4 + d5;
end

endmodule