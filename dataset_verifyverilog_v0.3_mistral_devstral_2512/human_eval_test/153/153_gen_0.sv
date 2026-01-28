module strongest_extension(
    input [7:0] class_name [0:7],
    input [7:0] extensions [0:7][0:15],
    input [2:0] ext_count,
    input [3:0] class_len,
    input [3:0] ext_lens [0:7],
    output [7:0] result [0:24],
    output [4:0] result_len
);

    // Calculate strength for each extension
    wire signed [5:0] strengths [0:7];
    integer i, j;
    reg signed [5:0] strength_temp;
    
    // Compute strength for each extension
    for (i = 0; i < 8; i = i + 1) begin
        strength_temp = 6'd0;
        for (j = 0; j < 16; j = j + 1) begin
            if (j < ext_lens[i]) begin
                case (extensions[i][j])
                    8'd65, 8'd66, 8'd67, 8'd68, 8'd69, 8'd70, 8'd71, 8'd72, 8'd73, 8'd74, 
                    8'd75, 8'd76, 8'd77, 8'd78, 8'd79, 8'd80, 8'd81, 8'd82, 8'd83, 8'd84, 
                    8'd85, 8'd86, 8'd87, 8'd88, 8'd89, 8'd90: strength_temp = strength_temp + 6'd1;
                    8'd97, 8'd98, 8'd99, 8'd100, 8'd101, 8'd102, 8'd103, 8'd104, 8'd105, 8'd106, 
                    8'd107, 8'd108, 8'd109, 8'd110, 8'd111, 8'd112, 8'd113, 8'd114, 8'd115, 8'd116, 
                    8'd117, 8'd118, 8'd119, 8'd120, 8'd121, 8'd122: strength_temp = strength_temp - 6'd1;
                endcase
            end
        end
        strengths[i] = strength_temp;
    end

    // Find the best extension index
    reg [2:0] best_index;
    reg signed [5:0] max_strength;
    
    always @(*) begin
        max_strength = 6'sd0;
        best_index = 3'd0;
        for (i = 0; i < 8; i = i + 1) begin
            if (i < ext_count) begin
                if (strengths[i] > max_strength) begin
                    max_strength = strengths[i];
                    best_index = i;
                end
            end
        end
    end

    // Construct the result string
    reg [7:0] result_temp [0:24];
    reg [4:0] result_len_temp;
    
    always @(*) begin
        // Copy class name
        for (i = 0; i < 8; i = i + 1) begin
            if (i < class_len) begin
                result_temp[i] = class_name[i];
            end else begin
                result_temp[i] = 8'd0;
            end
        end
        
        // Add dot
        result_temp[class_len] = 8'd46; // '.'
        
        // Copy extension
        for (j = 0; j < 16; j = j + 1) begin
            if (j < ext_lens[best_index]) begin
                result_temp[class_len + 1 + j] = extensions[best_index][j];
            end else begin
                result_temp[class_len + 1 + j] = 8'd0;
            end
        end
        
        // Calculate result length
        result_len_temp = class_len + 1 + ext_lens[best_index];
    end

    // Assign outputs
    assign result[0] = result_temp[0];
    assign result[1] = result_temp[1];
    assign result[2] = result_temp[2];
    assign result[3] = result_temp[3];
    assign result[4] = result_temp[4];
    assign result[5] = result_temp[5];
    assign result[6] = result_temp[6];
    assign result[7] = result_temp[7];
    assign result[8] = result_temp[8];
    assign result[9] = result_temp[9];
    assign result[10] = result_temp[10];
    assign result[11] = result_temp[11];
    assign result[12] = result_temp[12];
    assign result[13] = result_temp[13];
    assign result[14] = result_temp[14];
    assign result[15] = result_temp[15];
    assign result[16] = result_temp[16];
    assign result[17] = result_temp[17];
    assign result[18] = result_temp[18];
    assign result[19] = result_temp[19];
    assign result[20] = result_temp[20];
    assign result[21] = result_temp[21];
    assign result[22] = result_temp[22];
    assign result[23] = result_temp[23];
    assign result[24] = result_temp[24];
    
    assign result_len = result_len_temp;

endmodule