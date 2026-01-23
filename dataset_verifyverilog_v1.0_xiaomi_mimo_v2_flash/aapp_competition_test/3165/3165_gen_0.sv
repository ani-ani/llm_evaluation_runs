module chess_rook_attacker (
    input [47:0] rook_data,
    input [31:0] move_data,
    input [1:0] k,
    input [1:0] p,
    output reg [15:0] result0,
    output reg [15:0] result1,
    output reg [15:0] result2,
    output reg [15:0] result3
);

    integer i, r, c;
    reg [7:0] board [3:0][3:0];
    reg [7:0] row_xor [3:0];
    reg [7:0] col_xor [3:0];
    reg [15:0] counts [0:3];
    reg [7:0] power;
    reg [1:0] src_row, src_col, dst_row, dst_col;
    
    always @(*) begin
        // Initialize board and XORs
        for (i = 0; i < 4; i = i + 1) begin
            row_xor[i] = 8'd0;
            col_xor[i] = 8'd0;
            for (r = 0; r < 4; r = r + 1) begin
                board[i][r] = 8'd0;
            end
        end
        
        // Step 1: Place rooks
        for (i = 0; i < 4; i = i + 1) begin
            if (i < k) begin
                // Extract rook data: bits [11:0] per rook
                // Row: bits [1:0], Col: bits [3:2], Power: bits [11:4]
                board[rook_data[i*12 + 1 -: 2]][rook_data[i*12 + 3 -: 2]] = rook_data[i*12 + 11 -: 8];
                row_xor[rook_data[i*12 + 1 -: 2]] = row_xor[rook_data[i*12 + 1 -: 2]] ^ rook_data[i*12 + 11 -: 8];
                col_xor[rook_data[i*12 + 3 -: 2]] = col_xor[rook_data[i*12 + 3 -: 2]] ^ rook_data[i*12 + 11 -: 8];
            end
        end
        
        // Step 2: Process moves
        for (i = 0; i < 4; i = i + 1) begin
            if (i < p) begin
                // Extract move data: bits [7:0] per move
                // src_row: bits [1:0], src_col: bits [3:2], dst_row: bits [5:4], dst_col: bits [7:6]
                src_row = move_data[i*8 + 1 -: 2];
                src_col = move_data[i*8 + 3 -: 2];
                dst_row = move_data[i*8 + 5 -: 2];
                dst_col = move_data[i*8 + 7 -: 2];
                
                // Get power from source
                power = board[src_row][src_col];
                
                // Update board
                board[src_row][src_col] = 8'd0;
                board[dst_row][dst_col] = power;
                
                // Update XORs
                row_xor[src_row] = row_xor[src_row] ^ power;
                col_xor[src_col] = col_xor[src_col] ^ power;
                row_xor[dst_row] = row_xor[dst_row] ^ power;
                col_xor[dst_col] = col_xor[dst_col] ^ power;
                
                // Count attacked fields
                counts[i] = 16'd0;
                for (r = 0; r < 4; r = r + 1) begin
                    for (c = 0; c < 4; c = c + 1) begin
                        if ((row_xor[r] ^ col_xor[c]) != 8'd0) begin
                            counts[i] = counts[i] + 16'd1;
                        end
                    end
                end
            end else begin
                counts[i] = 16'd0;
            end
        end
        
        // Assign outputs
        result0 = counts[0];
        result1 = counts[1];
        result2 = counts[2];
        result3 = counts[3];
    end

endmodule