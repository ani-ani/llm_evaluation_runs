module GridColoringProblem (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] R,
    input wire [3:0] C,
    input wire [15:0] a,
    input wire [15:0] b,
    input wire [15:0] c,
    output reg [255:0] grid,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] BUILD      = 3'd2;
    localparam [2:0] VALID_OUT  = 3'd3;
    localparam [2:0] INVALID    = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [7:0] cycle_count;
    reg [7:0] row_idx;
    reg [7:0] col_idx;
    reg [15:0] a_rem, b_rem, c_rem;
    reg [3:0] R_reg, C_reg;
    
    // Pattern definitions
    localparam [1:0] PATTERN_CHECKER = 2'd0;
    localparam [1:0] PATTERN_2X2     = 2'd1;
    reg [1:0] pattern_type;
    
    // Temporary grid storage (for building)
    reg [3:0] temp_grid [0:15] [0:15];
    
    // Internal signals
    wire [15:0] total_cells;
    wire [15:0] min_cells;
    wire [15:0] max_cells;
    wire [15:0] cells_row_even;
    wire [15:0] cells_row_odd;
    wire [15:0] count_even;
    wire [15:0] count_odd;
    wire [15:0] count_rem;
    
    assign total_cells = R_reg * C_reg;
    
    // Pattern analysis
    // For checkerboard: 2 colors needed, counts differ by at most 1
    // For 2x2 blocks: 3 colors needed, specific ratios
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            grid <= 256'd0;
            cycle_count <= 8'd0;
            row_idx <= 8'd0;
            col_idx <= 8'd0;
            a_rem <= 16'd0;
            b_rem <= 16'd0;
            c_rem <= 16'd0;
            R_reg <= 4'd0;
            C_reg <= 4'd0;
            pattern_type <= PATTERN_CHECKER;
            // Initialize temp_grid
            for (int i = 0; i < 16; i = i + 1) begin
                for (int j = 0; j < 16; j = j + 1) begin
                    temp_grid[i][j] <= 4'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    row_idx <= 8'd0;
                    col_idx <= 8'd0;
                    
                    if (start) begin
                        R_reg <= R;
                        C_reg <= C;
                        a_rem <= a;
                        b_rem <= b;
                        c_rem <= c;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check total cells
                    if (total_cells > 16'd256) begin
                        state <= INVALID;
                    end else if (total_cells != (a + b + c)) begin
                        state <= INVALID;
                    end else begin
                        // Analyze pattern
                        cells_row_even = (C_reg + 1) >> 1;  // ceil(C/2)
                        cells_row_odd = C_reg >> 1;         // floor(C/2)
                        
                        count_even = (R_reg + 1) >> 1;      // ceil(R/2)
                        count_odd = R_reg >> 1;             // floor(R/2)
                        
                        // For checkerboard pattern
                        // Color A at even positions, B at odd positions
                        // Positions: (row + col) even -> A, odd -> B
                        min_cells = count_even * cells_row_even + count_odd * cells_row_odd;
                        max_cells = count_even * cells_row_odd + count_odd * cells_row_even;
                        
                        // Try checkerboard first (requires 2 colors)
                        // Check if A and B counts fit the pattern
                        if ((a >= min_cells && a <= max_cells) && 
                            (b >= min_cells && b <= max_cells) &&
                            (c == 16'd0)) begin
                            pattern_type <= PATTERN_CHECKER;
                            state <= BUILD;
                        end
                        // Try 2x2 pattern (requires 3 colors)
                        // 2x2 blocks: A B / C A pattern
                        else if (c > 16'd0) begin
                            // Check if counts roughly match expected ratio
                            // For 2x2 blocks, each block has 1A, 1B, 1C, 1A (2A total)
                            // So we need roughly 2:1:1 ratio A:B:C
                            // For a rectangle divisible by 2, we can tile it
                            if (R_reg[0] == 1'b0 && C_reg[0] == 1'b0) begin
                                pattern_type <= PATTERN_2X2;
                                state <= BUILD;
                            end else begin
                                state <= INVALID;
                            end
                        end else begin
                            state <= INVALID;
                        end
                    end
                    
                    if (cycle_count >= 8'd200) begin
                        state <= INVALID;
                    end
                end
                
                BUILD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Build the grid based on pattern
                    if (pattern_type == PATTERN_CHECKER) begin
                        // Build checkerboard with A and B
                        // Fill with A and B alternately, then adjust counts
                        if (row_idx < R_reg) begin
                            if (col_idx < C_reg) begin
                                // Check position
                                if (((row_idx + col_idx) & 1) == 0) begin
                                    // Even position
                                    if (a_rem > 0) begin
                                        temp_grid[row_idx][col_idx] <= 4'd1; // A
                                        a_rem <= a_rem - 16'd1;
                                    end else if (b_rem > 0) begin
                                        temp_grid[row_idx][col_idx] <= 4'd2; // B
                                        b_rem <= b_rem - 16'd1;
                                    end
                                end else begin
                                    // Odd position
                                    if (b_rem > 0) begin
                                        temp_grid[row_idx][col_idx] <= 4'd2; // B
                                        b_rem <= b_rem - 16'd1;
                                    end else if (a_rem > 0) begin
                                        temp_grid[row_idx][col_idx] <= 4'd1; // A
                                        a_rem <= a_rem - 16'd1;
                                    end
                                end
                                col_idx <= col_idx + 8'd1;
                            end else begin
                                col_idx <= 8'd0;
                                row_idx <= row_idx + 8'd1;
                            end
                        end else begin
                            // Check if all used
                            if (a_rem == 16'd0 && b_rem == 16'd0) begin
                                state <= VALID_OUT;
                            end else begin
                                state <= INVALID;
                            end
                        end
                    end else begin
                        // 2x2 pattern: A B / C A
                        // Repeat across grid
                        if (row_idx < R_reg) begin
                            if (col_idx < C_reg) begin
                                // Calculate position in 2x2 block
                                if (col_idx[0] == 1'b0 && row_idx[0] == 1'b0) begin
                                    // Top-left: A
                                    temp_grid[row_idx][col_idx] <= 4'd1;
                                    a_rem <= a_rem - 16'd1;
                                end else if (col_idx[0] == 1'b1 && row_idx[0] == 1'b0) begin
                                    // Top-right: B
                                    temp_grid[row_idx][col_idx] <= 4'd2;
                                    b_rem <= b_rem - 16'd1;
                                end else if (col_idx[0] == 1'b0 && row_idx[0] == 1'b1) begin
                                    // Bottom-left: C
                                    temp_grid[row_idx][col_idx] <= 4'd3;
                                    c_rem <= c_rem - 16'd1;
                                end else begin
                                    // Bottom-right: A
                                    temp_grid[row_idx][col_idx] <= 4'd1;
                                    a_rem <= a_rem - 16'd1;
                                end
                                col_idx <= col_idx + 8'd1;
                            end else begin
                                col_idx <= 8'd0;
                                row_idx <= row_idx + 8'd1;
                            end
                        end else begin
                            // Check if counts match
                            if (a_rem == 16'd0 && b_rem == 16'd0 && c_rem == 16'd0) begin
                                state <= VALID_OUT;
                            end else begin
                                state <= INVALID;
                            end
                        end
                    end
                    
                    if (cycle_count >= 8'd250) begin
                        state <= INVALID;
                    end
                end
                
                VALID_OUT: begin
                    // Pack temp_grid into grid output
                    // grid is 256 bits: 16x16 cells, each 4 bits
                    // Row-major order
                    for (int i = 0; i < 16; i = i + 1) begin
                        for (int j = 0; j < 16; j = j + 1) begin
                            if (i < R_reg && j < C_reg) begin
                                grid[(i * 16 + j) * 4 +: 4] <= temp_grid[i][j];
                            end else begin
                                grid[(i * 16 + j) * 4 +: 4] <= 4'd0;
                            end
                        end
                    end
                    valid <= 1'b1;
                    state <= FINISH;
                end
                
                INVALID: begin
                    grid <= 256'd0;
                    valid <= 1'b0;
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule