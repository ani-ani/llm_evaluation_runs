module odd_digit_product (
    input wire [15:0] num,
    output reg [12:0] product
);

    integer i;
    integer temp;
    integer digit;
    integer product_temp;

    always @(*) begin
        product_temp = 0;
        temp = num;
        for (i = 0; i < 5; i = i + 1) begin
            digit = temp % 10;
            if (digit % 2 == 1) begin
                if (product_temp == 0) begin
                    product_temp = digit;
                end else begin
                    product_temp = product_temp * digit;
                end
            end
            temp = temp / 10;
        end
        product = product_temp;  // Truncates to 13 bits as per output width
    end

endmodule