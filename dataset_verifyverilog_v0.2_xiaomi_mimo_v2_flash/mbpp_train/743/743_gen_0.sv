module rotate_right(
    input [2:0] rotate_amount,
    input [7:0] data_in [0:7],
    output reg [7:0] data_out [0:7]
);
    integer i;
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            data_out[i] = data_in[(i - rotate_amount + 8) % 8];
        end
    end
endmodule