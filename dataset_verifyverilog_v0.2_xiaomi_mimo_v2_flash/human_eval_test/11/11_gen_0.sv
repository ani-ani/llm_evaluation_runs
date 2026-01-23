module string_xor (
    input [15:0] a,
    input [15:0] b,
    input [3:0] len,
    output reg [15:0] result
);

    integer i;

    always @(*) begin
        // Default all bits to 0
        result = 16'b0;
        
        // Perform XOR for bits 0 to (len-1)
        for (i = 0; i < 16; i = i + 1) begin
            if (i < len) begin
                result[i] = a[i] ^ b[i];
            end
        end
    end

endmodule
