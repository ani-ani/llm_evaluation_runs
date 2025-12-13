module count_positive_digit_sums(
    input  signed [7:0] arr [0:7],
    output reg   [3:0] count
);

    // Function to compute signed digit-sum for an 8-bit signed number
    function automatic signed [7:0] digit_sum(input signed [7:0] val);
        // Working variables
        reg        is_neg;
        reg signed [7:0] mag;        // magnitude (0..128)
        reg signed [7:0] tmp;
        reg [3:0] d0, d1, d2;        // decimal digits (0..9)
        reg signed [7:0] sum;
    begin
        // Determine sign and magnitude (handle -128 safely)
        is_neg = val[7];
        if (!is_neg) begin
            mag = val;               // 0..127
        end else begin
            if (val == -8'sd128)
                mag = 8'd128;        // special case
            else
                mag = -val;          // 1..127
        end

        // Extract digits (0..255 range is sufficient; mag <= 128)
        d0  = mag % 10;
        tmp = mag / 10;
        d1  = tmp % 10;
        d2  = tmp / 10;

        // Build signed digit sum per rules
        if (!is_neg) begin
            // Positive: all digits positive
            sum = d0 + d1 + d2;
        end else begin
            // Negative: first non-zero digit is negative, remaining positive
            if (d2 != 0) begin
                // Most significant digit is first
                sum = -$signed({4'd0, d2}) + d1 + d0;
            end else if (d1 != 0) begin
                sum = -$signed({4'd0, d1}) + d0;
            end else if (d0 != 0) begin
                sum = -$signed({4'd0, d0});
            end else begin
                // Value is exactly 0 (for -0 or 0, treat sum as 0)
                sum = 0;
            end
        end

        digit_sum = sum;
    end
    endfunction

    integer i;
    reg [3:0] local_count;
    reg signed [7:0] ds [0:7];

    always @* begin
        // Compute digit sums in parallel form
        for (i = 0; i < 8; i = i + 1) begin
            ds[i] = digit_sum(arr[i]);
        end

        // Count how many have sum > 0
        local_count = 4'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (ds[i] > 0)
                local_count = local_count + 1'b1;
        end

        count = local_count;
    end

endmodule