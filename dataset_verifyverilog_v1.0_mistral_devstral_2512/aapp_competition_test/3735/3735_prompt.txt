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
        if (n < 10) a = 0;
        else if (n < 100) a = 9;
        else if (n < 1000) a = 99;
        else if (n < 10000) a = 999;
        else if (n < 100000) a = 9999;
        else if (n < 1000000) a = 99999;
        else if (n < 10000000) a = 999999;
        else if (n < 100000000) a = 9999999;
        else if (n < 1000000000) a = 99999999;
        else if (n < 10000000000) a = 999999999;
        else if (n < 100000000000) a = 9999999999;
        else if (n < 1000000000000) a = 99999999999;
        else a = 999999999999;

        b = n - a;

        // Compute digit sum for a
        sum_a = 0;
        temp = a;
        for (i = 0; i < 15; i = i + 1) begin
            if (temp != 0) begin
                sum_a = sum_a + temp % 10;
                temp = temp / 10;
            end
        end

        // Compute digit sum for b
        sum_b = 0;
        temp = b;
        for (i = 0; i < 15; i = i + 1) begin
            if (temp != 0) begin
                sum_b = sum_b + temp % 10;
                temp = temp / 10;
            end
        end

        result = sum_a + sum_b;
    end

endmodule