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

    // Unpack w_packed into array
    wire [DATA_WIDTH-1:0] w [0:MAX_M-1];
    genvar gi;
    generate
        for (gi = 0; gi < MAX_M; gi = gi + 1) begin : unpack
            assign w[gi] = w_packed[gi*DATA_WIDTH +: DATA_WIDTH];
        end
    endgenerate

    // Descending bubble sort
    reg [DATA_WIDTH-1:0] sorted_w [0:MAX_M-1];
    integer i_sort, j_sort;
    always @(*) begin
        // Initialize sorted_w
        for (i_sort = 0; i_sort < MAX_M; i_sort = i_sort + 1) begin
            if (i_sort < m) begin
                sorted_w[i_sort] = w[i_sort];
            end else begin
                sorted_w[i_sort] = {DATA_WIDTH{1'b0}};
            end
        end

        // Bubble sort
        for (i_sort = 0; i_sort < m; i_sort = i_sort + 1) begin
            for (j_sort = 0; j_sort < m - 1 - i_sort; j_sort = j_sort + 1) begin
                // Swap if out of order
                if (sorted_w[j_sort] < sorted_w[j_sort + 1]) begin
                    // Swap elements using temp variable
                    reg [DATA_WIDTH-1:0] temp;
                    temp = sorted_w[j_sort];
                    sorted_w[j_sort] = sorted_w[j_sort + 1];
                    sorted_w[j_sort + 1] = temp;
                end
            end
        end
    end

    // Prefix sum calculation
    reg [RESULT_WIDTH-1:0] prefix [0:MAX_M];
    integer i_pre;
    always @(*) begin
        prefix[0] = {RESULT_WIDTH{1'b0}};
        for (i_pre = 0; i_pre < m; i_pre = i_pre + 1) begin
            prefix[i_pre + 1] = prefix[i_pre] + sorted_w[i_pre];
        end
    end

    // Find maximum k
    reg [4:0] k_max;
    integer i_k;
    always @(*) begin
        k_max = 5'd0;
        for (i_k = 1; i_k <= MAX_M; i_k = i_k + 1) begin
            if (i_k <= m) begin
                reg [RESULT_WIDTH-1:0] f_val;
                if (i_k[0]) begin  // Odd
                    f_val = (i_k * (i_k - 1)) / 2 + 1;
                end else begin      // Even
                    f_val = (i_k * i_k) / 2;
                end
                if (f_val <= n) begin
                    k_max = i_k[4:0];
                end
            end
        end
    end

    // Result assignment
    always @(*) begin
        result = prefix[k_max];
    end

endmodule