module treasure_map_solver (
    input [7:0] p1_data,
    input [7:0] p2_data,
    input [7:0] p3_data,
    input [7:0] p4_data,
    input [1:0] config,
    output reg [31:0] map_out,
    output reg valid
);

    // Internal grid storage: 4x4 grid of 2-bit values
    // Unpacked array for easier indexing during logic
    reg [1:0] grid [0:3][0:3];

    // Variables for validation logic
    integer r, c;
    integer tx, ty; // Treasure coordinates
    reg found_treasure;
    integer dist, expected_val;

    // Helper function to map a piece to a specific location in the grid
    // Loc: 0=TopLeft, 1=TopRight, 2=BottomLeft, 3=BottomRight
    task place_piece;
        input [7:0] piece;
        input [1:0] loc;
        begin
            case (loc)
                2'b00: begin // Top-Left (Rows 0-1, Cols 0-1)
                    grid[0][0] <= piece[1:0];
                    grid[0][1] <= piece[3:2];
                    grid[1][0] <= piece[5:4];
                    grid[1][1] <= piece[7:6];
                end
                2'b01: begin // Top-Right (Rows 0-1, Cols 2-3)
                    grid[0][2] <= piece[1:0];
                    grid[0][3] <= piece[3:2];
                    grid[1][2] <= piece[5:4];
                    grid[1][3] <= piece[7:6];
                end
                2'b10: begin // Bottom-Left (Rows 2-3, Cols 0-1)
                    grid[2][0] <= piece[1:0];
                    grid[2][1] <= piece[3:2];
                    grid[3][0] <= piece[5:4];
                    grid[3][1] <= piece[7:6];
                end
                2'b11: begin // Bottom-Right (Rows 2-3, Cols 2-3)
                    grid[2][2] <= piece[1:0];
                    grid[2][3] <= piece[3:2];
                    grid[3][2] <= piece[5:4];
                    grid[3][3] <= piece[7:6];
                end
            endcase
        end
    endtask

    integer i, j;
    integer zero_count;

    always @(*) begin
        // 1. Assemble Map based on config
        // Initialize grid to avoid latches if parts are not written (though task covers all)
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 4; j = j + 1) begin
                grid[i][j] = 2'b00;
            end
        end

        case (config)
            2'b00: begin
                place_piece(p1_data, 2'b00);
                place_piece(p2_data, 2'b01);
                place_piece(p3_data, 2'b10);
                place_piece(p4_data, 2'b11);
            end
            2'b01: begin
                place_piece(p1_data, 2'b00);
                place_piece(p3_data, 2'b01);
                place_piece(p2_data, 2'b10);
                place_piece(p4_data, 2'b11);
            end
            2'b10: begin
                place_piece(p2_data, 2'b00);
                place_piece(p1_data, 2'b01);
                place_piece(p3_data, 2'b10);
                place_piece(p4_data, 2'b11);
            end
            2'b11: begin
                place_piece(p2_data, 2'b00);
                place_piece(p4_data, 2'b01);
                place_piece(p1_data, 2'b10);
                place_piece(p3_data, 2'b11);
            end
        endcase

        // Pack map_out from grid
        map_out = {
            grid[3][3], grid[3][2], grid[3][1], grid[3][0],
            grid[2][3], grid[2][2], grid[2][1], grid[2][0],
            grid[1][3], grid[1][2], grid[1][1], grid[1][0],
            grid[0][3], grid[0][2], grid[0][1], grid[0][0]
        };

        // 2. Validate Map
        // Step 2a: Find the treasure (value 00)
        tx = -1;
        ty = -1;
        zero_count = 0;
        
        for (r = 0; r < 4; r = r + 1) begin
            for (c = 0; c < 4; c = c + 1) begin
                if (grid[r][c] == 2'b00) begin
                    zero_count = zero_count + 1;
                    tx = c;
                    ty = r;
                end
            end
        end

        // Step 2b: Check constraints
        if (zero_count != 1) begin
            valid = 1'b0;
        end else begin
            valid = 1'b1; // Assume valid until proven otherwise
            for (r = 0; r < 4; r = r + 1) begin
                for (c = 0; c < 4; c = c + 1) begin
                    // Calculate rectilinear distance
                    if (c > tx) dist = c - tx; else dist = tx - c;
                    if (r > ty) dist = dist + (r - ty); else dist = dist + (ty - r);
                    
                    // Expected value is distance modulo 4
                    expected_val = dist % 4;
                    
                    // Check if current cell matches
                    if (grid[r][c] != expected_val[1:0]) begin
                        valid = 1'b0;
                    end
                end
            end
        end
    end

endmodule