module divisor_parity(
    input [15:0] n,
    output reg even_divisors
);

    // Function to compute integer square root of a 16-bit number
    // Returns floor(sqrt(n))
    function automatic [7:0] isqrt;
        input [15:0] val;
        reg [15:0] rem;
        reg [7:0] root;
        integer i;
    begin
        rem = val;
        root = 0;
        // Iterate bits from high to low (8 bits since max root is 255)
        for (i = 7; i >= 0; i = i - 1) begin
            root = root << 1;
            // Check if we can set this bit to 1
            // We want to see if (root + 1)^2 <= rem
            // Since we haven't added the 1 yet, let temp = root + 1.
            // We need to compare temp * temp with rem.
            if ((root + 1) * (root + 1) <= rem) begin
                root = root + 1;
                rem = rem - (root * root);
            end
        end
        isqrt = root;
    end
    endfunction

    // Helper function to check if n is a perfect square
    function automatic is_perfect_square;
        input [15:0] val;
        reg [7:0] root;
        reg [15:0] sq;
    begin
        root = isqrt(val);
        sq = root * root;
        is_perfect_square = (sq == val);
    end
    endfunction

    // Combinational logic
    always @(*) begin
        if (n == 16'd0) begin
            // Special case for 0
            even_divisors = 1'b1;
        end else begin
            // If it is a perfect square, divisor count is odd (output 0)
            // If not, divisor count is even (output 1)
            if (is_perfect_square(n)) begin
                even_divisors = 1'b0;
            end else begin
                even_divisors = 1'b1;
            end
        end
    end

endmodule