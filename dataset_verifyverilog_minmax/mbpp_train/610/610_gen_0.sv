module remove_kth_element(
    input [79:0] array_in,
    input [4:0] k,
    output [79:0] array_out
);

    always_comb begin
        if (k == 0 || k > 16) begin
            array_out = array_in;
        end else begin
            for (int j = 0; j < 16; j++) begin
                if (j < (k-1)) begin
                    array_out[79-5*j -:5] = array_in[79-5*j -:5];
                end else if (j < 15) begin
                    array_out[79-5*j -:5] = array_in[79-5*(j+1) -:5];
                end else begin
                    array_out[79-5*j -:5] = array_in[79-5*15 -:5];
                end
            end
        end
    end

endmodule