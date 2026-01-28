module scroll_code_solver(
    input clk,
    input rst_n,
    input start,
    input [3:0] grid [0:2][0:2],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [15:0] count;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // Grid storage
    reg [3:0] current_grid [0:2][0:2];
    reg [3:0] temp_grid [0:2][0:2];

    // Position tracking
    reg [3:0] row;
    reg [3:0] col;
    reg [3:0] zero_count;
    reg [3:0] zero_index;

    // Row uniqueness check
    reg [8:0] row_mask [0:2];
    reg row_valid;

    // L-shape constraint check
    reg l_shape_valid;

    // Initialize grid and count zeros
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            count <= 16'd0;
            cycle_count <= 16'd0;
            done <= 1'b0;
            
            // Initialize grid storage
            integer i, j;
            for (i = 0; i < 3; i = i + 1) begin
                for (j = 0; j < 3; j = j + 1) begin
                    current_grid[i][j] <= 4'd0;
                    temp_grid[i][j] <= 4'd0;
                end
            end
            
            row <= 4'd0;
            col <= 4'd0;
            zero_count <= 4'd0;
            zero_index <= 4'd0;
            row_valid <= 1'b0;
            l_shape_valid <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        next_state <= INIT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                INIT: begin
                    // Copy input grid
                    integer i, j;
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            current_grid[i][j] <= grid[i][j];
                            temp_grid[i][j] <= grid[i][j];
                        end
                    end
                    
                    // Count zeros
                    zero_count <= 4'd0;
                    for (i = 0; i < 3; i = i + 1) begin
                        for (j = 0; j < 3; j = j + 1) begin
                            if (grid[i][j] == 4'd0) begin
                                zero_count <= zero_count + 4'd1;
                            end
                        end
                    end
                    
                    // Initialize position
                    row <= 4'd0;
                    col <= 4'd0;
                    zero_index <= 4'd0;
                    count <= 16'd0;
                    
                    if (zero_count == 4'd0) begin
                        // No zeros, check constraints directly
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= FINISH;
                    end else begin
                        // Find next zero position
                        integer i, j, k;
                        reg found;
                        found = 1'b0;
                        
                        for (i = 0; i < 3; i = i + 1) begin
                            for (j = 0; j < 3; j = j + 1) begin
                                if (temp_grid[i][j] == 4'd0) begin
                                    if (zero_index == 4'd0) begin
                                        row <= i;
                                        col <= j;
                                        found = 1'b1;
                                    end
                                    zero_index <= zero_index + 4'd1;
                                end
                            end
                        end
                        
                        if (!found) begin
                            // No more zeros, check constraints
                            row_valid = 1'b1;
                            
                            // Check row uniqueness
                            for (i = 0; i < 3; i = i + 1) begin
                                row_mask[i] <= 9'd0;
                                for (j = 0; j < 3; j = j + 1) begin
                                    if (row_mask[i][temp_grid[i][j]]) begin
                                        row_valid = 1'b0;
                                    end
                                    row_mask[i][temp_grid[i][j]] <= 1'b1;
                                end
                            end
                            
                            if (row_valid) begin
                                // Check L-shape constraints
                                l_shape_valid = 1'b1;
                                for (i = 1; i < 3; i = i + 1) begin
                                    for (j = 0; j < 2; j = j + 1) begin
                                        reg [3:0] l, r, u;
                                        l = temp_grid[i][j];
                                        r = temp_grid[i][j+1];
                                        u = temp_grid[i-1][j];
                                        
                                        reg valid;
                                        valid = 1'b0;
                                        
                                        // Check all possible operations
                                        if (l * r == u) valid = 1'b1;
                                        if (l + r == u) valid = 1'b1;
                                        if (l > r && l - r == u) valid = 1'b1;
                                        if (r > l && r - l == u) valid = 1'b1;
                                        if (r != 4'd0 && l % r == 4'd0 && l / r == u) valid = 1'b1;
                                        if (l != 4'd0 && r % l == 4'd0 && r / l == u) valid = 1'b1;
                                        
                                        if (!valid) begin
                                            l_shape_valid = 1'b0;
                                        end
                                    end
                                end
                                
                                if (l_shape_valid) begin
                                    count <= count + 16'd1;
                                end
                            end
                            
                            // Move to next position
                            zero_index <= 4'd0;
                            row <= 4'd0;
                            col <= 4'd0;
                            
                            // Find next zero
                            found = 1'b0;
                            for (i = 0; i < 3; i = i + 1) begin
                                for (j = 0; j < 3; j = j + 1) begin
                                    if (temp_grid[i][j] == 4'd0) begin
                                        row <= i;
                                        col <= j;
                                        found = 1'b1;
                                        break;
                                    end
                                end
                                if (found) break;
                            end
                            
                            if (!found) begin
                                next_state <= FINISH;
                            end
                        end else begin
                            // Try all possible values for current zero
                            if (temp_grid[row][col] < 4'd9) begin
                                temp_grid[row][col] <= temp_grid[row][col] + 4'd1;
                                if (temp_grid[row][col] == 4'd0) begin
                                    temp_grid[row][col] <= 4'd1;
                                end
                            end else begin
                                temp_grid[row][col] <= 4'd0;
                                
                                // Backtrack
                                if (zero_index > 4'd0) begin
                                    zero_index <= zero_index - 4'd1;
                                    
                                    // Find previous zero
                                    integer prev_i, prev_j;
                                    reg prev_found;
                                    prev_found = 1'b0;
                                    
                                    for (prev_i = 2; prev_i >= 0; prev_i = prev_i - 1) begin
                                        for (prev_j = 2; prev_j >= 0; prev_j = prev_j - 1) begin
                                            if (current_grid[prev_i][prev_j] == 4'd0) begin
                                                if (zero_index == 4'd0) begin
                                                    row <= prev_i;
                                                    col <= prev_j;
                                                    prev_found = 1'b1;
                                                    break;
                                                end
                                                zero_index <= zero_index - 4'd1;
                                            end
                                        end
                                        if (prev_found) break;
                                    end
                                    
                                    if (prev_found) begin
                                        temp_grid[row][col] <= temp_grid[row][col] + 4'd1;
                                        if (temp_grid[row][col] == 4'd0) begin
                                            temp_grid[row][col] <= 4'd1;
                                        end
                                    end
                                end else begin
                                    next_state <= FINISH;
                                end
                            end
                        end
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase
        end
    end
endmodule