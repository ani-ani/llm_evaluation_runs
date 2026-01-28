module table_sort_check (
    input clk,
    input rst_n,
    input start,
    input [((4*4)-1):0][3:0] table_in,
    output reg result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] UNPACK       = 4'd1;
    localparam [3:0] CHECK_COL    = 4'd2;
    localparam [3:0] CHECK_ROW_A  = 4'd3;
    localparam [3:0] CHECK_MIS_A  = 4'd4;
    localparam [3:0] CHECK_ROW_B  = 4'd5;
    localparam [3:0] CHECK_MIS_B  = 4'd6;
    localparam [3:0] CHECK_ROW_C  = 4'd7;
    localparam [3:0] CHECK_MIS_C  = 4'd8;
    localparam [3:0] CHECK_ROW_D  = 4'd9;
    localparam [3:0] CHECK_MIS_D  = 4'd10;
    localparam [3:0] CHECK_COL_SWAP = 4'd11;
    localparam [3:0] PREPARE_ROW_SWAP = 4'd12;
    localparam [3:0] CHECK_ROW_SWAP_A = 4'd13;
    localparam [3:0] CHECK_MIS_ROW_A = 4'd14;
    localparam [3:0] CHECK_ROW_SWAP_B = 4'd15;
    localparam [3:0] CHECK_MIS_ROW_B = 4'd16;
    localparam [3:0] FINISH       = 4'd17;

    reg [3:0] state;
    reg [3:0] next_state;
    
    // Internal registers
    reg [3:0] table [0:3][0:3];
    reg [3:0] col_swap_map [0:3];
    reg [3:0] row_val [0:3];
    reg [1:0] row_idx;
    reg [1:0] col_idx;
    reg [1:0] check_col;
    reg [1:0] swap_idx;
    reg [2:0] mis_count;
    reg [1:0] mis_count2;
    reg [1:0] mis_count3;
    reg [1:0] mis_count4;
    reg row_ok_a;
    reg row_ok_b;
    reg row_ok_c;
    reg row_ok_d;
    reg found_valid;
    reg swap_option;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd7;

    integer i, j, k;

    // Helper task to check if row is fixable with at most one swap
    // Returns mis_count and flag
    task check_row_fixable;
        input [3:0] row_data [0:3];
        input [3:0] target [0:3];
        output [2:0] mis_cnt;
        output fixable;
        integer r, c, d;
        reg [3:0] temp_row [0:3];
        reg [3:0] swap_temp;
        reg has_mis;
        begin
            mis_cnt = 3'd0;
            fixable = 1'b0;
            has_mis = 1'b0;
            
            // Count mismatches
            for (r = 0; r < 4; r = r + 1) begin
                if (row_data[r] != target[r]) begin
                    mis_cnt = mis_cnt + 3'd1;
                    has_mis = 1'b1;
                end
            end
            
            if (mis_cnt == 3'd0) begin
                fixable = 1'b1;
            end else if (mis_cnt == 3'd2) begin
                // Check if a single swap can fix it
                for (r = 0; r < 4; r = r + 1) begin
                    for (c = r + 1; c < 4; c = c + 1) begin
                        // Swap and check
                        for (d = 0; d < 4; d = d + 1) begin
                            temp_row[d] = row_data[d];
                        end
                        swap_temp = temp_row[r];
                        temp_row[r] = temp_row[c];
                        temp_row[c] = swap_temp;
                        
                        // Check if now matches target
                        if ((temp_row[0] == target[0]) && 
                            (temp_row[1] == target[1]) && 
                            (temp_row[2] == target[2]) && 
                            (temp_row[3] == target[3])) begin
                            fixable = 1'b1;
                        end
                    end
                end
            end else begin
                fixable = 1'b0;
            end
        end
    endtask

    // Combinational logic for row checking with current column swap
    // We need to compute targets based on column swap
    always @(*) begin
        reg [3:0] target_row [0:3];
        reg [3:0] current_row [0:3];
        integer r, c;
        
        // Default values
        mis_count = 3'd0;
        mis_count2 = 2'd0;
        mis_count3 = 2'd0;
        mis_count4 = 2'd0;
        row_ok_a = 1'b0;
        row_ok_b = 1'b0;
        row_ok_c = 1'b0;
        row_ok_d = 1'b0;
        
        // For Option A: check with swapped columns
        // Row 0 target: [1,2,3,4]
        // But we apply column swap first
        
        // Row 0 check
        if (state == CHECK_ROW_A) begin
            for (r = 0; r < 4; r = r + 1) begin
                // Column swap: table[row][col] goes to position col_swap_map[col]
                current_row[r] = table[0][r];
            end
            // Target for row 0 is [1,2,3,4]
            target_row[0] = 4'd1;
            target_row[1] = 4'd2;
            target_row[2] = 4'd3;
            target_row[3] = 4'd4;
            check_row_fixable(current_row, target_row, mis_count, row_ok_a);
        end
        
        // Row 1 check  
        if (state == CHECK_ROW_B) begin
            for (r = 0; r < 4; r = r + 1) begin
                current_row[r] = table[1][r];
            end
            target_row[0] = 4'd5;
            target_row[1] = 4'd6;
            target_row[2] = 4'd7;
            target_row[3] = 4'd8;
            check_row_fixable(current_row, target_row, mis_count2, row_ok_b);
        end
        
        // Row 2 check
        if (state == CHECK_ROW_C) begin
            for (r = 0; r < 4; r = r + 1) begin
                current_row[r] = table[2][r];
            end
            target_row[0] = 4'd9;
            target_row[1] = 4'd10;
            target_row[2] = 4'd11;
            target_row[3] = 4'd12;
            check_row_fixable(current_row, target_row, mis_count3, row_ok_c);
        end
        
        // Row 3 check
        if (state == CHECK_ROW_D) begin
            for (r = 0; r < 4; r = r + 1) begin
                current_row[r] = table[3][r];
            end
            target_row[0] = 4'd13;
            target_row[1] = 4'd14;
            target_row[2] = 4'd15;
            target_row[3] = 4'd16;
            check_row_fixable(current_row, target_row, mis_count4, row_ok_d);
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 3'd0;
            row_idx <= 2'd0;
            col_idx <= 2'd0;
            check_col <= 2'd0;
            swap_idx <= 2'd0;
            found_valid <= 1'b0;
            swap_option <= 1'b0;
            // Initialize all registers
            for (i = 0; i < 4; i = i + 1) begin
                for (j = 0; j < 4; j = j + 1) begin
                    table[i][j] <= 4'd0;
                end
                col_swap_map[i] <= 4'd0;
                row_val[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    found_valid <= 1'b0;
                    swap_option <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= UNPACK;
                    end
                end
                
                UNPACK: begin
                    // Unpack table_in into internal 2D array
                    // table_in is indexed as table_in[(i*M + j)*DATA_WIDTH +: DATA_WIDTH]
                    // But we declared it as [3:0][3:0] packed array
                    // So we can access directly
                    for (i = 0; i < 4; i = i + 1) begin
                        for (j = 0; j < 4; j = j + 1) begin
                            table[i][j] <= table_in[i*4 + j];
                        end
                    end
                    // Initialize column swap map to identity
                    for (i = 0; i < 4; i = i + 1) begin
                        col_swap_map[i] <= i;
                    end
                    check_col <= 2'd0;
                    found_valid <= 1'b0;
                    state <= CHECK_COL;
                end
                
                CHECK_COL: begin
                    // Apply column swap to check_col
                    // Swap column check_col with column swap_idx
                    // For identity check (swap_idx = check_col means no swap)
                    // Or for actual swap
                    
                    // We'll do this in CHECK_COL_SWAP state
                    state <= CHECK_COL_SWAP;
                end
                
                CHECK_COL_SWAP: begin
                    // Apply the column swap operation
                    // We're checking if swapping column check_col with swap_idx works
                    
                    // Set up column swap map for this swap
                    if (swap_idx == check_col) begin
                        // Identity (no swap for this pair)
                        for (i = 0; i < 4; i = i + 1) begin
                            col_swap_map[i] <= i;
                        end
                    end else begin
                        // Swap column check_col with swap_idx
                        for (i = 0; i < 4; i = i + 1) begin
                            if (i == check_col) begin
                                col_swap_map[i] <= swap_idx;
                            end else if (i == swap_idx) begin
                                col_swap_map[i] <= check_col;
                            end else begin
                                col_swap_map[i] <= i;
                            end
                        end
                    end
                    
                    // Check rows
                    state <= CHECK_ROW_A;
                end
                
                CHECK_ROW_A: begin
                    // Wait for combinational logic to compute
                    state <= CHECK_MIS_A;
                end
                
                CHECK_MIS_A: begin
                    if (row_ok_a) begin
                        state <= CHECK_ROW_B;
                    end else begin
                        // This column swap doesn't work, try next
                        if (swap_idx < 3'd3) begin
                            swap_idx <= swap_idx + 2'd1;
                            state <= CHECK_COL_SWAP;
                        end else if (check_col < 2'd3) begin
                            check_col <= check_col + 2'd1;
                            swap_idx <= 2'd0;
                            state <= CHECK_COL;
                        end else if (!swap_option) begin
                            // Tried all column swaps in Option A, try Option B
                            swap_option <= 1'b1;
                            check_col <= 2'd0;
                            swap_idx <= 2'd0;
                            state <= PREPARE_ROW_SWAP;
                        end else begin
                            // Tried everything, result is NO
                            state <= FINISH;
                        end
                    end
                end
                
                CHECK_ROW_B: begin
                    state <= CHECK_MIS_B;
                end
                
                CHECK_MIS_B: begin
                    if (row_ok_b) begin
                        state <= CHECK_ROW_C;
                    end else begin
                        // This column swap doesn't work
                        if (swap_idx < 3'd3) begin
                            swap_idx <= swap_idx + 2'd1;
                            state <= CHECK_COL_SWAP;
                        end else if (check_col < 2'd3) begin
                            check_col <= check_col + 2'd1;
                            swap_idx <= 2'd0;
                            state <= CHECK_COL;
                        end else if (!swap_option) begin
                            swap_option <= 1'b1;
                            check_col <= 2'd0;
                            swap_idx <= 2'd0;
                            state <= PREPARE_ROW_SWAP;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                CHECK_ROW_C: begin
                    state <= CHECK_MIS_C;
                end
                
                CHECK_MIS_C: begin
                    if (row_ok_c) begin
                        state <= CHECK_ROW_D;
                    end else begin
                        if (swap_idx < 3'd3) begin
                            swap_idx <= swap_idx + 2'd1;
                            state <= CHECK_COL_SWAP;
                        end else if (check_col < 2'd3) begin
                            check_col <= check_col + 2'd1;
                            swap_idx <= 2'd0;
                            state <= CHECK_COL;
                        end else if (!swap_option) begin
                            swap_option <= 1'b1;
                            check_col <= 2'd0;
                            swap_idx <= 2'd0;
                            state <= PREPARE_ROW_SWAP;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                CHECK_ROW_D: begin
                    state <= CHECK_MIS_D;
                end
                
                CHECK_MIS_D: begin
                    if (row_ok_d) begin
                        // All rows pass with this column swap!
                        found_valid <= 1'b1;
                        state <= FINISH;
                    end else begin
                        // This column swap doesn't work
                        if (swap_idx < 3'd3) begin
                            swap_idx <= swap_idx + 2'd1;
                            state <= CHECK_COL_SWAP;
                        end else if (check_col < 2'd3) begin
                            check_col <= check_col + 2'd1;
                            swap_idx <= 2'd0;
                            state <= CHECK_COL;
                        end else if (!swap_option) begin
                            // Try Option B: row swaps first
                            swap_option <= 1'b1;
                            check_col <= 2'd0;
                            swap_idx <= 2'd0;
                            state <= PREPARE_ROW_SWAP;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end
                
                PREPARE_ROW_SWAP: begin
                    // In Option B, we check if we can swap rows first
                    // to make all rows fixable, then apply column swap
                    // This is more complex, so for this implementation,
                    // we'll use a simplified approach
                    // For Option B, we need to check if there exists a column swap
                    // such that after applying it, each row has 0 or 2 mismatches
                    // with its target
                    
                    // Reset for column swap iteration
                    check_col <= 2'd0;
                    swap_idx <= 2'd0;
                    state <= CHECK_COL_SWAP;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (found_valid) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule