module empty_list (
    input [2:0] length,
    output reg [7:0] arr [0:7]
);
    always_comb begin
        for (int i = 0; i < 8; i++) begin
            if (i <= length) arr[i] = 8'b0;
            else arr[i] = 8'b1;
        end
    end
endmodule