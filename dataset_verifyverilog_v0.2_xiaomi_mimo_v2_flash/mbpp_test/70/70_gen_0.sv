module tuple_length_checker (
    input [3:0] valid_tuples_count,
    input [3:0] tuple_lengths [0:3],
    output reg equal
);

    always @(*) begin
        // Default: If 0 or 1 valid tuples, they are considered equal
        equal = 1'b1;

        if (valid_tuples_count > 1) begin
            // Compare lengths of valid tuples (indices 1 to valid_tuples_count-1)
            // against the first tuple (index 0)
            
            // Check Tuple 1 (if valid)
            if (valid_tuples_count > 1) begin
                if (tuple_lengths[1] != tuple_lengths[0]) equal = 1'b0;
            end
            
            // Check Tuple 2 (if valid)
            if (valid_tuples_count > 2) begin
                if (tuple_lengths[2] != tuple_lengths[0]) equal = 1'b0;
            end
            
            // Check Tuple 3 (if valid)
            if (valid_tuples_count > 3) begin
                if (tuple_lengths[3] != tuple_lengths[0]) equal = 1'b0;
            end
        end
    end

endmodule