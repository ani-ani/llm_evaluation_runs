module StringGenerator(
    input [3:0] N,
    input [3:0] K,
    input [3:0] P,
    output [7:0] char_array [0:15],
    output valid,
    output error
);

    reg [7:0] char_array_reg [0:15];
    reg valid_reg;
    reg error_reg;
    integer i;

    always @(*) begin
        // Initialize outputs
        error_reg = 1'b0;
        valid_reg = 1'b0;
        for (i = 0; i < 16; i = i + 1) begin
            char_array_reg[i] = 8'd0;
        end

        // Check for invalid constraints
        if (P > N || K > N || P < 1 || K < 1) begin
            error_reg = 1'b1;
            valid_reg = 1'b0;
        end else if (P == N) begin
            // Palindrome case
            if (K > (N + 1) / 2) begin
                error_reg = 1'b1;
                valid_reg = 1'b0;
            end else begin
                // Generate palindrome pattern
                for (i = 0; i < N; i = i + 1) begin
                    if (i < (N + 1) / 2) begin
                        char_array_reg[i] = 8'h61 + i;
                    end else begin
                        char_array_reg[i] = char_array_reg[N - 1 - i];
                    end
                end
                valid_reg = 1'b1;
            end
        end else if (P == 1) begin
            // No palindromes longer than 1
            if (K >= N) begin
                // All distinct characters
                for (i = 0; i < N; i = i + 1) begin
                    char_array_reg[i] = 8'h61 + i;
                end
                valid_reg = 1'b1;
            end else begin
                // Repeat pattern to avoid palindromes
                for (i = 0; i < N; i = i + 1) begin
                    char_array_reg[i] = 8'h61 + (i % K);
                end
                valid_reg = 1'b1;
            end
        end else begin
            // 1 < P < N case
            // Generate one palindromic block of length P
            // and ensure no longer palindromes exist
            if (K > N - (P - 1)) begin
                error_reg = 1'b1;
                valid_reg = 1'b0;
            end else begin
                // Generate palindromic block
                for (i = 0; i < P; i = i + 1) begin
                    if (i < (P + 1) / 2) begin
                        char_array_reg[i] = 8'h61 + i;
                    end else begin
                        char_array_reg[i] = char_array_reg[P - 1 - i];
                    end
                end
                // Fill remaining characters with distinct values
                for (i = P; i < N; i = i + 1) begin
                    char_array_reg[i] = 8'h61 + (P + (i - P));
                end
                valid_reg = 1'b1;
            end
        end
    end

    // Assign outputs
    assign char_array[0] = char_array_reg[0];
    assign char_array[1] = char_array_reg[1];
    assign char_array[2] = char_array_reg[2];
    assign char_array[3] = char_array_reg[3];
    assign char_array[4] = char_array_reg[4];
    assign char_array[5] = char_array_reg[5];
    assign char_array[6] = char_array_reg[6];
    assign char_array[7] = char_array_reg[7];
    assign char_array[8] = char_array_reg[8];
    assign char_array[9] = char_array_reg[9];
    assign char_array[10] = char_array_reg[10];
    assign char_array[11] = char_array_reg[11];
    assign char_array[12] = char_array_reg[12];
    assign char_array[13] = char_array_reg[13];
    assign char_array[14] = char_array_reg[14];
    assign char_array[15] = char_array_reg[15];
    assign valid = valid_reg;
    assign error = error_reg;

endmodule