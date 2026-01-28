module MedianOfThree(
    input [7:0] a,
    input [7:0] b,
    input [7:0] c,
    output [7:0] median
);

    wire [7:0] min_ab;
    wire [7:0] max_ab;
    wire [7:0] min_ac;
    wire [7:0] max_ac;
    wire [7:0] min_bc;
    wire [7:0] max_bc;

    assign min_ab = (a < b) ? a : b;
    assign max_ab = (a > b) ? a : b;
    assign min_ac = (a < c) ? a : c;
    assign max_ac = (a > c) ? a : c;
    assign min_bc = (b < c) ? b : c;
    assign max_bc = (b > c) ? b : c;

    assign median = (a == min_ab && a == max_ab) ? b :
                   (b == min_ab && b == max_ab) ? a :
                   (a == min_ac && a == max_ac) ? c :
                   (c == min_ac && c == max_ac) ? a :
                   (b == min_bc && b == max_bc) ? c :
                   (c == min_bc && c == max_bc) ? b :
                   (a == min_ab && c == max_ab) ? b :
                   (b == min_ab && c == max_ab) ? a :
                   (a == min_ac && b == max_ac) ? c :
                   (c == min_ac && b == max_ac) ? a :
                   (a == min_bc && c == max_bc) ? b :
                   (b == min_bc && c == max_bc) ? a :
                   (a == min_ab && b == max_ab && c == min_ac && c == max_ac) ? a :
                   (a == min_ab && b == max_ab && c == min_bc && c == max_bc) ? b :
                   (a == min_ac && c == max_ac && b == min_bc && b == max_bc) ? c :
                   (a == min_ab && c == max_ab && b == min_ac && b == max_ac) ? b :
                   (a == min_ab && c == max_ab && b == min_bc && b == max_bc) ? c :
                   (b == min_ab && c == max_ab && a == min_ac && a == max_ac) ? a :
                   (b == min_hab && c == max_ab && a == min_bc && a == max_bc) ? c :
                   (b == min_ac && c == max_ac && a == min_bc && a == max_bc) ? a :
                   (b == min_ac && c == max_ac && a == min_ab && a == max_ab) ? c :
                   (c == min_ab && b == max_ab && a == min_ac && a == max_ac) ? a :
                   (c == min_ab && b == max_ab && a == min_bc && a == max_bc) ? b :
                   (c == min_ac && b == max_ac && a == min_bc && a == max_bc) ? a :
                   (c == min_ac && b == max_ac && a == min_ab && a == max_ab) ? b :
                   (c == min_bc && b == max_bc && a == min_ab && a == max_ab) ? a :
                   (c == min_bc && b == max_bc && a == min_ac && a == max_ac) ? b :
                   a;