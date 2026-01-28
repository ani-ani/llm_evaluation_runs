module SquareKiller(
    input clk,
    input rst_n,
    input start,
    input [3:0] row0,
    input [3:0] row1,
    input [3:0] row2,
    input [3:0] row3,
    input [2:0] R,
    input [2:0] C,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] SIZE_LOOP = 3'd1;
    localparam [2:0] POS_LOOP  = 3'd2;
    localparam [2:0] CHECK     = 3'd3;
    localparam [2:0] FOUND     = 3'd4;
    localparam [2:0] NOT_FOUND = 3'd5;
    localparam [2:0] FINISH    = 3'd6;

    reg [2:0] state, next_state;
    reg [2:0] size, next_size;
    reg [2:0] pos_r, next_pos_r;
    reg [2:0] pos_c, next_pos_c;
    reg [3:0] result_reg, next_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper wires for matrix access
    reg [3:0] rows [0:3];
    always @(*) begin
        rows[0] = row0;
        rows[1] = row1;
        rows[2] = row2;
        rows[3] = row3;
    end

    // Combinational logic for checking if a submatrix is a killer
    reg is_killer;
    always @(*) begin
        is_killer = 1'b1;
        // Check all cells in the size x size submatrix starting at (pos_r, pos_c)
        if (size >= 3'd2 && size <= 3'd4) begin
            // Check each cell against its 180-degree rotated counterpart
            // Rotation: (i, j) <-> (size-1-i, size-1-j)
            // Only need to check half the cells (upper triangle)
            for (int i = 0; i < 3; i = i + 1) begin
                for (int j = 0; j < 3; j = j + 1) begin
                    // Check bounds based on size
                    if (i < size && j < size) begin
                        // Calculate indices
                        int row_idx1 = pos_r + i;
                        int col_idx1 = pos_c + j;
                        int row_idx2 = pos_r + (size - 1 - i);
                        int col_idx2 = pos_c + (size - 1 - j);
                        
                        // Check if within matrix bounds
                        if (row_idx1 < R && col_idx1 < C && row_idx2 < R && col_idx2 < C) begin
                            // Get bit values
                            bit bit1, bit2;
                            bit1 = rows[row_idx1][col_idx1];
                            bit2 = rows[row_idx2][col_idx2];
                            
                            // Check symmetry (must be equal)
                            if (bit1 != bit2) begin
                                is_killer = 1'b0;
                            end
                        end
                    end
                end
            end
        end else begin
            is_killer = 1'b0;
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            size <= 3'd0;
            pos_r <= 3'd0;
            pos_c <= 3'd0;
            result_reg <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            size <= next_size;
            pos_r <= next_pos_r;
            pos_c <= next_pos_c;
            result_reg <= next_result;
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result_reg <= 4'd0;
                end
                SIZE_LOOP: begin
                    // Initialize for new size
                    pos_r <= 3'd0;
                    pos_c <= 3'd0;
                end
                POS_LOOP: begin
                    // Move to next position
                    if (pos_c + size < C) begin
                        pos_c <= pos_c + 3'd1;
                    end else begin
                        pos_c <= 3'd0;
                        pos_r <= pos_r + 3'd1;
                    end
                end
                CHECK: begin
                    // Check if current position yields a killer
                end
                FOUND: begin
                    result_reg <= {1'b0, size}; // 2->2, 3->3, 4->4 (unsigned)
                    done <= 1'b1;
                end
                NOT_FOUND: begin
                    // Check next size
                    result_reg <= 4'b1111; // -1
                    done <= 1'b1;
                end
                FINISH: begin
                    done <= 1'b0;
                end
                default: begin
                    state <= IDLE;
                    size <= 3'd0;
                    pos_r <= 3'd0;
                    pos_c <= 3'd0;
                    result_reg <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        next_size = size;
        next_pos_r = pos_r;
        next_pos_c = pos_c;
        next_result = result_reg;
        
        case (state)
            IDLE: begin
                if (start) begin
                    // Determine max size to check (min(R, C))
                    if (R < C) begin
                        next_size = R;
                    end else begin
                        next_size = C;
                    end
                    
                    // Only check sizes 2, 3, 4
                    if (next_size >= 3'd2 && next_size <= 3'd4) begin
                        next_state = SIZE_LOOP;
                    end else begin
                        next_state = NOT_FOUND;
                    end
                end
            end
            
            SIZE_LOOP: begin
                // Start checking positions for this size
                next_pos_r = 3'd0;
                next_pos_c = 3'd0;
                next_state = POS_LOOP;
            end
            
            POS_LOOP: begin
                // Check if we have more positions to check
                if (pos_r + size <= R && pos_c + size <= C) begin
                    next_state = CHECK;
                end else begin
                    // No more positions for this size
                    if (size > 3'd2) begin
                        next_size = size - 3'd1;
                        if (next_size >= 3'd2) begin
                            next_state = SIZE_LOOP;
                        end else begin
                            next_state = NOT_FOUND;
                        end
                    end else begin
                        next_state = NOT_FOUND;
                    end
                end
            end
            
            CHECK: begin
                if (is_killer) begin
                    next_state = FOUND;
                end else begin
                    // Move to next position
                    if (pos_c + size < C) begin
                        next_pos_c = pos_c + 3'd1;
                    end else begin
                        next_pos_c = 3'd0;
                        if (pos_r + size < R) begin
                            next_pos_r = pos_r + 3'd1;
                        end else begin
                            // No more positions for this size
                            if (size > 3'd2) begin
                                next_size = size - 3'd1;
                                if (next_size >= 3'd2) begin
                                    next_state = SIZE_LOOP;
                                end else begin
                                    next_state = NOT_FOUND;
                                end
                            end else begin
                                next_state = NOT_FOUND;
                            end
                        end
                    end
                end
            end
            
            FOUND: begin
                next_state = FINISH;
            end
            
            NOT_FOUND: begin
                next_state = FINISH;
            end
            
            FINISH: begin
                next_state = IDLE;
                next_result = result_reg;
            end
            
            default: begin
                next_state = IDLE;
                next_size = 3'd0;
                next_pos_r = 3'd0;
                next_pos_c = 3'd0;
                next_result = 4'd0;
            end
        endcase
        
        // Safety timeout
        if (cycle_count >= MAX_CYCLES && state != IDLE && state != FINISH) begin
            next_state = NOT_FOUND;
        end
    end

    // Output assignment
    always @(*) begin
        result = result_reg;
    end

endmodule