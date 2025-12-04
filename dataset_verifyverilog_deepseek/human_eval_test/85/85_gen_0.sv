module add_even_at_odd_indices (
    input [2:0] length,
    input [7:0] lst [0:7],
    output reg [10:0] sum
);

    always_comb begin
        sum = 11'b0;
        for (int i = 0; i < 8; i++) begin
            if (i < length && i[0] && !lst[i][0])
                sum = sum + lst[i];
        end
    end
endmodule