module magic_color_counter (
    input [3:0] flat_tree [255:0],
    input [7:0] query_start_idx,
    input [7:0] query_end_idx,
    input [2:0] num_colors,
    output reg [3:0] magical_count
);

    // Internal signals for parity computation
    reg [255:0] p1, p2, p3, p4;
    reg [7:0] idx;
    reg [3:0] color;
    
    // Parity accumulators for each color
    reg parity_1, parity_2, parity_3, parity_4;
    
    integer i;

    always @(*) begin
        // Initialize parity accumulators to 0
        parity_1 = 0;
        parity_2 = 0;
        parity_3 = 0;
        parity_4 = 0;
        
        // Iterate through the query range
        // Since the range is dynamic, we must use a loop
        // However, synthesis tools can unroll this if bounds are known static
        // Given max 16 nodes, this is efficient
        for (i = 0; i < 256; i = i + 1) begin
            // Check if index i is within the query range [query_start_idx, query_end_idx)
            if (i >= query_start_idx && i < query_end_idx) begin
                color = flat_tree[i];
                
                // Update parity based on color value
                // Using XOR to toggle parity
                if (color == 4'd1) parity_1 = parity_1 ^ 1'b1;
                else if (color == 4'd2) parity_2 = parity_2 ^ 1'b1;
                else if (color == 4'd3) parity_3 = parity_3 ^ 1'b1;
                else if (color == 4'd4) parity_4 = parity_4 ^ 1'b1;
            end
        end
        
        // Count magical colors (those with odd parity)
        magical_count = 0;
        
        // Only count if the color is active (based on num_colors)
        if (num_colors >= 3'd1 && parity_1) magical_count = magical_count + 1;
        if (num_colors >= 3'd2 && parity_2) magical_count = magical_count + 1;
        if (num_colors >= 3'd3 && parity_3) magical_count = magical_count + 1;
        if (num_colors >= 3'd4 && parity_4) magical_count = magical_count + 1;
    end

endmodule