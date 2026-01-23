module puppy_standardization (
    input [127:0] string,
    input [3:0] length,
    output reg result
);
    integer i, j;
    reg duplicate_found;
    reg [7:0] char_i, char_j;

    always @(*) begin
        duplicate_found = 1'b0;
        
        // Check for duplicates among valid characters
        for (i = 0; i < 15; i = i + 1) begin
            for (j = i + 1; j < 16; j = j + 1) begin
                if (i < length && j < length) begin
                    char_i = string[(i * 8) +: 8];
                    char_j = string[(j * 8) +: 8];
                    if (char_i == char_j) begin
                        duplicate_found = 1'b1;
                    end
                end
            end
        end
        
        // Result is 1 if length is 1 OR duplicate found
        result = (length == 4'd1) || duplicate_found;
    end
endmodule