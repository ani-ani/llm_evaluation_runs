module remove_odd_numbers (
    input reg [7:0][7:0] data_in,
    output [7:0] mask_out,
    output [7:0][7:0] data_out
);

    integer i;
    always_comb begin
        data_out = data_in;
        for (i=0; i<8; i=i+1) begin
            mask_out[i] = (data_in[i][0] == 0);
        end
    end

endmodule