module highest_power_of_2 (
    input [15:0] n,
    output reg [15:0] result
);
    integer i;
    always @(*) begin
        result = 0;
        // Check from MSB (bit 15) down to LSB (bit 0)
        for (i = 15; i >= 0; i = i - 1) begin
            if (n[i]) begin
                result = 1 << i;
                break; // Found the highest bit, stop
            end
        end
    end
endmodule