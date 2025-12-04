module upper_case_counter(input reg [63:0] str_bytes, output reg [3:0] count);
always_comb begin
    count = 0;
    for (int i = 0; i < 8; i++) begin
        automatic reg [7:0] current_byte = str_bytes[i*8 +: 8];
        if (current_byte >= 8'd65 && current_byte <= 8'd90) begin
            count = count + 1;
        end
    end
end
endmodule