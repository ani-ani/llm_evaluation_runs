module sliding_blocks_solver(
    input clk,
    input rst_n,
    input start,
    input [63:0] target_matrix,
    input [5:0] initial_r,
    input [5:0] initial_c,
    output reg [7:0] move_count,
    output reg [31:0] move_data,
    output reg move_valid,
    output reg solve_done,
    output reg possible
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam POP_QUEUE = 3'b001;
    localparam CHECK_NEIGHBORS = 3'b010;
    localparam OUTPUT_MOVE = 3'b011;
    localparam VERIFY_COMPLETE = 3'b100;
    localparam DONE = 3'b101;

    // Direction Encoding
    localparam LEFT = 2'b00;
    localparam RIGHT = 2'b01;
    localparam UP = 2'b10;
    localparam DOWN = 2'b11;

    // Registers
    reg [2:0] state, next_state;
    reg [63:0] target_reg;
    reg [63:0] visited_reg; // Added blocks
    reg [63:0] scheduled_reg; // In queue or processed
    reg [7:0] remaining_count;

    // FIFO
    reg [11:0] fifo_mem [0:63];
    reg [5:0] fifo_wr_ptr;
    reg [5:0] fifo_rd_ptr;
    reg [5:0] fifo_count;

    // Scan Registers
    reg scan_active;
    reg [5:0] scan_r_reg;
    reg [5:0] scan_c_reg;
    reg [1:0] scan_dir_reg;
    reg [1:0] dir_iter; // 0..3

    // Current Block
    reg [5:0] curr_r;
    reg [5:0] curr_c;

    // Candidate
    reg [5:0] cand_r;
    reg [5:0] cand_c;
    reg [1:0] cand_dir;

    // Helper for total ones count
    reg [7:0] total_ones;
    integer i;

    // Combinational Logic to count total target blocks
    always @(*) begin
        total_ones = 0;
        for (i = 0; i < 64; i = i + 1) begin
            total_ones = total_ones + target_matrix[i];
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            move_count <= 8'd0;
            move_valid <= 1'b0;
            solve_done <= 1'b0;
            possible <= 1'b0;
            visited_reg <= 64'd0;
            scheduled_reg <= 64'd0;
            fifo_wr_ptr <= 6'd0;
            fifo_rd_ptr <= 6'd0;
            fifo_count <= 6'd0;
            remaining_count <= 6'd0;
            target_reg <= 64'd0;
            dir_iter <= 2'b00;
            scan_active <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    move_valid <= 1'b0;
                    solve_done <= 1'b0;
                    possible <= 1'b0;
                    if (start) begin
                        target_reg <= target_matrix;

                        // Enqueue Start Block
                        fifo_mem[0] <= {initial_r, initial_c};
                        fifo_wr_ptr <= 6'd1;
                        fifo_rd_ptr <= 6'd0;
                        fifo_count <= 6'd1;

                        // Reset Visited/Scheduled
                        visited_reg <= 64'd0;
                        scheduled_reg <= 64'd0;

                        // Check if start is in target to set remaining count
                        if (target_matrix[(initial_r-1)*8 + (initial_c-1)]) begin
                            // Start is a target block. It counts as 1.
                            // remaining = total - 1.
                            remaining_count <= (total_ones > 0) ? (total_ones - 8'd1) : 8'd0;
                        end else begin
                            remaining_count <= total_ones;
                        end

                        state <= POP_QUEUE;
                    end
                end

                POP_QUEUE: begin
                    move_valid <= 1'b0;
                    if (fifo_count == 6'd0) begin
                        // Queue empty, verify completion
                        state <= VERIFY_COMPLETE;
                    end else begin
                        // Pop
                        {curr_r, curr_c} <= fifo_mem[fifo_rd_ptr];
                        fifo_rd_ptr <= fifo_rd_ptr + 6'd1;
                        fifo_count <= fifo_count - 6'd1;

                        // Reset neighbor iterator
                        dir_iter <= 2'b00;
                        scan_active <= 1'b0;
                        state <= CHECK_NEIGHBORS;
                    end
                end

                CHECK_NEIGHBORS: begin
                    // Logic to scan directions 0,1,2,3 (Left, Right, Up, Down)

                    if (scan_active) begin
                        // --- Process current scan cell ---
                        // Check bounds (check if we went out while advancing, or initial bounds)
                        if (scan_r_reg < 6'd1 || scan_r_reg > 6'd8 || scan_c_reg < 6'd1 || scan_c_reg > 6'd8) begin
                            // Out of bounds -> End of scan for this direction
                            scan_active <= 1'b0;
                            if (dir_iter < 2'b11) begin
                                dir_iter <= dir_iter + 2'b1;
                            end else begin
                                // All directions done
                                state <= POP_QUEUE;
                            end
                        end else begin
                            // In bounds, check content
                            reg [5:0] idx = (scan_r_reg - 6'd1) * 8 + (scan_c_reg - 6'd1);
                            reg is_target = target_reg[idx];
                            reg is_visited = visited_reg[idx];

                            if (is_target && !is_visited) begin
                                // Found candidate target. Check Behind.
                                // Behind cell is opposite to scan direction.
                                reg [5:0] behind_r = scan_r_reg;
                                reg [5:0] behind_c = scan_c_reg;
                                reg behind_ok = 1'b1;

                                case (scan_dir_reg)
                                    2'b00: behind_c = scan_c_reg + 6'd1; // Left target, Behind is Right
                                    2'b01: behind_c = scan_c_reg - 6'd1; // Right target, Behind is Left
                                    2'b10: behind_r = scan_r_reg + 6'd1; // Up target, Behind is Down
                                    2'b11: behind_r = scan_r_reg - 6'd1; // Down target, Behind is Up
                                endcase

                                // Check Behind
                                if (behind_r < 6'd1 || behind_r > 6'd8 || behind_c < 6'd1 || behind_c > 6'd8) begin
                                    behind_ok = 1'b0; // Boundary blocks the slide
                                end else begin
                                    reg [5:0] b_idx = (behind_r - 6'd1) * 8 + (behind_c - 6'd1);
                                    if (target_reg[b_idx]) behind_ok = 1'b0; // "not in target"
                                end

                                if (behind_ok) begin
                                    // Valid Candidate
                                    cand_r <= scan_r_reg;
                                    cand_c <= scan_c_reg;
                                    // Map scan_dir to direction code
                                    case (scan_dir_reg)
                                        2'b00: cand_dir <= LEFT;
                                        2'b01: cand_dir <= RIGHT;
                                        2'b10: cand_dir <= UP;
                                        2'b11: cand_dir <= DOWN;
                                    endcase

                                    // Mark Visited/Scheduled
                                    visited_reg[idx] <= 1'b1;
                                    scheduled_reg[idx] <= 1'b1;

                                    // Enqueue
                                    fifo_mem[fifo_wr_ptr] <= {scan_r_reg, scan_c_reg};
                                    fifo_wr_ptr <= fifo_wr_ptr + 6'd1;
                                    fifo_count <= fifo_count + 6'd1;

                                    // Move to Output
                                    scan_active <= 1'b0;
                                    state <= OUTPUT_MOVE;
                                end else begin
                                    // Candidate blocked behind. Stop scan this dir.
                                    scan_active <= 1'b0;
                                    if (dir_iter < 2'b11) begin
                                        dir_iter <= dir_iter + 2'b1;
                                    end else begin
                                        state <= POP_QUEUE;
                                    end
                                end
                            end else if (is_visited) begin
                                // Hit an added block. Stop scan.
                                scan_active <= 1'b0;
                                if (dir_iter < 2'b11) begin
                                    dir_iter <= dir_iter + 2'b1;
                                end else begin
                                    state <= POP_QUEUE;
                                end
                            end else begin
                                // Empty cell. Advance scan.
                                case (scan_dir_reg)
                                    2'b00: scan_c_reg <= scan_c_reg - 6'd1;
                                    2'b01: scan_c_reg <= scan_c_reg + 6'd1;
                                    2'b10: scan_r_reg <= scan_r_reg - 6'd1;
                                    2'b11: scan_r_reg <= scan_r_reg + 6'd1;
                                endcase
                                // Stay in state, next cycle will process advanced cell
                            end
                        end
                    end else begin
                        // --- Start new direction scan ---
                        if (dir_iter < 2'b11) begin
                            // Valid direction index (0, 1, 2). Wait, 2'b11 is 3. So < 3 covers 0,1,2.
                            // When dir_iter is 3, we enter else and finish.

                            scan_dir_reg <= dir_iter;
                            case (dir_iter)
                                2'b00: begin // Left
                                    if (curr_c > 6'd1) begin
                                        scan_r_reg <= curr_r;
                                        scan_c_reg <= curr_c - 6'd1;
                                        scan_active <= 1'b1;
                                    end else begin
                                        dir_iter <= dir_iter + 2'b1;
                                    end
                                end
                                2'b01: begin // Right
                                    if (curr_c < 6'd8) begin
                                        scan_r_reg <= curr_r;
                                        scan_c_reg <= curr_c + 6'd1;
                                        scan_active <= 1'b1;
                                    end else begin
                                        dir_iter <= dir_iter + 2'b1;
                                    end
                                end
                                2'b10: begin // Up (Row Dec)
                                    if (curr_r > 6'd1) begin
                                        scan_r_reg <= curr_r - 6'd1;
                                        scan_c_reg <= curr_c;
                                        scan_active <= 1'b1;
                                    end else begin
                                        dir_iter <= dir_iter + 2'b1;
                                    end
                                end
                                2'b11: begin // Down (Row Inc) - This block is actually covered by the outer if condition, but included for completeness if loop logic changes
                                    // Note: 2'b11 is 3. Outer if is < 2'b11 ( < 3). So this case 3 is NOT reached here.
                                    // We need to handle 3 separately if we want to process it.
                                    // Let's adjust the outer if.
                                end
                            endcase
                            // If scan_active set, stay. If not (boundary), loop continues (dir_iter already incremented in case)
                        end else if (dir_iter == 2'b11) begin
                            // Handle Direction 3 (Down)
                            scan_dir_reg <= 2'b11;
                            if (curr_r < 6'd8) begin
                                scan_r_reg <= curr_r + 6'd1;
                                scan_c_reg <= curr_c;
                                scan_active <= 1'b1;
                            end else begin
                                // Done with dir 3, go pop
                                state <= POP_QUEUE;
                            end
                        end else begin
                            // Logic safety: dir_iter > 3
                            dir_iter <= 2'b00;
                            state <= POP_QUEUE;
                        end

                        // If we just started scan_active, we stay. If we skipped (boundary), we loop back here (no state change)
                        // to check next dir_iter? No, we updated dir_iter in the case block.
                        // We need to loop back to start of state to process the new dir_iter.
                        // Since this is a combinational-like flow in sequential logic, we stay in state.
                    end

                    // Fix for loop continuation:
                    // If we are in this state and scan_active is low, and we just incremented dir_iter,
                    // we need to process the new dir_iter immediately (or next cycle).
                    // The code above handles it because we don't leave the state.
                    // However, if dir_iter was updated in the case block (boundary skip),
                    // the code flow finished the `else` block. We didn't re-evaluate the new dir_iter.
                    // We need to ensure that if we skipped a direction, we don't wait a cycle.
                    // We can use `disable` or loops, but Verilog doesn't support that in always block easily.
                    // We'll rely on the fact that if `scan_active` is not set, and we are in state, 
                    // we loop back to the start of the state body next cycle.
                end

                OUTPUT_MOVE: begin
                    move_data <= {20'b0, cand_dir, cand_r, cand_c};
                    move_count <= move_count + 8'd1;
                    move_valid <= 1'b1;
                    if (remaining_count > 0) remaining_count <= remaining_count - 8'd1;

                    // Resume scanning
                    state <= CHECK_NEIGHBORS;
                end

                VERIFY_COMPLETE: begin
                    // Determine possibility
                    // If remaining_count is 0, all targets added.
                    if (remaining_count == 8'd0) possible <= 1'b1;
                    else possible <= 1'b0;

                    solve_done <= 1'b1;
                    state <= DONE;
                end

                DONE: begin
                    // Wait
                    if (start) state <= IDLE; // Immediate restart if needed
                    else move_valid <= 1'b0; // Pulse low
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
