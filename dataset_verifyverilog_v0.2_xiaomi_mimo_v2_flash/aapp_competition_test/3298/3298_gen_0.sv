module unsorted_permutations(
    input [3:0] n,
    input [7:0][31:0] data,
    output reg [31:0] count
);
    integer i, j;
    reg [31:0] p [0:7];
    reg [31:0] d [0:7];
    reg [31:0] temp;
    reg unsorted;
    reg sorted_pos;
    reg descending;
    integer k_idx;
    integer l_idx;

    always @(*) begin
        // 1. Initialize local data array and Sort input
        for (i = 0; i < 8; i = i + 1) begin
            if (i < n) d[i] = data[i];
            else d[i] = 32'hFFFF_FFFF;
        end
        
        // Bubble sort d (only up to n elements)
        for (i = 0; i < n - 1; i = i + 1) begin
            for (j = 0; j < n - 1 - i; j = j + 1) begin
                if (d[j] > d[j+1]) begin
                    temp = d[j];
                    d[j] = d[j+1];
                    d[j+1] = temp;
                end
            end
        end

        // 2. Initialize permutation array p with sorted data
        for (i = 0; i < n; i = i + 1) begin
            p[i] = d[i];
        end

        // 3. Initialize count
        count = 0;

        // 4. Iterate through all permutations
        // We use a named block to allow disabling (breaking) the loop
        begin : PERM_LOOP
            while (1) begin
                // Check if current permutation is entirely unsorted
                unsorted = 1'b1;
                for (i = 0; i < n; i = i + 1) begin
                    sorted_pos = 1'b1;
                    // Check elements to the left
                    for (j = 0; j < i; j = j + 1) begin
                        if (p[j] > p[i]) sorted_pos = 1'b0;
                    end
                    // Check elements to the right
                    for (j = i + 1; j < n; j = j + 1) begin
                        if (p[j] < p[i]) sorted_pos = 1'b0;
                    end
                    // If any element is in sorted position, the permutation is not entirely unsorted
                    if (sorted_pos) unsorted = 1'b0;
                end

                if (unsorted) count = count + 1;

                // Check if current permutation is the last one (descending order)
                descending = 1'b1;
                for (i = 0; i < n - 1; i = i + 1) begin
                    if (p[i] < p[i+1]) descending = 1'b0;
                end
                
                if (descending) disable PERM_LOOP;

                // Generate Next Permutation (Step 1: Find k)
                k_idx = -1;
                for (i = n - 2; i >= 0; i = i - 1) begin
                    if (p[i] < p[i+1]) begin
                        k_idx = i;
                        i = -1; // Break loop manually
                    end
                end

                // Generate Next Permutation (Step 2: Find l)
                l_idx = -1;
                for (i = n - 1; i > k_idx; i = i - 1) begin
                    if (p[i] > p[k_idx]) begin
                        l_idx = i;
                        i = k_idx; // Break loop manually
                    end
                end

                // Swap p[k_idx] and p[l_idx]
                if (k_idx != -1 && l_idx != -1) begin
                    temp = p[k_idx];
                    p[k_idx] = p[l_idx];
                    p[l_idx] = temp;
                end

                // Reverse the suffix (k_idx + 1 to end)
                for (i = 0; i < (n - 1 - k_idx) / 2; i = i + 1) begin
                    temp = p[k_idx + 1 + i];
                    p[k_idx + 1 + i] = p[n - 1 - i];
                    p[n - 1 - i] = temp;
                end
            end
        end

        // 5. Apply modulo (though 40320 < 1000000009, this is required)
        // count = count % 1000000009; 
        // Modulo operator is resource intensive. Since max count is 40320, we can skip for synthesis efficiency,
        // but strictly following requirements:
        // Actually, 40320 fits in 32-bit, so strict compliance would be `count = count;`
        // The requirement says "Return count modulo 1000000009". 
        // Since the max possible value is significantly smaller than the modulus, 
        // the result is already effectively modulo'd. We omit the division for area efficiency.
    end
endmodule