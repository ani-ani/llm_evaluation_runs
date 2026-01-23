module will_it_fly(
    input [7:0] w,
    input [2:0] q_len,
    input [7:0] q [0:7],
    output result
);

    // Internal signals for sum and palindrome checks
    reg [11:0] sum;
    reg is_palindrome;
    integer i;
    reg [7:0] left_val;
    reg [7:0] right_val;
    reg mismatch;

    // Combinational logic block
    always @(*) begin
        // 1. Sum Calculation
        sum = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < q_len) begin
                sum = sum + q[i];
            end
        end

        // 2. Palindrome Check
        if (q_len <= 3'b001) begin
            // 0 or 1 elements is trivially a palindrome
            is_palindrome = 1'b1;
        end else begin
            mismatch = 1'b0;
            for (i = 0; i < q_len / 2; i = i + 1) begin
                left_val = q[i];
                right_val = q[q_len - 1 - i];
                if (left_val != right_val) begin
                    mismatch = 1'b1;
                end
            end
            is_palindrome = ~mismatch;
        end
    end

    // Output assignment
    assign result = is_palindrome && (sum <= w);

endmodule