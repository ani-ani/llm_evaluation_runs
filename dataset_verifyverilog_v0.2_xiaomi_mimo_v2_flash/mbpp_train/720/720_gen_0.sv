module add_dict_to_tuple (
    input [7:0] tuple_data [0:2],
    input [2:0] tuple_len,
    input [7:0] dict_keys [0:2],
    input [7:0] dict_vals [0:2],
    input [2:0] dict_len,
    output reg [63:0] result
);
    integer i;
    
    always @(*) begin
        // Initialize result to zero
        result = 64'h0;
        
        // Append tuple data (left-aligned)
        for (i = 0; i < 3; i = i + 1) begin
            if (i < tuple_len) begin
                result[(63 - (8*i)) -: 8] = tuple_data[i];
            end
        end
        
        // Append dictionary values (immediately after tuple data)
        for (i = 0; i < 3; i = i + 1) begin
            if (i < dict_len) begin
                // Calculate offset based on tuple_len (max 3) + current dict index i
                result[(63 - (8 * (tuple_len + i))) -: 8] = dict_vals[i];
            end
        end
    end
endmodule
