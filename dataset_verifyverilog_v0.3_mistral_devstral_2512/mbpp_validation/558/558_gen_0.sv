module digit_distance_nums (
    // Inputs
    input [15:0] n1,      // First 16-bit unsigned integer
    input [15:0] n2,      // Second 16-bit unsigned integer
    
    // Outputs
    output reg [7:0] result  // Sum of digits (max 45 for 99999)
);

// Function to compute sum of decimal digits of a 16-bit number
function [7:0] sum_digits;
    input [15:0] num;
    integer i;
    reg [15:0] temp;
    reg [3:0] digit;
    begin
        sum_digits = 8'd0;
        temp = num;
        // Extract up to 5 decimal digits (max for 16-bit: 65535)
        for (i = 0; i < 5; i = i + 1) begin
            digit = temp % 10;  // Get last digit
            sum_digits = sum_digits + digit;
            temp = temp / 10;   // Remove last digit
        end
    end
endfunction

// Combinational logic
wire [15:0] diff;
wire [15:0] abs_diff;

// Compute difference
assign diff = (n1 > n2) ? (n1 - n2) : (n2 - n1);

// Take absolute value (already done by conditional subtraction)
assign abs_diff = diff;

// Compute result
always @(*) begin
    result = sum_digits(abs_diff);
end

endmodule