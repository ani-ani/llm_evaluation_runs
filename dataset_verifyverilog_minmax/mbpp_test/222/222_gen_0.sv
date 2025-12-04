module check_tuple_type(
    input reg [5:0][1:0] types,   // 6 elements, each 2-bit
    output logic all_same
);
    // Combinational logic: check all elements against types[0]
    always_comb begin
        all_same = 1'b1;
        for (int i = 1; i < 6; i++) begin
            if (types[i] != types[0]) begin
                all_same = 1'b0;
            end
        end
    end
endmodule