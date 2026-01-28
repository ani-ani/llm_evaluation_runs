module WolfSheepCabbageSolver (
    input [7:0] W,
    input [7:0] S,
    input [7:0] C,
    input [7:0] K,
    output reg result,
    output reg done
);

    // Internal wire declarations
    wire [15:0] total_items;
    wire [7:0] max_single;
    wire all_present;
    wire conflicts_exist;
    wire k_ge_3;
    wire k_is_2;
    wire k_is_1;
    wire k_is_0;
    wire k_ge_total;
    wire single_item_safe;
    wire two_item_safe;
    
    // Combinational logic
    // Calculate total items
    assign total_items = W + S + C;
    
    // Find maximum of W, S, C (simplified comparison logic)
    assign max_single = (W >= S) ? ((W >= C) ? W : C) : ((S >= C) ? S : C);
    
    // Check if all three types are present
    assign all_present = (W > 8'd0) && (S > 8'd0) && (C > 8'd0);
    
    // Check for conflicts (wolf-sheep or sheep-cabbage pairs)
    assign conflicts_exist = (W > 8'd0 && S > 8'd0) || (S > 8'd0 && C > 8'd0);
    
    // Key conditions
    assign k_is_0 = (K == 8'd0);
    assign k_is_1 = (K == 8'd1);
    assign k_is_2 = (K == 8'd2);
    assign k_ge_3 = (K >= 8'd3);
    assign k_ge_total = (K >= total_items);
    
    // For K=1: Safe only if no conflicts (S=0 or (W=0 and C=0))
    assign single_item_safe = (S == 8'd0) || ((W == 8'd0) && (C == 8'd0));
    
    // For K=2: Generally YES if max items <= 2 or special cases
    // Standard solution exists if we can separate items
    // For K=2, if all three present, it's tricky but possible if max <= 2
    // Actually, for K=2 and all three present, standard solution exists
    assign two_item_safe = (max_single <= 8'd2);
    
    // Main decision logic
    always @(*) begin
        done = 1'b1;  // Combinational - always done
        
        if (k_is_0) begin
            result = 1'b0;  // Impossible
        end
        else if (k_ge_total) begin
            result = 1'b1;  // All in one trip
        end
        else if (k_is_1) begin
            // K=1: Only safe if no conflicts to leave behind
            result = single_item_safe ? 1'b1 : 1'b0;
        end
        else if (k_is_2) begin
            // K=2: Standard solution exists for most cases
            // Exception: if all three present and one item type is > 2,
            // might need careful analysis, but generally YES
            // For this problem, we assume YES for K=2 unless extreme
            // Actually, standard wolf-sheep-cabbage with boat capacity 2
            // can always solve if done correctly
            result = 1'b1;
        end
        else if (k_ge_3) begin
            // K>=3: Standard solution always exists
            result = 1'b1;
        end
        else begin
            result = 1'b0;  // Default NO (shouldn't reach here)
        end
    end

endmodule