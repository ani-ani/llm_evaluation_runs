module concatenate (
    input [4:0][7:0] strings,
    input [2:0] count,
    output reg [39:0] result,
    output reg [2:0] length
);

    integer i;

    always @(*) begin
        // Default values
        length = count;
        result = 40'h0;

        // Concatenate valid strings
        // The most significant byte corresponds to strings[0]
        for (i = 0; i < 5; i = i + 1) begin
            if (i < count) begin
                result[39-(8*i) -: 8] = strings[i];
            end
        end
    end

endmodule
