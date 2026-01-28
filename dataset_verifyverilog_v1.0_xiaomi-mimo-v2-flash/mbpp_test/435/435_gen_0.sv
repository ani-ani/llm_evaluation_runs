module last_digit (
    input [7:0] num,
    output reg [3:0] result
);
    // Combinational logic to compute last decimal digit (num % 10)
    // Using subtraction-based approach for 8-bit numbers (0-255)
    // This is equivalent to computing num mod 10

    always @(*) begin
        // For 8-bit numbers (0-255), we can subtract multiples of 10
        // The maximum number of subtractions needed is 25 (255/10)
        // We'll use a lookup table approach with subtraction cascade
        
        reg [7:0] temp;
        reg [3:0] count;
        
        temp = num;
        count = 4'd0;
        
        // Subtract 10 repeatedly (max 25 iterations for 0-255)
        // This is a combinational loop but will synthesize to priority logic
        if (temp >= 8'd150) begin
            temp = temp - 8'd150;
            count = count + 4'd15;
        end
        if (temp >= 8'd100) begin
            temp = temp - 8'd100;
            count = count + 4'd10;
        end
        if (temp >= 8'd50) begin
            temp = temp - 8'd50;
            count = count + 4'd5;
        end
        if (temp >= 8'd30) begin
            temp = temp - 8'd30;
            count = count + 4'd3;
        end
        if (temp >= 8'd20) begin
            temp = temp - 8'd20;
            count = count + 4'd2;
        end
        if (temp >= 8'd10) begin
            temp = temp - 8'd10;
            count = count + 4'd1;
        end
        
        // Now temp contains the remainder (0-9)
        result = temp[3:0];
    end
endmodule