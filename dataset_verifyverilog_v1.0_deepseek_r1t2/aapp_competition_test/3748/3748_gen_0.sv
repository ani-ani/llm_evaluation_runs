module symmetry_check (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] grid [0:11] [0:11],
    input wire [3:0] H, W,
    output reg result,
    output reg done
);

    // State declarations with explicit widths
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] GEN_ROWS   = 3'd1;
    localparam [2:0] BUILD_GRID = 3'd2;
    localparam [2:0] CHECK_COLS = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    
    // Cycle counter to prevent infinite loops
    reg [9:0] cycle_count;
    localparam [9:0] MAX_CYCLES = 10'd1000;
    
    // Row pairing tracking
    reg [3:0] row_index;
    reg [3:0] row_pair [0:11];
    reg [7:0] temp_grid [0:11][0:11];
    reg match_found;
    reg [3:0] col_check_index;
    reg col_match;
    
    integer i, j;  // Loop counters

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 10'd0;
            row_index <= 4'd0;
            match_found <= 1'b0;
            
            // Initialize array with for-loop
            for (i = 0; i < 12; i = i + 1) begin
                row_pair[i] <= 4'd0;
                for (j = 0; j < 12; j = j + 1) begin
                    temp_grid[i][j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 10'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    cycle_count <= 10'd0;
                    match_found <= 1'b0;
                    
                    if (start) begin
                        next_state <= GEN_ROWS;
                        for (i = 0; i < 12; i = i + 1) begin
                            row_pair[i] <= i[3:0];  // Initialize row pairing
                        end
                    end
                end
                
                GEN_ROWS: begin
                    // Simple incremental permutation generation
                    // For actual implementation, replace with heap\'s algorithm
                    if (row_index < H - 4'd1) begin
                        row_pair[row_index] <= row_pair[row_index] + 4'd1;
                        next_state <= BUILD_GRID;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end
                
                BUILD_GRID: begin
                    // Build temporary grid with current row pairing
                    for (i = 0; i < 12; i = i + 1) begin
                        for (j = 0; j < W; j = j + 1) begin
                            temp_grid[i][j] <= grid[row_pair[i]][j];
                        end
                    end
                    next_state <= CHECK_COLS;
                    col_check_index <= 4'd0;
                    col_match <= 1'b1;
                end
                
                CHECK_COLS: begin
                    // Check column symmetry
                    for (i = 0; i < 12; i = i + 1) begin
                        if (temp_grid[i][col_check_index] != temp_grid[i][W - 4'd1 - col_check_index]) begin
                            col_match <= 1'b0;
                        end
                    end
                    
                    if (col_check_index == W/2) begin
                        if (col_match) begin
                            match_found <= 1'b1;
                            next_state <= DONE_STATE;
                        end else begin
                            row_index <= row_index + 4'd1;
                            next_state <= GEN_ROWS;
                        end
                    end else begin
                        col_check_index <= col_check_index + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    result <= match_found;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
            
            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
            end
        end
    end
endmodule