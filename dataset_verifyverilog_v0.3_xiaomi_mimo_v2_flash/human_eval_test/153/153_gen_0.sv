module strongest_extension(
    input [7:0] class_name [0:7],
    input [7:0] extensions [0:7][0:15],
    input [2:0] ext_count,
    input [3:0] class_len,
    input [3:0] ext_lens [0:7],
    output [7:0] result [0:24],
    output [4:0] result_len
);

    // Strength computation for each extension
    wire signed [5:0] strength [0:7]; // Range: -16 to +16
    
    // Calculate strength for each extension (parallel combinational logic)
    genvar i, j;
    generate
        for (i = 0; i < 8; i = i + 1) begin : strength_loop
            reg signed [5:0] local_strength;
            
            always @(*) begin
                local_strength = 6'sd0;
                for (j = 0; j < 16; j = j + 1) begin
                    if (j < ext_lens[i]) begin
                        case (extensions[i][j])
                            8'd65, 8'd66, 8'd67, 8'd68, 8'd69, 8'd70, 8'd71, 8'd72,
                            8'd73, 8'd74, 8'd75, 8'd76, 8'd77, 8'd78, 8'd79, 8'd80,
                            8'd81, 8'd82, 8'd83, 8'd84, 8'd85, 8'd86, 8'd87, 8'd88,
                            8'd89, 8'd90: local_strength = local_strength + 6'sd1;
                            8'd97, 8'd98, 8'd99, 8'd100, 8'd101, 8'd102, 8'd103, 8'd104,
                            8'd105, 8'd106, 8'd107, 8'd108, 8'd109, 8'd110, 8'd111, 8'd112,
                            8'd113, 8'd114, 8'd115, 8'd116, 8'd117, 8'd118, 8'd119, 8'd120,
                            8'd121, 8'd122: local_strength = local_strength - 6'sd1;
                            default: local_strength = local_strength;
                        endcase
                    end
                end
            end
            assign strength[i] = local_strength;
        end
    endgenerate

    // Find best extension index with tie-breaking (first occurrence wins)
    reg [2:0] best_idx;
    integer k;
    
    always @(*) begin
        best_idx = 3'd0; // Default to first valid extension
        
        if (ext_count > 3'd0) begin
            // Compare all extensions with current best
            for (k = 1; k < 8; k = k + 1) begin
                if (k < ext_count) begin
                    if (strength[k] > strength[best_idx]) begin
                        best_idx = 3'(k);
                    end
                    // If equal, keep lower index (do nothing)
                end
            end
        end
    end

    // Construct result string: ClassName + '.' + ExtensionName
    reg [7:0] result_reg [0:24];
    reg [4:0] result_len_reg;
    
    integer char_idx;
    
    always @(*) begin
        // Copy class name
        for (char_idx = 0; char_idx < 8; char_idx = char_idx + 1) begin
            if (char_idx < class_len) begin
                result_reg[char_idx] = class_name[char_idx];
            end else begin
                result_reg[char_idx] = 8'd0;
            end
        end
        
        // Add dot separator
        if (class_len < 8'd25) begin
            result_reg[class_len] = 8'h2E; // ASCII '.'
        end
        
        // Copy extension name
        for (char_idx = 0; char_idx < 16; char_idx = char_idx + 1) begin
            if (char_idx < ext_lens[best_idx] && (class_len + 8'd1 + 8'(char_idx)) < 8'd25) begin
                result_reg[class_len + 8'd1 + 8'(char_idx)] = extensions[best_idx][char_idx];
            end
        end
        
        // Calculate total length
        if (ext_count == 3'd0) begin
            result_len_reg = class_len;
        end else begin
            if ((class_len + 8'd1 + ext_lens[best_idx]) > 8'd25) begin
                result_len_reg = 5'd25;
            end else begin
                result_len_reg = 5'(class_len + 8'd1 + ext_lens[best_idx]);
            end
        end
    end

    // Assign outputs
    genvar out_idx;
    generate
        for (out_idx = 0; out_idx < 25; out_idx = out_idx + 1) begin : output_gen
            assign result[out_idx] = result_reg[out_idx];
        end
    endgenerate
    
    assign result_len = result_len_reg;

endmodule