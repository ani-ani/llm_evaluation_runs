module symmetric_difference (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr1 [0:15],
    input [7:0] arr2 [0:15],
    input [3:0] len1,
    input [3:0] len2,
    output reg [7:0] result [0:31],
    output reg [4:0] result_len,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:0] CAPTURE       = 4'd1;
    localparam [3:0] UNIQUE1_START = 4'd2;
    localparam [3:0] UNIQUE1_WORK  = 4'd3;
    localparam [3:0] UNIQUE2_START = 4'd4;
    localparam [3:0] UNIQUE2_WORK  = 4'd5;
    localparam [3:0] DIFF_START    = 4'd6;
    localparam [3:0] DIFF_WORK     = 4'd7;
    localparam [3:0] SORT_START    = 4'd8;
    localparam [3:0] SORT_WORK     = 4'd9;
    localparam [3:0] DONE_STATE    = 4'd10;

    reg [3:0] state;
    reg [7:0] unique1 [0:15];
    reg [3:0] unique1_len;
    reg [7:0] unique2 [0:15];
    reg [3:0] unique2_len;
    reg [7:0] diff [0:31];
    reg [4:0] diff_len;
    reg [7:0] sorted [0:31];
    reg [4:0] sorted_len;
    
    // Working registers for loops
    reg [7:0] work_arr [0:15];
    reg [3:0] work_len;
    reg [3:0] i, j, k;
    reg found;
    reg [7:0] temp;
    reg [7:0] stored_arr1 [0:15];
    reg [7:0] stored_arr2 [0:15];
    reg [3:0] stored_len1;
    reg [3:0] stored_len2;
    reg [7:0] temp_arr [0:31];
    reg [4:0] temp_len;
    reg [7:0] temp_result [0:31];
    reg [4:0] temp_result_len;
    reg [7:0] swap_temp;
    reg [7:0] duplicate_check [0:15];
    reg [3:0] duplicate_check_len;
    reg [7:0] element_check;
    reg found_in_both;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 5'd0;
            unique1_len <= 4'd0;
            unique2_len <= 4'd0;
            diff_len <= 5'd0;
            sorted_len <= 5'd0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            work_len <= 4'd0;
            found <= 1'b0;
            temp <= 8'd0;
            stored_len1 <= 4'd0;
            stored_len2 <= 4'd0;
            temp_len <= 5'd0;
            temp_result_len <= 5'd0;
            swap_temp <= 8'd0;
            duplicate_check_len <= 4'd0;
            element_check <= 8'd0;
            found_in_both <= 1'b0;
            
            // Clear all arrays
            for (int idx = 0; idx < 16; idx = idx + 1) begin
                unique1[idx] <= 8'd0;
                unique2[idx] <= 8'd0;
                work_arr[idx] <= 8'd0;
                stored_arr1[idx] <= 8'd0;
                stored_arr2[idx] <= 8'd0;
                duplicate_check[idx] <= 8'd0;
            end
            for (int idx = 0; idx < 32; idx = idx + 1) begin
                diff[idx] <= 8'd0;
                sorted[idx] <= 8'd0;
                result[idx] <= 8'd0;
                temp_arr[idx] <= 8'd0;
                temp_result[idx] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end
                
                CAPTURE: begin
                    // Store inputs
                    for (int idx = 0; idx < 16; idx = idx + 1) begin
                        if (idx < len1)
                            stored_arr1[idx] <= arr1[idx];
                        else
                            stored_arr1[idx] <= 8'd0;
                        
                        if (idx < len2)
                            stored_arr2[idx] <= arr2[idx];
                        else
                            stored_arr2[idx] <= 8'd0;
                    end
                    stored_len1 <= len1;
                    stored_len2 <= len2;
                    unique1_len <= 4'd0;
                    unique2_len <= 4'd0;
                    i <= 4'd0;
                    j <= 4'd0;
                    state <= UNIQUE1_START;
                end
                
                UNIQUE1_START: begin
                    // Process arr1 for unique elements
                    i <= 4'd0;
                    unique1_len <= 4'd0;
                    state <= UNIQUE1_WORK;
                end
                
                UNIQUE1_WORK: begin
                    if (i < stored_len1) begin
                        // Check if stored_arr1[i] is already in unique1
                        found <= 1'b0;
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < unique1_len && unique1[idx] == stored_arr1[i]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (!found && unique1_len < 4'd16) begin
                            unique1[unique1_len] <= stored_arr1[i];
                            unique1_len <= unique1_len + 4'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        state <= UNIQUE2_START;
                    end
                end
                
                UNIQUE2_START: begin
                    // Process arr2 for unique elements
                    i <= 4'd0;
                    unique2_len <= 4'd0;
                    state <= UNIQUE2_WORK;
                end
                
                UNIQUE2_WORK: begin
                    if (i < stored_len2) begin
                        // Check if stored_arr2[i] is already in unique2
                        found <= 1'b0;
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < unique2_len && unique2[idx] == stored_arr2[i]) begin
                                found <= 1'b1;
                            end
                        end
                        
                        if (!found && unique2_len < 4'd16) begin
                            unique2[unique2_len] <= stored_arr2[i];
                            unique2_len <= unique2_len + 4'd1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        i <= 4'd0;
                        j <= 4'd0;
                        diff_len <= 5'd0;
                        state <= DIFF_START;
                    end
                end
                
                DIFF_START: begin
                    // Find symmetric difference
                    i <= 4'd0;
                    state <= DIFF_WORK;
                end
                
                DIFF_WORK: begin
                    if (i < unique1_len) begin
                        // Check if unique1[i] is in unique2
                        found_in_both <= 1'b0;
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < unique2_len && unique2[idx] == unique1[i]) begin
                                found_in_both <= 1'b1;
                            end
                        end
                        
                        if (!found_in_both && diff_len < 5'd32) begin
                            diff[diff_len] <= unique1[i];
                            diff_len <= diff_len + 5'd1;
                        end
                        i <= i + 4'd1;
                    end else if (j < unique2_len) begin
                        // Check if unique2[j] is in unique1
                        found_in_both <= 1'b0;
                        for (int idx = 0; idx < 16; idx = idx + 1) begin
                            if (idx < unique1_len && unique1[idx] == unique2[j]) begin
                                found_in_both <= 1'b1;
                            end
                        end
                        
                        if (!found_in_both && diff_len < 5'd32) begin
                            diff[diff_len] <= unique2[j];
                            diff_len <= diff_len + 5'd1;
                        end
                        j <= j + 4'd1;
                    end else begin
                        // Copy diff to sorted for sorting
                        for (int idx = 0; idx < 32; idx = idx + 1) begin
                            if (idx < diff_len)
                                sorted[idx] <= diff[idx];
                            else
                                sorted[idx] <= 8'd0;
                        end
                        sorted_len <= diff_len;
                        i <= 5'd0;
                        j <= 5'd0;
                        state <= SORT_START;
                    end
                end
                
                SORT_START: begin
                    // Bubble sort
                    if (sorted_len > 5'd1) begin
                        i <= 5'd0;
                        state <= SORT_WORK;
                    end else begin
                        // Copy to result
                        for (int idx = 0; idx < 32; idx = idx + 1) begin
                            if (idx < sorted_len)
                                result[idx] <= sorted[idx];
                            else
                                result[idx] <= 8'd0;
                        end
                        result_len <= sorted_len;
                        state <= DONE_STATE;
                    end
                end
                
                SORT_WORK: begin
                    if (i < sorted_len - 5'd1) begin
                        if (sorted[i] > sorted[i + 5'd1]) begin
                            // Swap
                            swap_temp <= sorted[i];
                            sorted[i] <= sorted[i + 5'd1];
                            sorted[i + 5'd1] <= swap_temp;
                        end
                        i <= i + 5'd1;
                    end else begin
                        // Check if sorted (one pass done)
                        j <= j + 5'd1;
                        if (j < sorted_len - 5'd1) begin
                            i <= 5'd0;
                        end else begin
                            // Copy to result
                            for (int idx = 0; idx < 32; idx = idx + 1) begin
                                if (idx < sorted_len)
                                    result[idx] <= sorted[idx];
                                else
                                    result[idx] <= 8'd0;
                            end
                            result_len <= sorted_len;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule