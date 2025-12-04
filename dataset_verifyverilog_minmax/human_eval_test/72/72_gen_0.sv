module will_it_fly (
    input [63:0] q_flat,
    input [3:0] length,
    input [10:0] w,
    output reg will_fly
);

    reg [7:0] elements [0:7];
    integer i;

    // Extract the 8 elements from the packed input
    assign elements[0] = q_flat[7:0];
    assign elements[1] = q_flat[15:8];
    assign elements[2] = q_flat[23:16];
    assign elements[3] = q_flat[31:24];
    assign elements[4] = q_flat[39:32];
    assign elements[5] = q_flat[47:40];
    assign elements[6] = q_flat[55:48];
    assign elements[7] = q_flat[63:56];

    always @(*) begin
        reg is_palindrome;
        reg [10:0] sum;

        // Check palindromic condition for the first 'length' elements
        is_palindrome = 1;
        for (i = 0; i < 4; i++) begin
            if (i < (length >> 1)) begin
                if (elements[i] != elements[length-1-i]) begin
                    is_palindrome = 0;
                end
            end
        end

        // Compute the sum of the first 'length' elements
        sum = 0;
        for (i = 0; i < length; i++) begin
            sum = sum + elements[i];
        end

        // Output will_fly: 1 if palindromic and sum <= w
        will_fly = is_palindrome && (sum <= w);
    end

endmodule