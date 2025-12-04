module list_sum (
    input [7:0] elements [7:0],
    input [7:0] valid_mask,
    output [15:0] total_sum
);
    integer i;
    always_comb begin
        total_sum = 0;
        for (i = 0; i < 8; i = i + 1) begin
            if (valid_mask[i]) 
                total_sum = total_sum + elements[i];
        end
    end
endmodule