module next_smallest_palindrome (
    input [7:0] num,           // Input number (0-255)
    output reg [15:0] result,  // Result (max 9999 for 3-digit inputs)
    output reg valid           // Valid output flag
);

// Find next palindrome for 8-bit input
// Palindromes can be 1, 2, or 3 digits
// Combinational logic checks from num+1 upward

integer i;
reg [15:0] candidate;
reg [7:0] rev;
reg found;

always @(*) begin
    valid = 1'b0;
    result = 16'd0;
    found = 1'b0;
    
    // Search from num+1 to 999 (bounded search)
    i = num + 1;
    while (i <= 999 && !found) begin
        candidate = i;
        
        // Reverse digits manually
        if (candidate < 10) begin
            // 1-digit: always palindrome
            result = candidate;
            valid = 1'b1;
            found = 1'b1;
        end else if (candidate < 100) begin
            // 2-digit: check if digits equal
            if ((candidate / 10) == (candidate % 10)) begin
                result = candidate;
                valid = 1'b1;
                found = 1'b1;
            end
        end else begin
            // 3-digit: check first == last
            if ((candidate / 100) == (candidate % 10)) begin
                result = candidate;
                valid = 1'b1;
                found = 1'b1;
            end
        end
        
        i = i + 1;
    end
end

endmodule