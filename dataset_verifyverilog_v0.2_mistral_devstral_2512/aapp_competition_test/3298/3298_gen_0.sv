module unsorted_permutations(
    input [3:0] n,
    input [7:0][31:0] data,
    output reg [31:0] count
);

    parameter MOD = 1000000009;
    localparam MAX_N = 8;

    reg [31:0] perm [0:MAX_N-1];
    reg [31:0] temp_data [0:MAX_N-1];
    integer i, j, k, m;
    reg [31:0] total;
    reg [31:0] fact [0:MAX_N];

    // Precompute factorials modulo MOD
    always @* begin
        fact[0] = 1;
        for (i = 1; i <= MAX_N; i = i + 1) begin
            fact[i] = (fact[i-1] * i) % MOD;
        end
    end

    // Copy input data to temp array
    always @* begin
        for (i = 0; i < MAX_N; i = i + 1) begin
            temp_data[i] = data[i];
        end
    end

    // Function to check if a permutation is entirely unsorted
    function reg [31:0] is_unsorted;
        input [31:0] p [0:MAX_N-1];
        input [3:0] size;
        reg [31:0] unsorted;
        integer idx, jdx;
        
        unsorted = 1;
        for (idx = 0; idx < size; idx = idx + 1) begin
            // Check if element at idx is sorted
            reg sorted = 1;
            for (jdx = 0; jdx < size; jdx = jdx + 1) begin
                if (jdx < idx) begin
                    if (p[jdx] > p[idx]) begin
                        sorted = 0;
                    end
                end else if (jdx > idx) begin
                    if (p[jdx] < p[idx]) begin
                        sorted = 0;
                    end
                end
            end
            if (sorted) begin
                unsorted = 0;
                break;
            end
        end
        is_unsorted = unsorted;
    endfunction

    // Function to generate all permutations and count unsorted ones
    function reg [31:0] count_unsorted_permutations;
        input [31:0] arr [0:MAX_N-1];
        input [3:0] size;
        reg [31:0] cnt;
        reg [31:0] current_perm [0:MAX_N-1];
        integer idx, jdx, kdx;
        reg [31:0] temp;
        
        cnt = 0;
        
        // Initialize current_perm
        for (idx = 0; idx < size; idx = idx + 1) begin
            current_perm[idx] = arr[idx];
        end
        
        // Generate all permutations
        for (idx = 0; idx < fact[size]; idx = idx + 1) begin
            if (is_unsorted(current_perm, size)) begin
                cnt = (cnt + 1) % MOD;
            end
            
            // Generate next permutation
            // Find the largest index k such that current_perm[k] < current_perm[k+1]
            kdx = size - 2;
            while (kdx >= 0 && current_perm[kdx] >= current_perm[kdx + 1]) begin
                kdx = kdx - 1;
            end
            
            if (kdx >= 0) begin
                // Find the largest index l > k such that current_perm[k] < current_perm[l]
                jdx = size - 1;
                while (current_perm[jdx] <= current_perm[kdx]) begin
                    jdx = jdx - 1;
                end
                
                // Swap current_perm[k] and current_perm[l]
                temp = current_perm[kdx];
                current_perm[kdx] = current_perm[jdx];
                current_perm[jdx] = temp;
                
                // Reverse the sequence from k+1 to the end
                idx = kdx + 1;
                jdx = size - 1;
                while (idx < jdx) begin
                    temp = current_perm[idx];
                    current_perm[idx] = current_perm[jdx];
                    current_perm[jdx] = temp;
                    idx = idx + 1;
                    jdx = jdx - 1;
                end
            end
        end
        
        count_unsorted_permutations = cnt;
    endfunction

    // Main logic
    always @* begin
        total = 0;
        if (n > 0 && n <= MAX_N) begin
            total = count_unsorted_permutations(temp_data, n);
        end
        count = total;
    end

endmodule