module beautiful_array #(
    parameter DATA_WIDTH = 16,
    parameter MAX_M = 16,
    parameter RESULT_WIDTH = 24
)(
    input [DATA_WIDTH-1:0] n,
    input [4:0] m,
    input [MAX_M*DATA_WIDTH-1:0] w_packed,
    output reg [RESULT_WIDTH-1:0] result
);

    // Generate block to unpack w_packed into an array
    wire [DATA_WIDTH-1:0] w [0:MAX_M-1];
    integer gi;
    generate
        for (gi = 0; gi < MAX_M; gi = gi + 1) begin : unpack_w
            assign w[gi] = w_packed[gi*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // Temporary array for sorting
    reg [DATA_WIDTH-1:0] sorted_w [0:MAX_M-1];
    integer i_sort, j_sort;
    
    // Combinational sorting logic
    always @(*) begin
        // Initialize sorted_w with first m elements
        for (i_sort = 0; i_sort < MAX_M; i_sort = i_sort + 1) begin
            if (i_sort < m)
                sorted_w[i_sort] = w[i_sort];
            else
                sorted_w[i_sort] = 0;
        end
        
        // Bubble sort (descending order)
        for (i_sort = 0; i_sort < m - 1; i_sort = i_sort + 1) begin
            for (j_sort = 0; j_sort < m - 1 - i_sort; j_sort = j_sort + 1) begin
                if (sorted_w[j_sort] < sorted_w[j_sort+1]) begin
                    // Swap elements
                    sorted_w[j_sort] = sorted_w[j_sort+1];
                    sorted_w[j_sort+1] = sorted_w[j_sort];
                end
            end
        end
    end

    // Prefix sums array
    reg [RESULT_WIDTH-1:0] prefix [0:MAX_M];
    integer i_pre;
    
    always @(*) begin
        prefix[0] = 0;
        for (i_pre = 0; i_pre < m; i_pre = i_pre + 1) begin
            prefix[i_pre+1] = prefix[i_pre] + sorted_w[i_pre];
        end
    end

    // Find maximum k such that f(k) <= n
    integer i_k;
    reg [4:0] k_max;
    
    always @(*) begin
        k_max = 0;
        for (i_k = 1; i_k <= MAX_M; i_k = i_k + 1) begin
            if (i_k <= m) begin
                reg [RESULT_WIDTH-1:0] f_val;
                if (i_k[0]) // odd
                    f_val = ((i_k * (i_k - 1)) >> 1) + 1;
                else // even
                    f_val = (i_k * i_k) >> 1;
                
                if (f_val <= n) begin
                    k_max = i_k;
                end
            end
        end
    end

    // Set result
    always @(*) begin
        result = prefix[k_max];
    end

endmodule