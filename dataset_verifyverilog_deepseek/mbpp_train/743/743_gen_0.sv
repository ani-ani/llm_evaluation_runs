module list_rotator (
    input [3:0] data_in [7:0],
    input [2:0] m,
    output reg [3:0] data_out [7:0]
);
    always_comb begin
        for (int i = 0; i < 8; i = i + 1) begin
            automatic int idx = (i + 8 - m) % 8;
            data_out[i] = data_in[idx];
        end
    end
endmodule