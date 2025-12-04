module overlapping_checker (
    input [7:0][3:0] list1,
    input [7:0][3:0] list2,
    output reg overlap
);

always_comb begin
    overlap = 1'b0;
    for (int i = 0; i < 8; i++) begin
        for (int j = 0; j < 8; j++) begin
            if (list1[i] == list2[j]) begin
                overlap = 1'b1;
            end
        end
    end
end

endmodule