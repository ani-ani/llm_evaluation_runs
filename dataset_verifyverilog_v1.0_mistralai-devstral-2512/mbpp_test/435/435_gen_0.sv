module last_digit(
    input [7:0] num,
    output [3:0] result
);
    
    // Combinational logic to compute num % 10
    // Using subtraction method
    reg [3:0] temp;
    
    always @(*) begin
        temp = num;
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        if (temp >= 10) begin
            temp = temp - 10;
        end
        result = temp;
    end
    
endmodule