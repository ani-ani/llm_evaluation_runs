module majority_check(
    input [2:0] n,
    input [7:0][7:0] arr,
    input [7:0] x,
    output reg result
);

    reg [2:0] first_idx;
    reg found;
    reg [2:0] target_idx;
    reg [7:0] val_at_target;
    reg valid_target;
    
    always @(*) begin
        // Step 1: Find first occurrence of x in parallel
        found = 0;
        first_idx = 3'b0;
        
        // We use a priority encoder logic. 
        // Since the array is sorted, the first occurrence is the smallest index where arr[i] == x.
        // However, we must verify arr[i-1] < x for true first occurrence or i==0.
        // Given the requirement "Parallel comparators... for all 8 positions" and the specific logic:
        // "arr[i] == x AND (i == 0 OR arr[i-1] < x)"
        // We check this condition for all i in parallel and pick the lowest index.
        // NOTE: We assume arr[i] for i >= n is irrelevant or we strictly use n to bound logic.
        // However, the input array is fixed 8 elements. We must be careful with indices >= n.
        // The problem states n ranges 1-8.
        
        // Priority logic from top to bottom (0 to 7)
        if (n > 0 && arr[0] == x) begin
            first_idx = 3'd0;
            found = 1;
        end else if (n > 1 && arr[1] == x && arr[0] < x) begin
            first_idx = 3'd1;
            found = 1;
        end else if (n > 2 && arr[2] == x && arr[1] < x) begin
            first_idx = 3'd2;
            found = 1;
        end else if (n > 3 && arr[3] == x && arr[2] < x) begin
            first_idx = 3'd3;
            found = 1;
        end else if (n > 4 && arr[4] == x && arr[3] < x) begin
            first_idx = 3'd4;
            found = 1;
        end else if (n > 5 && arr[5] == x && arr[4] < x) begin
            first_idx = 3'd5;
            found = 1;
        end else if (n > 6 && arr[6] == x && arr[5] < x) begin
            first_idx = 3'd6;
            found = 1;
        end else if (n > 7 && arr[7] == x && arr[6] < x) begin
            first_idx = 3'd7;
            found = 1;
        end
        
        // Step 2: Calculate target index (first_idx + floor(n/2))
        // floor(n/2) is n >> 1. Since n is max 8, we can do a 3-bit shift.
        target_idx = first_idx + (n >> 1);
        
        // Step 3: Check validity and value at target index
        // The index must be < n (strictly within valid array range)
        valid_target = (target_idx < n);
        
        // We need to read arr[target_idx]. We use a case statement for indexing.
        // If target_idx is out of valid bounds (>=8 or >=n), val_at_target is don't care or zero.
        // We handle the safety within valid_target check later.
        case(target_idx)
            3'd0: val_at_target = arr[0];
            3'd1: val_at_target = arr[1];
            3'd2: val_at_target = arr[2];
            3'd3: val_at_target = arr[3];
            3'd4: val_at_target = arr[4];
            3'd5: val_at_target = arr[5];
            3'd6: val_at_target = arr[6];
            3'd7: val_at_target = arr[7];
            default: val_at_target = 8'b0;
        endcase
        
        // Step 4: Final Result
        // result is 1 if x was found AND the target index is valid AND the value at target index is x
        result = found && valid_target && (val_at_target == x);
    end

endmodule
