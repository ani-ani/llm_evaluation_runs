module pos_counter (
    input  signed [3:0] numbers [3:0],
    output       [2:0] pos_count
);

    wire [3:0] is_nonneg;

    assign is_nonneg[0] = ~numbers[0][3];
    assign is_nonneg[1] = ~numbers[1][3];
    assign is_nonneg[2] = ~numbers[2][3];
    assign is_nonneg[3] = ~numbers[3][3];

    assign pos_count = is_nonneg[0] + is_nonneg[1] + is_nonneg[2] + is_nonneg[3];

endmodule