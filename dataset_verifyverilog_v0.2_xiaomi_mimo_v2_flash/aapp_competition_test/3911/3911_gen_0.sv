module slime_game (
    input [15:0] n,
    output reg [4:0] count,
    output reg [4:0][15:0] values
);

    integer i;
    integer j;

    always @(*) begin
        // Initialize
        count = 0;
        for (j = 0; j < 16; j = j + 1) begin
            values[j] = 16'd0;
        end

        // Iterate from MSB (15) down to LSB (0)
        for (i = 15; i >= 0; i = i - 1) begin
            if (n[i]) begin
                values[count] = i + 1;
                count = count + 1;
            end
        end
    end

endmodule
