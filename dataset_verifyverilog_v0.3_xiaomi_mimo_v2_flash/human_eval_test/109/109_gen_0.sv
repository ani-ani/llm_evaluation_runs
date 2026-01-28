module move_one_ball(
    input [7:0] arr [0:7],
    output reg result
);
    // Internal signals for comparison results
    wire [6:0] compare_results;  // For i from 0 to 6
    wire boundary_comparison;
    
    // Check adjacent elements: arr[i] <= arr[i+1] for i=0..6
    assign compare_results[0] = (arr[0] <= arr[1]);
    assign compare_results[1] = (arr[1] <= arr[2]);
    assign compare_results[2] = (arr[2] <= arr[3]);
    assign compare_results[3] = (arr[3] <= arr[4]);
    assign compare_results[4] = (arr[4] <= arr[5]);
    assign compare_results[5] = (arr[5] <= arr[6]);
    assign compare_results[6] = (arr[6] <= arr[7]);
    
    // Check boundary condition: arr[7] <= arr[0]
    assign boundary_comparison = (arr[7] <= arr[0]);
    
    // Count drops (violations: arr[i] > arr[i+1])
    wire [2:0] drop_count;
    wire [6:0] drops_mask;
    
    // drops_mask[i] = 1 when arr[i] > arr[i+1] (i.e., compare_results[i] == 0)
    assign drops_mask[0] = ~compare_results[0];
    assign drops_mask[1] = ~compare_results[1];
    assign drops_mask[2] = ~compare_results[2];
    assign drops_mask[3] = ~compare_results[3];
    assign drops_mask[4] = ~compare_results[4];
    assign drops_mask[5] = ~compare_results[5];
    assign drops_mask[6] = ~compare_results[6];
    
    // Count bits in drops_mask (combinational logic)
    assign drop_count = 
        drops_mask[0] + drops_mask[1] + drops_mask[2] + drops_mask[3] +
        drops_mask[4] + drops_mask[5] + drops_mask[6];
    
    // Result logic:
    // 1. Already sorted: drops == 0
    // 2. Exactly one drop AND boundary condition satisfied: drops == 1 AND boundary_comparison == 1
    always @(*) begin
        if (drop_count == 3'd0) begin
            result = 1'b1;
        end else if (drop_count == 3'd1 && boundary_comparison) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end
endmodule