module matrix_sort_by_row_sum (
    input signed [7:0] matrix [0:2][0:2],
    output logic signed [7:0] sorted_matrix [0:2][0:2]
);

    // 1. Compute row sums (10-bit to accommodate 3x8-bit signed values)
    logic signed [9:0] sum [0:2];
    
    always_comb begin
        sum[0] = matrix[0][0] + matrix[0][1] + matrix[0][2];
        sum[1] = matrix[1][0] + matrix[1][1] + matrix[1][2];
        sum[2] = matrix[2][0] + matrix[2][1] + matrix[2][2];
    end

    // 2. Bubble sort logic to determine sorted row indices
    // Using 2 comparator stages
    logic [1:0] idx0, idx1, idx2;
    logic signed [9:0] s0, s1, s2;

    // Intermediate indices and sums for stage 1
    logic [1:0] temp0, temp1, temp2;
    logic signed [9:0] tmp0, tmp1, tmp2;

    always_comb begin
        // Initialize indices
        idx0 = 2'd0;
        idx1 = 2'd1;
        idx2 = 2'd2;
        
        s0 = sum[0];
        s1 = sum[1];
        s2 = sum[2];
        
        // Stage 1: Compare adjacent pairs
        // Compare sum[0] vs sum[1]
        if (s0 > s1) begin
            tmp0 = s0;
            s0 = s1;
            s1 = tmp0;
            temp0 = idx0;
            idx0 = idx1;
            idx1 = temp0;
        end
        // Compare sum[1] vs sum[2]
        if (s1 > s2) begin
            tmp1 = s1;
            s1 = s2;
            s2 = tmp1;
            temp1 = idx1;
            idx1 = idx2;
            idx2 = temp1;
        end
        
        // Stage 2: Final check (compare sum[0] vs sum[1] again to bubble up if needed)
        if (s0 > s1) begin
            tmp2 = s0;
            s0 = s1;
            s1 = tmp2;
            temp2 = idx0;
            idx0 = idx1;
            idx1 = temp2;
        end
    end

    // 3. Use sorted indices to select rows via multiplexers
    always_comb begin
        sorted_matrix[0][0] = matrix[idx0][0];
        sorted_matrix[0][1] = matrix[idx0][1];
        sorted_matrix[0][2] = matrix[idx0][2];
        
        sorted_matrix[1][0] = matrix[idx1][0];
        sorted_matrix[1][1] = matrix[idx1][1];
        sorted_matrix[1][2] = matrix[idx1][2];
        
        sorted_matrix[2][0] = matrix[idx2][0];
        sorted_matrix[2][1] = matrix[idx2][1];
        sorted_matrix[2][2] = matrix[idx2][2];
    end

endmodule