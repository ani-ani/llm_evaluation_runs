module highest_power_of_2 (
    input [15:0] n,
    output reg [15:0] result
);
    always @(*) begin
        integer i;
        result = 0;
        for (i = 15; i >= 0; i = i - 1) begin
            if (n[i]) begin
                result[i] = 1;
                break;
            end
        end
    end
endmodule