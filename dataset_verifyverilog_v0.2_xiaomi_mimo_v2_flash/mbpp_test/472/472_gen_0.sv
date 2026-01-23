module check_consecutive(
    input [7:0] data [0:7],
    output reg result
);

    parameter N = 8;
    integer i, j;
    reg [7:0] min_val;
    reg [7:0] max_val;
    reg has_duplicates;

    always @(*) begin
        // 1. Find minimum value
        min_val = data[0];
        for (i = 1; i < N; i = i + 1) begin
            if (data[i] < min_val) begin
                min_val = data[i];
            end
        end

        // 2. Find maximum value
        max_val = data[0];
        for (i = 1; i < N; i = i + 1) begin
            if (data[i] > max_val) begin
                max_val = data[i];
            end
        end

        // 3. Check for duplicates
        has_duplicates = 1'b0;
        for (i = 0; i < N - 1; i = i + 1) begin
            for (j = i + 1; j < N; j = j + 1) begin
                if (data[i] == data[j]) begin
                    has_duplicates = 1'b1;
                end
            end
        end

        // 4. Compute result
        // Result is 1 if: no duplicates AND max = min + N - 1
        if (!has_duplicates && (max_val == (min_val + N - 1))) begin
            result = 1'b1;
        end else begin
            result = 1'b0;
        end
    end

endmodule