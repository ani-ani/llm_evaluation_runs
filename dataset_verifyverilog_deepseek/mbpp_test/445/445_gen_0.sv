module tuple_mult (
    input [7:0] test_tup1 [0:3][0:1],
    input [7:0] test_tup2 [0:3][0:1],
    output reg [15:0] res [0:3][0:1]
);

    always_comb begin
        for (int i = 0; i < 4; i++) begin
            for (int j = 0; j < 2; j++) begin
                res[i][j] = test_tup1[i][j] * test_tup2[i][j];
            end
        end
    end

endmodule