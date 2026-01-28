module puppy_standardization (
    input [127:0] string,
    input [3:0] length,
    output reg result
);
    integer i, j;
    reg duplicate_found;

    always @(*) begin
        duplicate_found = 0;
        for (i = 0; i < 16; i = i + 1) begin
            for (j = i + 1; j < 16; j = j + 1) begin
                if (i < length && j < length) begin
                    if (string[i*8 +: 8] == string[j*8 +: 8]) begin
                        duplicate_found = 1;
                    end
                end
            end
        end
        result = (length == 4'd1) || duplicate_found;
    end
endmodule