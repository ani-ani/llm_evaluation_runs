module distinct_gcd_count(
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [7:0] result
);

    function [7:0] gcd;
        input [7:0] a;
        input [7:0] b;
        reg [7:0] x;
        reg [7:0] y;
        integer i;
        begin
            x = a;
            y = b;
            for (i = 0; i < 8; i = i + 1) begin
                if (y == 8'd0) begin
                    gcd = x;
                    return;
                end
                x = y;
                y = x % y;
            end
            gcd = x;
        end
    endfunction

    reg [255:0] mask;
    integer i, j;
    reg [7:0] current_gcd;
    reg [7:0] arr [0:7];

    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;

    always @(*) begin
        mask = 256'd0;
        for (i = 0; i < len; i = i + 1) begin
            current_gcd = arr[i];
            mask[current_gcd] = 1'b1;
            for (j = i + 1; j < len; j = j + 1) begin
                current_gcd = gcd(current_gcd, arr[j]);
                mask[current_gcd] = 1'b1;
            end
        end
        result = 0;
        for (i = 0; i < 256; i = i + 1) begin
            if (mask[i]) begin
                result = result + 1;
            end
        end
    end

endmodule