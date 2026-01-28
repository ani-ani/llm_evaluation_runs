module magnet_module (
    input clk,
    input rst_n,
    input start,
    input [255:0] grid_flat,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CHECK_ROWS = 4'd1;
    localparam [3:0] CHECK_COLS = 4'd2;
    localparam [3:0] VALIDATE = 4'd3;
    localparam [3:0] SETUP_VISITED = 4'd4;
    localparam [3:0] FIND_COMPONENTS = 4'd5;
    localparam [3:0] FIND_START = 4'd6;
    localparam [3:0] BFS_RESET = 4'd7;
    localparam [3:0] BFS_LOOP = 4'd8;
    localparam [3:0] BFS_PROCESS = 4'd9;
    localparam [3:0] DONE_STATE = 4'd10;
    localparam [3:0] ERROR = 4'd11;

    reg [3:0] state;
    reg [3:0] next_state;

    // Registers for row/col checks
    reg [15:0] row_data;
    reg [15:0] col_data;
    reg [3:0] row_idx;
    reg [3:0] col_idx;
    reg [3:0] bit_idx;
    reg [1:0] row_state;
    reg [1:0] col_state;
    reg row_has_black;
    reg col_has_black;
    reg row_valid;
    reg col_valid;
    reg error_flag;

    // Registers for visited and component counting
    reg [255:0] visited;
    reg [7:0] comp_count;
    reg [7:0] start_idx;
    reg [3:0] bfs_x;
    reg [3:0] bfs_y;
    reg [7:0] bfs_queue [0:63];
    reg [5:0] bfs_head;
    reg [5:0] bfs_tail;
    reg [2:0] bfs_dir;
    reg [3:0] nx;
    reg [3:0] ny;
    reg [7:0] curr_idx;
    reg [7:0] new_idx;

    // Timing / Cycle count
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd2048;

    // Wires for extracting bits
    wire [15:0] current_row;
    wire [15:0] current_col;
    
    // Helper logic to extract current row from flat grid
    assign current_row = grid_flat[ (row_idx * 16) +: 16 ];
    
    // Helper logic to extract current column from flat grid
    // Manual extraction to avoid 2D slice errors
    assign current_col[0] = grid_flat[col_idx + 0*16];
    assign current_col[1] = grid_flat[col_idx + 1*16];
    assign current_col[2] = grid_flat[col_idx + 2*16];
    assign current_col[3] = grid_flat[col_idx + 3*16];
    assign current_col[4] = grid_flat[col_idx + 4*16];
    assign current_col[5] = grid_flat[col_idx + 5*16];
    assign current_col[6] = grid_flat[col_idx + 6*16];
    assign current_col[7] = grid_flat[col_idx + 7*16];
    assign current_col[8] = grid_flat[col_idx + 8*16];
    assign current_col[9] = grid_flat[col_idx + 9*16];
    assign current_col[10] = grid_flat[col_idx + 10*16];
    assign current_col[11] = grid_flat[col_idx + 11*16];
    assign current_col[12] = grid_flat[col_idx + 12*16];
    assign current_col[13] = grid_flat[col_idx + 13*16];
    assign current_col[14] = grid_flat[col_idx + 14*16];
    assign current_col[15] = grid_flat[col_idx + 15*16];

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_ROWS;
                else next_state = IDLE;
            end
            CHECK_ROWS: begin
                if (row_idx == 4'd15 && bit_idx == 4'd15) next_state = CHECK_COLS;
                else next_state = CHECK_ROWS;
            end
            CHECK_COLS: begin
                if (col_idx == 4'd15 && bit_idx == 4'd15) next_state = VALIDATE;
                else next_state = CHECK_COLS;
            end
            VALIDATE: begin
                if (error_flag) next_state = ERROR;
                else next_state = SETUP_VISITED;
            end
            SETUP_VISITED: next_state = FIND_START;
            FIND_START: begin
                if (start_idx > 8'd255) next_state = DONE_STATE;
                else if (visited[start_idx]) next_state = FIND_START;
                else if (grid_flat[start_idx]) next_state = BFS_RESET;
                else next_state = FIND_START;
            end
            BFS_RESET: next_state = BFS_LOOP;
            BFS_LOOP: begin
                if (bfs_head == bfs_tail) next_state = FIND_START;
                else next_state = BFS_PROCESS;
            end
            BFS_PROCESS: begin
                if (bfs_dir == 3'd4) next_state = BFS_LOOP;
                else next_state = BFS_PROCESS;
            end
            DONE_STATE: next_state = IDLE;
            ERROR: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State register and main logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 12'd0;
            row_idx <= 4'd0;
            col_idx <= 4'd0;
            bit_idx <= 4'd0;
            error_flag <= 1'b0;
            comp_count <= 8'd0;
            start_idx <= 8'd0;
            visited <= 256'd0;
            bfs_head <= 6'd0;
            bfs_tail <= 6'd0;
            bfs_dir <= 3'd0;
        end else begin
            // Default assignment for done
            done <= 1'b0;
            
            // Cycle count increment (stop at max to prevent infinite loops)
            if (state != IDLE && state != DONE_STATE && state != ERROR) begin
                if (cycle_count < MAX_CYCLES) cycle_count <= cycle_count + 12'd1;
            end else begin
                cycle_count <= 12'd0;
            end

            case (state)
                IDLE: begin
                    result <= 8'd0;
                    error_flag <= 1'b0;
                    row_idx <= 4'd0;
                    col_idx <= 4'd0;
                    bit_idx <= 4'd0;
                    comp_count <= 8'd0;
                    start_idx <= 8'd0;
                    visited <= 256'd0;
                end

                CHECK_ROWS: begin
                    if (bit_idx == 4'd0) begin
                        row_data <= current_row;
                        row_has_black <= 1'b0;
                        row_state <= 2'd0; // 0: before black, 1: in black, 2: after black
                        row_valid <= 1'b1;
                    end else begin
                        if (row_data[bit_idx]) begin
                            if (row_state == 2'd0) begin
                                row_state <= 2'd1; // Start black
                                row_has_black <= 1'b1;
                            end else if (row_state == 2'd2) begin
                                row_valid <= 1'b0; // Gap found
                            end
                        end else begin // White
                            if (row_state == 2'd1) row_state <= 2'd2; // End black
                        end
                    end

                    if (bit_idx == 4'd15) begin
                        if (!row_valid || (!row_has_black && !error_flag)) begin
                            error_flag <= 1'b1;
                        end
                        if (row_idx < 4'd15) begin
                            row_idx <= row_idx + 4'd1;
                            bit_idx <= 4'd0;
                        end
                    end else begin
                        bit_idx <= bit_idx + 4'd1;
                    end
                end

                CHECK_COLS: begin
                    if (bit_idx == 4'd0) begin
                        col_data <= current_col;
                        col_has_black <= 1'b0;
                        col_state <= 2'd0;
                        col_valid <= 1'b1;
                    end else begin
                        if (col_data[bit_idx]) begin
                            if (col_state == 2'd0) begin
                                col_state <= 2'd1;
                                col_has_black <= 1'b1;
                            end else if (col_state == 2'd2) begin
                                col_valid <= 1'b0;
                            end
                        end else begin
                            if (col_state == 2'd1) col_state <= 2'd2;
                        end
                    end

                    if (bit_idx == 4'd15) begin
                        if (!col_valid || (!col_has_black && !error_flag)) begin
                            error_flag <= 1'b1;
                        end
                        if (col_idx < 4'd15) begin
                            col_idx <= col_idx + 4'd1;
                            bit_idx <= 4'd0;
                        end
                    end else begin
                        bit_idx <= bit_idx + 4'd1;
                    end
                end

                VALIDATE: begin
                    // Just a transition state
                    // error_flag is already set if needed
                end

                SETUP_VISITED: begin
                    visited <= 256'd0;
                    comp_count <= 8'd0;
                    start_idx <= 8'd0;
                end

                FIND_START: begin
                    if (start_idx <= 8'd255) begin
                        if (visited[start_idx]) begin
                            start_idx <= start_idx + 8'd1;
                        end else if (grid_flat[start_idx]) begin
                            comp_count <= comp_count + 8'd1;
                            // Do not increment start_idx here, wait for BFS
                        end else begin
                            start_idx <= start_idx + 8'd1;
                        end
                    end
                end

                BFS_RESET: begin
                    // Mark start as visited and enqueue
                    visited[start_idx] <= 1'b1;
                    bfs_queue[0] <= start_idx;
                    bfs_head <= 6'd0;
                    bfs_tail <= 6'd1;
                    start_idx <= start_idx + 8'd1; // Move search index forward for next time
                    bfs_dir <= 3'd0;
                end

                BFS_LOOP: begin
                    if (bfs_head != bfs_tail) begin
                        curr_idx <= bfs_queue[bfs_head];
                        bfs_head <= bfs_head + 6'd1;
                        bfs_dir <= 3'd0;
                    end
                end

                BFS_PROCESS: begin
                    // Convert curr_idx to x, y
                    // curr_idx = y*16 + x
                    bfs_y <= curr_idx[7:4];
                    bfs_x <= curr_idx[3:0];
                    
                    case (bfs_dir)
                        3'd0: begin nx <= (bfs_x > 0) ? bfs_x - 4'd1 : 4'd16; ny <= bfs_y; end
                        3'd1: begin nx <= (bfs_x < 15) ? bfs_x + 4'd1 : 4'd16; ny <= bfs_y; end
                        3'd2: begin nx <= bfs_x; ny <= (bfs_y > 0) ? bfs_y - 4'd1 : 4'd16; end
                        3'd3: begin nx <= bfs_x; ny <= (bfs_y < 15) ? bfs_y + 4'd1 : 4'd16; end
                        default: begin nx <= 4'd16; ny <= 4'd16; end
                    endcase
                    
                    if (bfs_dir < 3'd4) begin
                        if (nx <= 4'd15 && ny <= 4'd15) begin
                            new_idx <= ny[3:0] * 8'd16 + nx[3:0];
                            // Check logic in same cycle or next? Let's check next for simplicity/robustness
                        end
                        bfs_dir <= bfs_dir + 3'd1;
                    end
                    
                    // Enqueue logic
                    if (bfs_dir < 3'd4 && nx <= 4'd15 && ny <= 4'd15 && !visited[ny[3:0] * 8'd16 + nx[3:0]] && grid_flat[ny[3:0] * 8'd16 + nx[3:0]]) begin
                        visited[ny[3:0] * 8'd16 + nx[3:0]] <= 1'b1;
                        bfs_queue[bfs_tail] <= ny[3:0] * 8'd16 + nx[3:0];
                        bfs_tail <= bfs_tail + 6'd1;
                    end
                end

                DONE_STATE: begin
                    result <= comp_count;
                    done <= 1'b1;
                end

                ERROR: begin
                    result <= 8'd255;
                    done <= 1'b1;
                end
            endcase

            // Override for immediate error if constraints failed during checks
            // (Handled by error_flag and transitioning to ERROR in VALIDATE)
            if (state == CHECK_ROWS && !row_valid) error_flag <= 1'b1;
            if (state == CHECK_ROWS && bit_idx == 4'd15 && !row_has_black) error_flag <= 1'b1;
            if (state == CHECK_COLS && !col_valid) error_flag <= 1'b1;
            if (state == CHECK_COLS && bit_idx == 4'd15 && !col_has_black) error_flag <= 1'b1;
            
            // If start goes high in IDLE, clear done
            if (state == IDLE && start) done <= 1'b0;
        end
    end

endmodule