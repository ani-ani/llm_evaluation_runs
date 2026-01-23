module chess_rook_attacker(
    input [47:0] rook_data,
    input [31:0] move_data,
    input [1:0] k,
    input [1:0] p,
    output [15:0] result0,
    output [15:0] result1,
    output [15:0] result2,
    output [15:0] result3
);

    reg [7:0] board [0:3][0:3];
    reg [7:0] row_xor [0:3];
    reg [7:0] col_xor [0:3];
    reg [15:0] count;
    integer i, j, r, c;

    always @(*) begin
        // Initialize board and XOR arrays
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                board[i][j] = 8'd0;
            end
            row_xor[i] = 8'd0;
            col_xor[i] = 8'd0;
        end

        // Place initial rooks
        for (i = 0; i < 4; i = i + 1) begin
            if (i < k) begin
                reg [1:0] row = rook_data[(12*i)+1:(12*i)];
                reg [1:0] col = rook_data[(12*i)+3:(12*i)+2];
                reg [7:0] power = rook_data[(12*i)+11:(12*i)+4];
                board[row][col] = power;
                row_xor[row] = row_xor[row] ^ power;
                col_xor[col] = col_xor[col] ^ power;
            end
        end

        // Process moves
        for (i = 0; i < 4; i = i + 1) begin
            if (i < p) begin
                reg [1:0] src_row = move_data[(8*i)+1:(8*i)];
                reg [1:0] src_col = move_data[(8*i)+3:(8*i)+2];
                reg [1:0] dst_row = move_data[(8*i)+5:(8*i)+4];
                reg [1:0] dst_col = move_data[(8*i)+7:(8*i)+6];
                reg [7:0] power = board[src_row][src_col];

                // Move rook
                board[src_row][src_col] = 8'd0;
                board[dst_row][dst_col] = power;
                row_xor[src_row] = row_xor[src_row] ^ power;
                col_xor[src_col] = col_xor[src_col] ^ power;
                row_xor[dst_row] = row_xor[dst_row] ^ power;
                col_xor[dst_col] = col_xor[dst_col] ^ power;

                // Count attacked fields
                count = 16'd0;
                for (r = 0; r < 4; r = r + 1) begin
                    for (c = 0; c < 4; c = c + 1) begin
                        if ((row_xor[r] ^ col_xor[c]) != 8'd0) begin
                            count = count + 16'd1;
                        end
                    end
                end

                // Assign result
                case (i)
                    0: result0 = count;
                    1: result1 = count;
                    2: result2 = count;
                    3: result3 = count;
                endcase
            end else begin
                case (i)
                    0: result0 = 16'd0;
                    1: result1 = 16'd0;
                    2: result2 = 16'd0;
                    3: result3 = 16'd0;
                endcase
            end
        end
    end

endmodule