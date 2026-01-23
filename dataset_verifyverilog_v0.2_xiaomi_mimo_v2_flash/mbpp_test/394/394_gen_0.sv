module check_distinct (
    input [7:0] data_in [0:7],
    output reg is_distinct
);

    reg any_duplicate;
    integer i, j;

    always @(*) begin
        any_duplicate = 1'b0;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = i + 1; j < 8; j = j + 1) begin
                if (data_in[i] == data_in[j]) begin
                    any_duplicate = 1'b1;
                end
            end
        end
    end

    assign is_distinct = !any_duplicate;

endmodule