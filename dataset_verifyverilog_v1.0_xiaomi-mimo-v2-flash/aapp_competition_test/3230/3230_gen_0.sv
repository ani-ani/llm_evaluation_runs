module tram_explosions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] grid_data,
    output reg [7:0] explosions,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] current_idx;      // Index 0-63 for iterating cells
    reg [7:0] min_dist;
    reg [7:0] collision_counter;
    reg [7:0] temp_explosions;
    reg [2:0] L_row, L_col;     // Current L position
    reg [2:0] X_row, X_col;     // X position for comparison
    reg [7:0] dist;
    reg [7:0] row_diff, col_diff;
    
    // Helper signals
    wire [1:0] cell_type;
    wire [1:0] check_cell_type;
    
    // Extract cell type from grid_data
    assign cell_type = grid_data[(current_idx*2)+:2]; // Extract 2 bits per cell
    assign check_cell_type = grid_data[(x_idx*2)+:2]; // For X loop
    
    // X loop index register
    reg [7:0] x_idx;
    reg [7:0] x_idx_prev;
    reg processing_L;
    reg [7:0] internal_state; // 0: idle, 1: init, 2: loop_x, 3: check

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            explosions <= 8'd0;
            done <= 1'b0;
            temp_explosions <= 8'd0;
            current_idx <= 8'd0;
            x_idx <= 8'd0;
            min_dist <= 8'd255;
            collision_counter <= 8'd0;
            L_row <= 3'd0;
            L_col <= 3'd0;
            X_row <= 3'd0;
            X_col <= 3'd0;
            dist <= 8'd0;
            row_diff <= 8'd0;
            col_diff <= 8'd0;
            processing_L <= 1'b0;
            internal_state <= 8'd0;
            x_idx_prev <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        current_idx <= 8'd0;
                        temp_explosions <= 8'd0;
                        processing_L <= 1'b0;
                        internal_state <= 8'd0;
                    end
                end

                PROCESS: begin
                    // Processing Logic
                    if (current_idx < 8'd64) begin
                        if (!processing_L) begin
                            // Check if current cell is 'L' (value 2)
                            if (cell_type == 2'd2) begin
                                // Found L, start processing
                                processing_L <= 1'b1;
                                
                                // Calculate L Row/Col
                                // Current_idx is 0-63. Row = idx / 8, Col = idx % 8
                                L_row <= current_idx[7:3]; // Divide by 8
                                L_col <= current_idx[2:0]; // Modulo 8
                                
                                // Init min_dist and counter
                                min_dist <= 8'd255;
                                collision_counter <= 8'd0;
                                x_idx <= 8'd0;
                                x_idx_prev <= 8'd0;
                                internal_state <= 8'd1; // Init state
                            end else begin
                                // Not L, move to next index
                                current_idx <= current_idx + 8'd1;
                            end
                        end else begin
                            // We are processing an L (internal loop over X)
                            case (internal_state)
                                8'd1: begin // Init X loop
                                    x_idx <= 8'd0;
                                    x_idx_prev <= 8'd0;
                                    internal_state <= 8'd2;
                                end
                                8'd2: begin // Loop over X
                                    if (x_idx < 8'd64) begin
                                        // Check if cell is 'X' (value 1)
                                        if (check_cell_type == 2'd1) begin
                                            // Calculate X Row/Col
                                            X_row <= x_idx[7:3];
                                            X_col <= x_idx[2:0];
                                            
                                            // Go to calculation state
                                            internal_state <= 8'd3;
                                        end else begin
                                            // Not X, check next
                                            x_idx <= x_idx + 8'd1;
                                        end
                                    end else begin
                                        // Finished looping Xs
                                        // Check collision
                                        if (collision_counter > 8'd1) begin
                                            temp_explosions <= temp_explosions + 8'd1;
                                        end
                                        // Done with this L
                                        processing_L <= 1'b0;
                                        current_idx <= current_idx + 8'd1;
                                        internal_state <= 8'd0;
                                    end
                                end
                                8'd3: begin // Calculate distance and update min
                                    // Calculate (L_row - X_row)^2 + (L_col - X_col)^2
                                    // Since values are small (0-7), differences are 0-7. Squares 0-49. Sum 0-98.
                                    
                                    // Use signed arithmetic for subtraction
                                    if (L_row >= X_row) begin
                                        row_diff <= {5'd0, L_row - X_row};
                                    end else begin
                                        row_diff <= {5'd0, X_row - L_row};
                                    end
                                    
                                    if (L_col >= X_col) begin
                                        col_diff <= {5'd0, L_col - X_col};
                                    end else begin
                                        col_diff <= {5'd0, X_col - L_col};
                                    end
                                    
                                    // Need to wait 1 cycle for subtraction result if async? No, it's combinational usually.
                                    // But let's ensure stable logic.
                                    // Actually, in synthesis, arithmetic is usually async.
                                    // Let's do it in the same cycle if possible, or add a state.
                                    // To be safe and explicit: calculate in next state.
                                    internal_state <= 8'd4;
                                end
                                8'd4: begin // Square and Add
                                    // row_diff^2 + col_diff^2
                                    dist <= (row_diff * row_diff) + (col_diff * col_diff);
                                    internal_state <= 8'd5;
                                end
                                8'd5: begin // Compare
                                    if (dist < min_dist) begin
                                        min_dist <= dist;
                                        collision_counter <= 8'd1;
                                    end else if (dist == min_dist) begin
                                        collision_counter <= collision_counter + 8'd1;
                                    end
                                    // Next X
                                    x_idx <= x_idx + 8'd1;
                                    internal_state <= 8'd2;
                                end
                                default: internal_state <= 8'd0;
                            endcase
                        end
                    end else begin
                        // Finished all cells
                        state <= FINISH;
                        explosions <= temp_explosions;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule