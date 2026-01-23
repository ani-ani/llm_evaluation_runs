module exchange_checker(
    input [7:0] lst1 [0:7],
    input [7:0] lst2 [0:7],
    output reg result
);

    // Internal variables for odd detection bits
    wire [7:0] odd_bits_in;
    wire [7:0] odd_bits_out;

    // Step 1: Identify odd numbers by checking LSB
    assign odd_bits_in = {lst1[7][0], lst1[6][0], lst1[5][0], lst1[4][0], lst1[3][0], lst1[2][0], lst1[1][0], lst1[0][0]};
    assign odd_bits_out = {lst2[7][0], lst2[6][0], lst2[5][0], lst2[4][0], lst2[3][0], lst2[2][0], lst2[1][0], lst2[0][0]};

    // Step 2: Count the number of odd elements
    // Max count is 8, which fits in 4 bits (3:0)
    reg [3:0] odd_in_count;
    reg [3:0] odd_out_count;

    integer i;

    always @(*) begin
        // Initialize counters
        odd_in_count = 4'd0;
        odd_out_count = 4'd0;

        // Count odd bits in lst1
        for (i = 0; i < 8; i = i + 1) begin
            if (odd_bits_in[i]) begin
                odd_in_count = odd_in_count + 1;
            end
        end

        // Count odd bits in lst2
        for (i = 0; i < 8; i = i + 1) begin
            if (odd_bits_out[i]) begin
                odd_out_count = odd_out_count + 1;
            end
        end
    end

    // Step 3: Compare counts
    // If count of odd numbers in lst1 <= count of odd numbers in lst2, result = 1
    always @(*) begin
        if (odd_in_count <= odd_out_count)
            result = 1'b1;
        else
            result = 1'b0;
    end

endmodule