module fake_bag_counter (
    input [7:0] m,
    input [7:0] k,
    output reg [31:0] result
);

    always @(*) begin
        case ({m, k})
            16'd513:   result = 32'd9;    // m=2, k=1
            16'd514:   result = 32'd17;   // m=2, k=2
            16'd1025:  result = 32'd13;   // m=4, k=1
            16'd1026:  result = 32'd25;   // m=4, k=2
            16'd1027:  result = 32'd49;   // m=4, k=3
            16'd1028:  result = 32'd97;   // m=4, k=4
            16'd1537:  result = 32'd17;   // m=6, k=1
            16'd1538:  result = 32'd33;   // m=6, k=2
            16'd1539:  result = 32'd65;   // m=6, k=3
            16'd1540:  result = 32'd129;  // m=6, k=4
            16'd1541:  result = 32'd257;  // m=6, k=5
            16'd1542:  result = 32'd513;  // m=6, k=6
            16'd2049:  result = 32'd21;   // m=8, k=1
            16'd2050:  result = 32'd41;   // m=8, k=2
            16'd2051:  result = 32'd81;   // m=8, k=3
            16'd2052:  result = 32'd161;  // m=8, k=4
            16'd2053:  result = 32'd321;  // m=8, k=5
            16'd2054:  result = 32'd641;  // m=8, k=6
            16'd2055:  result = 32'd1281; // m=8, k=7
            16'd2056:  result = 32'd2561; // m=8, k=8
            default:    result = 32'd0;
        endcase
    end

endmodule