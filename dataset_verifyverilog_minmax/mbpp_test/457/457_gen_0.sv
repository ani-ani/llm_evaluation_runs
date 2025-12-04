module min_sublist(
    input [3:0] valid_mask[3:0],
    input [7:0] data[3:0][3:0],
    output reg [7:0] min_data[3:0],
    output reg [3:0] out_valid_mask
);
    integer counts[3:0];
    integer i, min_count, min_index;
    
    always @(*) begin
        // Count valid elements for each sublist
        for (i = 0; i < 4; i = i + 1) begin
            counts[i] = $countones(valid_mask[i]);
        end
        
        // Find minimum count and first occurrence
        min_count = counts[0];
        min_index = 0;
        for (i = 1; i < 4; i = i + 1) begin
            if (counts[i] < min_count) begin
                min_count = counts[i];
                min_index = i;
            end
        end
        
        // Output selected sublist
        min_data = data[min_index];
        out_valid_mask = valid_mask[min_index];
    end
endmodule