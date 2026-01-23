module remove_duplicates(
    input [7:0] data_in [0:7],
    output [7:0] data_out [0:7]
);

    // Internal signals to track if a value is unique (not seen earlier)
    // unique_mask[i] is 1 if data_in[i] is the first occurrence of its value
    reg [0:0] unique_mask [0:7];
    
    integer i, j;
    
    always @(*) begin
        for (i = 0; i < 8; i = i + 1) begin
            // Default assumption: value is unique unless proven otherwise
            unique_mask[i] = 1'b1;
            
            // Process only non-sentinel values
            if (data_in[i] != 8'hFF) begin
                // Check all previous elements
                for (j = 0; j < i; j = j + 1) begin
                    // If a previous non-sentinel element has the same value, current is a duplicate
                    if (data_in[j] != 8'hFF && data_in[j] == data_in[i]) begin
                        unique_mask[i] = 1'b0;
                    end
                end
            end else begin
                // Sentinel values are not considered unique (they are empty)
                unique_mask[i] = 1'b0;
            end
        end
    end

    // Pack unique elements into output in order
    // Since this is combinational, we can assign directly based on unique_mask
    
    // We need to map the 8 unique_mask flags to 8 output slots sequentially
    // If 4 unique values, they occupy indices 0-3, rest are 255
    
    reg [7:0] temp_out [0:7];
    integer out_idx;
    
    always @(*) begin
        out_idx = 0;
        for (i = 0; i < 8; i = i + 1) begin
            temp_out[i] = 8'hFF; // Default to sentinel
        end
        
        for (i = 0; i < 8; i = i + 1) begin
            if (unique_mask[i]) begin
                temp_out[out_idx] = data_in[i];
                out_idx = out_idx + 1;
            end
        end
    end

    assign data_out = temp_out;

endmodule
