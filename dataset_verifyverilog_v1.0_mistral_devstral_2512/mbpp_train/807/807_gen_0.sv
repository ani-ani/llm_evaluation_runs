module find_first_odd(
    input [7:0] arr [0:7],
    output reg [7:0] result,
    output reg valid,
    output reg [2:0] index
);

    integer i;
    reg found;

    always @(*) begin
        found = 1'b0;
        result = 8'd0;
        valid = 1'b0;
        index = 3'd0;

        for (i = 0; i < 8; i = i + 1) begin
            if (!found && arr[i][0]) begin
                result = arr[i];
                valid = 1'b1;
                index = i;
                found = 1'b1;
            end
        end
    end

endmodule