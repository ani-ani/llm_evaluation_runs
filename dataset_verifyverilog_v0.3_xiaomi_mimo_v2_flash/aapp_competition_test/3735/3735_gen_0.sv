module digit_sum_opt (
    input [63:0] n,
    output reg [8:0] result
);

    reg [63:0] a;
    reg [63:0] b;
    reg [8:0] sum_a, sum_b;
    reg [63:0] temp;
    integer i;

    always @(*) begin
        // Determine a based on n
        if (n < 64'd10) a = 64'd0;
        else if (n < 64'd100) a = 64'd9;
        else if (n < 64'd1000) a = 64'd99;
        else if (n < 64'd10000) a = 64'd999;
        else if (n < 64'd100000) a = 64'd9999;
        else if (n < 64'd1000000) a = 64'd99999;
        else if (n < 64'd10000000) a = 64'd999999;
        else if (n < 64'd100000000) a = 64'd9999999;
        else if (n < 64'd1000000000) a = 64'd99999999;
        else if (n < 64'd10000000000) a = 64'd999999999;
        else if (n < 64'd100000000000) a = 64'd9999999999;
        else if (n < 64'd1000000000000) a = 64'd99999999999;
        else a = 64'd999999999999;

        b = n - a;

        // Compute digit sum for a
        sum_a = 9'd0;
        temp = a;
        for (i = 0; i < 15; i = i + 1) begin
            if (temp != 64'd0) begin
                sum_a = sum_a + temp[3:0];
                temp = temp / 64'd10;
            end
        end

        // Compute digit sum for b
        sum_b = 9'd0;
        temp = b;
        for (i = 0; i < 15; i = i + 1) begin
            if (temp != 64'd0) begin
                sum_b = sum_b + temp[3:0];
                temp = temp / 64'd10;
            end
        end

        result = sum_a + sum_b;
    end

endmodule