module gcd_distinct_counter(
    input [3:0] n,
    input [15:0] a [0:3],
    output [3:0] distinct_count
);

    // GCD calculator using Euclidean algorithm (combinational, 4 stages max)
    function [15:0] gcd_calc;
        input [15:0] a, b;
        reg [15:0] x, y, temp;
        integer i;
        begin
            x = a;
            y = b;
            for (i = 0; i < 4; i = i + 1) begin
                if (y == 0) begin
                    return x;
                end
                temp = x % y;
                x = y;
                y = temp;
            end
            return x;
        end
    endfunction

    // Compute GCD for all possible contiguous subarrays
    wire [15:0] subarray_gcd [0:9];
    assign subarray_gcd[0] = a[0]; // [0:0]
    assign subarray_gcd[1] = gcd_calc(a[0], a[1]); // [0:1]
    assign subarray_gcd[2] = gcd_calc(a[0], gcd_calc(a[1], a[2])); // [0:2]
    assign subarray_gcd[3] = gcd_calc(a[0], gcd_calc(a[1], gcd_calc(a[2], a[3]))); // [0:3]
    assign subarray_gcd[4] = a[1]; // [1:1]
    assign subarray_gcd[5] = gcd_calc(a[1], a[2]); // [1:2]
    assign subarray_gcd[6] = gcd_calc(a[1], gcd_calc(a[2], a[3])); // [1:3]
    assign subarray_gcd[7] = a[2]; // [2:2]
    assign subarray_gcd[8] = gcd_calc(a[2], a[3]); // [2:3]
    assign subarray_gcd[9] = a[3]; // [3:3]

    // Distinct counting logic
    reg [3:0] count = 0;
    reg [15:0] unique_values [0:9];
    integer i, j;
    always @* begin
        count = 0;
        for (i = 0; i < 10; i = i + 1) begin
            if (i < n*(n+1)/2) begin
                reg is_unique = 1'b1;
                for (j = 0; j < i; j = j + 1) begin
                    if (subarray_gcd[i] == unique_values[j]) begin
                        is_unique = 1'b0;
                    end
                end
                if (is_unique) begin
                    unique_values[count] = subarray_gcd[i];
                    count = count + 1;
                end
            end
        end
    end

    assign distinct_count = count;

endmodule