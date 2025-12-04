module array_splitter (
    input wire [63:0] flat_array,
    input wire [2:0] L,
    output reg [63:0] part1,
    output reg [63:0] part2
);

    always_comb begin
        part1 = 64'd0;
        part2 = 64'd0;
        
        for (int i = 0; i < 8; i++) begin
            if (i < L) 
                part1[i*8 +: 8] = flat_array[i*8 +: 8];
        end
        
        for (int j = 0; j < 8; j++) begin
            if (j < (8 - L))
                part2[j*8 +: 8] = flat_array[(L + j)*8 +: 8];
        end
    end

endmodule