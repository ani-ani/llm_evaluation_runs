module find_kth(
    input [3:0] k,
    input [2:0] m,
    input [2:0] n,
    input [7:0] arr1 [0:7],
    input [7:0] arr2 [0:7],
    output reg [7:0] kth_element
);

    // Internal variables for the merge process
    reg [7:0] merged [0:15];
    integer i, j, idx;

    always @(*) begin
        // Initialize indices for arr1 and arr2
        i = 0;
        j = 0;
        idx = 0;
        
        // Reset merged array to avoid latches, though we only use up to idx
        // For synthesis, we will fill partially and use the last value
        
        // Merge the two sorted arrays until we reach the k-th element
        while (i < m && j < n && idx < 16) begin
            if (arr1[i] <= arr2[j]) begin
                merged[idx] = arr1[i];
                i = i + 1;
            end else begin
                merged[idx] = arr2[j];
                j = j + 1;
            end
            idx = idx + 1;
        end
        
        // If arr1 has remaining elements
        while (i < m && idx < 16) begin
            merged[idx] = arr1[i];
            i = i + 1;
            idx = idx + 1;
        end
        
        // If arr2 has remaining elements
        while (j < n && idx < 16) begin
            merged[idx] = arr2[j];
            j = j + 1;
            idx = idx + 1;
        end
        
        // Handle edge cases where k might be out of valid range (though specs say it's valid)
        // or if arrays are smaller than k. The problem states k is valid (1 <= k <= m+n).
        // k is 1-based, so index is k-1.
        // If k-1 is within the merged array size (idx), return it.
        // Otherwise (should not happen per specs, but for safety), return 0.
        
        if ((k - 1) < idx) begin
            kth_element = merged[k-1];
        end else begin
            kth_element = 8'hXX; // Undefined state, but specs say k is valid
        end
    end

endmodule
