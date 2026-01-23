module elementwise_div(
    input [3:0] num1_array,
    input [3:0] num2_array,
    output reg [3:0] quotient_array,
    output reg [3:0] remainder_array
);

    always @(*) begin
        // Element 0
        if (num2_array[0] == 1'b0) begin
            quotient_array[0] = 4'b1111;
            remainder_array[0] = 4'b0000;
        end else begin
            quotient_array[0] = num1_array[0] / num2_array[0];
            remainder_array[0] = num1_array[0] % num2_array[0];
        end

        // Element 1
        if (num2_array[1] == 1'b0) begin
            quotient_array[1] = 4'b1111;
            remainder_array[1] = 4'b0000;
        end else begin
            quotient_array[1] = num1_array[1] / num2_array[1];
            remainder_array[1] = num1_array[1] % num2_array[1];
        end

        // Element 2
        if (num2_array[2] == 1'b0) begin
            quotient_array[2] = 4'b1111;
            remainder_array[2] = 4'b0000;
        end else begin
            quotient_array[2] = num1_array[2] / num2_array[2];
            remainder_array[2] = num1_array[2] % num2_array[2];
        end

        // Element 3
        if (num2_array[3] == 1'b0) begin
            quotient_array[3] = 4'b1111;
            remainder_array[3] = 4'b0000;
        end else begin
            quotient_array[3] = num1_array[3] / num2_array[3];
            remainder_array[3] = num1_array[3] % num2_array[3];
        end
    end

endmodule