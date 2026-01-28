module MonoPoleMagnet (
    input clk,
    input rst_n,
    input start,
    input [7:0] grid_0,
    input [7:0] grid_1,
    input [7:0] grid_2,
    input [7:0] grid_3,
    input [7:0] grid_4,
    input [7:0] grid_5,
    input [7:0] grid_6,
    input [7:0] grid_7,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE            = 3'd0;
    localparam [2:0] ROW_CHECK       = 3'd1;
    localparam [2:0] COL_CHECK       = 3'd2;
    localparam [2:0] CONSISTENCY_CHECK = 3'd3;
    localparam [2:0] COMPONENT_COUNT = 3'd4;
    localparam [2:0] DONE            = 3'd5;
    localparam [2:0] ERROR           = 3'd6;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] grid_reg [0:7];  // Store grid locally
    reg [2:0] row_idx;          // Current row being processed
    reg [2:0] col_idx;          // Current column being processed
    reg [7:0] visited [0:7];    // Visited cells (8x8 array)
    reg [7:0] queue_x [0:63];   // BFS queue for X coordinates
    reg [5:0] queue_y [0:63];   // BFS queue for Y coordinates
    reg [5:0] q_head;
    reg [5:0] q_tail;
    reg [15:0] component_count;
    reg [7:0] empty_rows;
    reg [7:0] empty_cols;
    reg valid_flag;
    reg [2:0] check_idx;
    reg [2:0] i, j;  // Loop variables
    
    // Temporary registers for row/col check
    reg [2:0] black_start;
    reg [2:0] black_end;
    reg [2:0] black_count;
    reg in_black;
    reg has_gap;
    reg has_black;

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: next_state = start ? ROW_CHECK : IDLE;
            
            ROW_CHECK: begin
                if (row_idx == 8'd8) next_state = COL_CHECK;
                else next_state = ROW_CHECK;
            end
            
            COL_CHECK: begin
                if (col_idx == 8'd8) next_state = CONSISTENCY_CHECK;
                else next_state = COL_CHECK;
            end
            
            CONSISTENCY_CHECK: begin
                if (valid_flag) next_state = COMPONENT_COUNT;
                else next_state = ERROR;
            end
            
            COMPONENT_COUNT: begin
                // Find next unvisited black cell
                if (component_count > 16'd64) next_state = ERROR;  // Safety
                else if (row_idx == 8'd8) next_state = DONE;
                else next_state = COMPONENT_COUNT;
            end
            
            DONE: next_state = IDLE;
            ERROR: next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            component_count <= 16'd0;
            empty_rows <= 8'd0;
            empty_cols <= 8'd0;
            valid_flag <= 1'b0;
            check_idx <= 3'd0;
            q_head <= 6'd0;
            q_tail <= 6'd0;
            black_start <= 3'd0;
            black_end <= 3'd0;
            black_count <= 3'd0;
            in_black <= 1'b0;
            has_gap <= 1'b0;
            has_black <= 1'b0;
            
            // Initialize grid and visited
            for (i = 0; i < 8; i = i + 1) begin
                grid_reg[i] <= 8'd0;
                visited[i] <= 8'd0;
            end
            
            for (i = 0; i < 64; i = i + 1) begin
                queue_x[i] <= 8'd0;
                queue_y[i] <= 6'd0;
            end
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load grid from inputs
                        grid_reg[0] <= grid_0;
                        grid_reg[1] <= grid_1;
                        grid_reg[2] <= grid_2;
                        grid_reg[3] <= grid_3;
                        grid_reg[4] <= grid_4;
                        grid_reg[5] <= grid_5;
                        grid_reg[6] <= grid_6;
                        grid_reg[7] <= grid_7;
                        
                        // Reset tracking variables
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                        component_count <= 16'd0;
                        empty_rows <= 8'd0;
                        empty_cols <= 8'd0;
                        valid_flag <= 1'b1;
                        check_idx <= 3'd0;
                        q_head <= 6'd0;
                        q_tail <= 6'd0;
                        
                        // Clear visited
                        for (i = 0; i < 8; i = i + 1) begin
                            visited[i] <= 8'd0;
                        end
                    end
                end
                
                ROW_CHECK: begin
                    // Check current row for contiguity
                    if (row_idx < 8'd8) begin
                        // Initialize check variables
                        if (check_idx == 3'd0) begin
                            in_black <= 1'b0;
                            has_gap <= 1'b0;
                            has_black <= 1'b0;
                            black_start <= 3'd0;
                            black_end <= 3'd0;
                        end
                        
                        if (check_idx < 8'd8) begin
                            // Check if cell is black
                            if (grid_reg[row_idx][7 - check_idx]) begin
                                has_black <= 1'b1;
                                if (!in_black) begin
                                    if (has_black && !has_gap) begin
                                        has_gap <= 1'b1;  // Found gap
                                    end
                                    in_black <= 1'b1;
                                    black_start <= check_idx;
                                end
                                black_end <= check_idx;
                            end else begin
                                if (in_black) begin
                                    in_black <= 1'b0;
                                end
                            end
                            check_idx <= check_idx + 3'd1;
                        end else begin
                            // Finished checking row
                            if (has_gap) valid_flag <= 1'b0;
                            if (!has_black) empty_rows[row_idx] <= 1'b1;
                            row_idx <= row_idx + 3'd1;
                            check_idx <= 3'd0;
                        end
                    end
                end
                
                COL_CHECK: begin
                    // Check current column for contiguity
                    if (col_idx < 8'd8) begin
                        if (check_idx == 3'd0) begin
                            in_black <= 1'b0;
                            has_gap <= 1'b0;
                            has_black <= 1'b0;
                            black_start <= 3'd0;
                            black_end <= 3'd0;
                        end
                        
                        if (check_idx < 8'd8) begin
                            // Check if cell is black
                            if (grid_reg[7 - check_idx][7 - col_idx]) begin
                                has_black <= 1'b1;
                                if (!in_black) begin
                                    if (has_black && !has_gap) begin
                                        has_gap <= 1'b1;
                                    end
                                    in_black <= 1'b1;
                                    black_start <= check_idx;
                                end
                                black_end <= check_idx;
                            end else begin
                                if (in_black) begin
                                    in_black <= 1'b0;
                                end
                            end
                            check_idx <= check_idx + 3'd1;
                        end else begin
                            // Finished checking column
                            if (has_gap) valid_flag <= 1'b0;
                            if (!has_black) empty_cols[col_idx] <= 1'b1;
                            col_idx <= col_idx + 3'd1;
                            check_idx <= 3'd0;
                        end
                    end
                end
                
                CONSISTENCY_CHECK: begin
                    // Check: (empty_rows == 0) xor (empty_cols == 0) == 0
                    // This means both must be 0 or both must be non-zero
                    if (valid_flag) begin
                        if (empty_rows == 8'd0 && empty_cols != 8'd0) begin
                            valid_flag <= 1'b0;
                        end else if (empty_rows != 8'd0 && empty_cols == 8'd0) begin
                            valid_flag <= 1'b0;
                        end
                    end
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                end
                
                COMPONENT_COUNT: begin
                    // Find next unvisited black cell
                    if (row_idx < 8'd8) begin
                        if (col_idx < 8'd8) begin
                            if (!visited[row_idx][7 - col_idx] && grid_reg[row_idx][7 - col_idx]) begin
                                // Found new component
                                component_count <= component_count + 16'd1;
                                
                                // Start BFS
                                queue_x[0] <= row_idx;
                                queue_y[0] <= {1'b0, col_idx};
                                q_head <= 6'd0;
                                q_tail <= 6'd1;
                                visited[row_idx][7 - col_idx] <= 1'b1;
                            end else begin
                                col_idx <= col_idx + 3'd1;
                            end
                        end else begin
                            col_idx <= 3'd0;
                            row_idx <= row_idx + 3'd1;
                        end
                    end
                    
                    // Process BFS queue
                    if (q_head < q_tail) begin
                        // Get current cell
                        if (q_head < q_tail) begin
                            // Process neighbors
                            // This requires multi-cycle processing
                            // For simplicity, we'll do one neighbor per cycle
                            
                            // We need to track which neighbor we're checking
                            if (check_idx < 3'd4) begin
                                // Check 4 neighbors
                                case (check_idx)
                                    3'd0: begin  // Up
                                        if (queue_x[q_head] > 3'd0 && !visited[queue_x[q_head] - 1][7 - queue_y[q_head]] && grid_reg[queue_x[q_head] - 1][7 - queue_y[q_head]]) begin
                                            visited[queue_x[q_head] - 1][7 - queue_y[q_head]] <= 1'b1;
                                            queue_x[q_tail] <= queue_x[q_head] - 1;
                                            queue_y[q_tail] <= queue_y[q_head];
                                            q_tail <= q_tail + 6'd1;
                                        end
                                    end
                                    3'd1: begin  // Down
                                        if (queue_x[q_head] < 3'd7 && !visited[queue_x[q_head] + 1][7 - queue_y[q_head]] && grid_reg[queue_x[q_head] + 1][7 - queue_y[q_head]]) begin
                                            visited[queue_x[q_head] + 1][7 - queue_y[q_head]] <= 1'b1;
                                            queue_x[q_tail] <= queue_x[q_head] + 1;
                                            queue_y[q_tail] <= queue_y[q_head];
                                            q_tail <= q_tail + 6'd1;
                                        end
                                    end
                                    3'd2: begin  // Left (column + 1)
                                        if (queue_y[q_head] < 3'd7 && !visited[queue_x[q_head]][7 - (queue_y[q_head] + 1)] && grid_reg[queue_x[q_head]][7 - (queue_y[q_head] + 1)]) begin
                                            visited[queue_x[q_head]][7 - (queue_y[q_head] + 1)] <= 1'b1;
                                            queue_x[q_tail] <= queue_x[q_head];
                                            queue_y[q_tail] <= queue_y[q_head] + 6'd1;
                                            q_tail <= q_tail + 6'd1;
                                        end
                                    end
                                    3'd3: begin  // Right (column - 1)
                                        if (queue_y[q_head] > 3'd0 && !visited[queue_x[q_head]][7 - (queue_y[q_head] - 1)] && grid_reg[queue_x[q_head]][7 - (queue_y[q_head] - 1)]) begin
                                            visited[queue_x[q_head]][7 - (queue_y[q_head] - 1)] <= 1'b1;
                                            queue_x[q_tail] <= queue_x[q_head];
                                            queue_y[q_tail] <= queue_y[q_head] - 6'd1;
                                            q_tail <= q_tail + 6'd1;
                                        end
                                    end
                                endcase
                                check_idx <= check_idx + 3'd1;
                            end else begin
                                // Move to next in queue
                                q_head <= q_head + 6'd1;
                                check_idx <= 3'd0;
                            end
                        end
                    end
                    
                    // Reset check_idx when queue is empty
                    if (q_head >= q_tail && check_idx == 3'd4) begin
                        check_idx <= 3'd0;
                        col_idx <= col_idx + 3'd1;  // Move to next column
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= component_count;
                end
                
                ERROR: begin
                    done <= 1'b1;
                    result <= 16'hFFFF;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule