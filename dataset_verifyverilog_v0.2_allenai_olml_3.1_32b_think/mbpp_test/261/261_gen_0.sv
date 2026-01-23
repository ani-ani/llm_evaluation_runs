module tuple_division(input [7:0] dividend [0:3], input [7:0] divisor [0:3], output [7:0] quotient [0:3]);
    module divider_8bit(input [7:0] dividend, input [7:0] divisor, output [7:0] quotient);
        reg [7:0] remainder;
        reg [7:0] q;

        always @(*) begin
            remainder = 0;
            q = 0;

            // Bit 7 processing
            remainder = (remainder << 1) | dividend[7];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 7);
            end

            // Bit 6
            remainder = (remainder << 1) | dividend[6];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 6);
            end

            // Bit 5
            remainder = (remainder << 1) | dividend[5];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 5);
            end

            // Bit 4
            remainder = (remainder << 1) | dividend[4];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 4);
            end

            // Bit 3
            remainder = (remainder << 1) | dividend[3];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 3);
            end

            // Bit 2
            remainder = (remainder << 1) | dividend[2];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 2);
            end

            // Bit 1
            remainder = (remainder << 1) | dividend[1];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 1);
            end

            // Bit 0
            remainder = (remainder << 1) | dividend[0];
            if (remainder >= divisor) begin
                remainder = remainder - divisor;
                q = q | (1 << 0);
            end

            quotient = q;
        end
    endmodule

    divider_8bit div0(.dividend(dividend[0]), .divisor(divisor[0]), .quotient(quotient[0]));
    divider_8bit div1(.dividend(dividend[1]), .divisor(divisor[1]), .quotient(quotient[1]));
    divider_8bit div2(.dividend(dividend[2]), .divisor(divisor[2]), .quotient(quotient[2]));
    divider_8bit div3(.dividend(dividend[3]), .divisor(divisor[3]), .quotient(quotient[3]));
endmodule