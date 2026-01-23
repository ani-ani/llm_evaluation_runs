module Find_Min_Length(
    input [3:0][7:0][7:0] data,  // 4 sub-arrays, each 8 elements, each 8 bits
    input [3:0] valid_mask,       // Which sub-arrays are valid (bit mask)
    output reg [3:0] min_length   // Minimum length among valid arrays
);

// Parameters for array sizes
parameter MAX_SUBARRAYS = 4;
parameter MAX_SUBARRAY_SIZE = 8;

// Internal wires for lengths of each sub-array
reg [3:0] lengths [0:3];

integer i, j;

always @(*) begin
    // Calculate length for each sub-array
    for (i = 0; i < MAX_SUBARRAYS; i = i + 1) begin
        if (valid_mask[i]) begin
            // Count non-zero elements (or all elements if we consider fixed-size)
            // Here we assume the length is the actual number of elements stored
            // For simplicity, we'll count based on the first 8 positions
            lengths[i] = 0;
            for (j = 0; j < MAX_SUBARRAY_SIZE; j = j + 1) begin
                if (data[i][j] != 8'h00) begin
                    lengths[i] = lengths[i] + 1;
                end
            end
        end else begin
            lengths[i] = 4'hF; // Mark as invalid (max value)
        end
    end
    
    // Find minimum among valid lengths
    min_length = 4'hF; // Initialize to max
    for (i = 0; i < MAX_SUBARRAYS; i = i + 1) begin
        if (valid_mask[i] && lengths[i] < min_length) begin
            min_length = lengths[i];
        end
    end
end

endmodule