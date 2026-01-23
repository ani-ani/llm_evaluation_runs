module arithmetic_book (
    input [4:0] n,
    input [31:0] numbers [0:15],
    output reg [7:0] count
);

    integer i, j, k;
    reg [63:0] current_sum;
    reg [63:0] current_prod;
    reg match;

    always @(*) begin
        count = 8'b0;
        
        if (n >= 2) begin
            for (i = 0; i < n - 1; i = i + 1) begin
                for (j = i + 1; j < n; j = j + 1) begin
                    current_sum = 0;
                    current_prod = 1;
                    
                    for (k = i; k <= j; k = k + 1) begin
                        current_sum = current_sum + numbers[k];
                        current_prod = current_prod * numbers[k];
                    end
                    
                    if (current_sum == current_prod) begin
                        count = count + 1;
                    end
                end
            end
        end
    end

endmodule
