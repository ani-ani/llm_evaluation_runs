module strongest_extension (
    input [7:0] class_name [0:7],
    input [7:0] extensions [0:7][0:15],
    input [2:0] ext_count,
    input [3:0] class_len,
    input [3:0] ext_lens [0:7],
    output reg [7:0] result [0:24],
    output reg [4:0] result_len
);
    
    // Strength calculation signals
    reg signed [5:0] strength_raw [0:7];
    wire signed [5:0] strength [0:7];
    
    // Mask strengths beyond ext_count
    genvar m;
    generate
        for (m = 0; m < 8; m = m + 1) begin : mask_strength
            assign strength[m] = (m < ext_count) ? strength_raw[m] : -6'sd32;
        end
    endgenerate
    
    // Strength calculation per extension
    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : calc_strength
            always @(*) begin
                integer j;
                strength_raw[i] = 6'sd0;
                for (j = 0; j < 16; j = j + 1) begin
                    if (j < ext_lens[i]) begin
                        if ((extensions[i][j] >= 8'd65) && (extensions[i][j] <= 8'd90)) begin
                            strength_raw[i] = strength_raw[i] + 6'sd1;
                        end
                        else if ((extensions[i][j] >= 8'd97) && (extensions[i][j] <= 8'd122)) begin
                            strength_raw[i] = strength_raw[i] - 6'sd1;
                        end
                    end
                end
            end
        end
    endgenerate
    
    // Find best extension index
    reg [2:0] best_index;
    reg signed [5:0] best_strength;
    
    always @(*) begin
        integer k;
        best_index = 3'd0;
        best_strength = strength[0];
        
        for (k = 1; k < 8; k = k + 1) begin
            if (strength[k] > best_strength) begin
                best_strength = strength[k];
                best_index = k[2:0];
            end
        end
    end
    
    // Output construction
    always @(*) begin
        integer m;
        integer n;
        
        // Initialize result to 0
        for (m = 0; m < 25; m = m + 1) begin
            result[m] = 8'd0;
        end
        
        // Copy class name
        for (m = 0; m < 8; m = m + 1) begin
            if (m < class_len) begin
                result[m] = class_name[m];
            end
        end
        
        // Add dot separator
        result[class_len] = 8'd46;
        
        // Copy best extension
        for (m = 0; m < 16; m = m + 1) begin
            if (m < ext_lens[best_index]) begin
                result[class_len + 1 + m] = extensions[best_index][m];
            end
        end
        
        // Calculate result length
        result_len = class_len + 4'd1 + ext_lens[best_index];
    end
    
endmodule