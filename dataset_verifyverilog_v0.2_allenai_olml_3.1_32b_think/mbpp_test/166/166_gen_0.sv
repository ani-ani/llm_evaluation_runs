module even_pair_counter (
    input [7:0] data_in,
    input [2:0] index,
    input load,
    input compute,
    output reg [4:0] result,
    output reg valid
);

reg [7:0] mem [7:0];

always @(*) begin
    if (compute) begin
        int count_even, count_odd;
        count_even = 0;
        count_odd = 0;
        for (int i=0; i<8; i++) begin
            if (mem[i][0] == 0) 
                count_even++;
            else 
                count_odd++;
        end
        result = (count_even*(count_even-1) + count_odd*(count_odd-1)) >> 1;
        valid = 1;
    end else begin
        valid = 0;
    end
end

always @(*) begin
    if (load) 
        mem[index] = data_in;
end

endmodule