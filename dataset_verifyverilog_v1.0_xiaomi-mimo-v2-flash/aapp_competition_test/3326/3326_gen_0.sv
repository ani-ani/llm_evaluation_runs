module monotonic_subgrids(
    input clk,
    input rst_n,
    input start,
    output reg [7:0] result,
    output reg done
);

    // Hardcoded 3x3 grid (4-bit values, row-major)
    localparam [3:0] GRID [0:8] = '{
        4'd1, 4'd2, 4'd5,  // Row 0
        4'd7, 4'd6, 4'd4,  // Row 1
        4'd9, 4'd8, 4'd3   // Row 2
    };

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] INIT        = 3'd1;
    localparam [2:0] CHECK_SUBGRID = 3'd2;
    localparam [2:0] COUNT       = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [5:0] row_mask;      // 3 bits for rows (0-2), 0 means not selected
    reg [5:0] col_mask;      // 3 bits for cols (0-2), 0 means not selected
    reg [7:0] valid_count;
    reg [2:0] subgrid_size;  // Number of selected rows/cols
    reg [3:0] temp_grid [0:8]; // Temporary storage for subgrid values
    reg [3:0] row_vals [0:2];  // Values for current row check
    reg [3:0] col_vals [0:2];  // Values for current column check
    reg [2:0] row_idx;
    reg [2:0] col_idx;
    reg [2:0] idx;
    reg valid_subgrid;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd5;

    // Combinational logic for monotonicity check
    wire row_mono_inc;
    wire row_mono_dec;
    wire col_mono_inc;
    wire col_mono_dec;
    wire row_valid;
    wire col_valid;

    // Row monotonicity check (strictly increasing or decreasing)
    // For 2 elements: always monotonic
    // For 3 elements: check both conditions
    assign row_mono_inc = (subgrid_size == 3'd1) || 
                          (subgrid_size == 3'd2) || 
                          (subgrid_size == 3'd3 && row_vals[0] < row_vals[1] && row_vals[1] < row_vals[2]);
    assign row_mono_dec = (subgrid_size == 3'd1) || 
                          (subgrid_size == 3'd2) || 
                          (subgrid_size == 3'd3 && row_vals[0] > row_vals[1] && row_vals[1] > row_vals[2]);
    assign row_valid = row_mono_inc || row_mono_dec;

    // Column monotonicity check
    assign col_mono_inc = (subgrid_size == 3'd1) || 
                          (subgrid_size == 3'd2) || 
                          (subgrid_size == 3'd3 && col_vals[0] < col_vals[1] && col_vals[1] < col_vals[2]);
    assign col_mono_dec = (subgrid_size == 3'd1) || 
                          (subgrid_size == 3'd2) || 
                          (subgrid_size == 3'd3 && col_vals[0] > col_vals[1] && col_vals[1] > col_vals[2]);
    assign col_valid = col_mono_inc || col_mono_dec;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = INIT;
                else
                    next_state = IDLE;
            end
            INIT: begin
                next_state = CHECK_SUBGRID;
            end
            CHECK_SUBGRID: begin
                if (row_idx < subgrid_size && col_idx < subgrid_size)
                    next_state = CHECK_SUBGRID;
                else if (row_idx >= subgrid_size)
                    next_state = COUNT;
                else
                    next_state = CHECK_SUBGRID;
            end
            COUNT: begin
                if (row_mask == 3'd7 && col_mask == 3'd7) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK_SUBGRID;
                end
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            row_mask <= 3'd0;
            col_mask <= 3'd0;
            valid_count <= 8'd0;
            subgrid_size <= 3'd0;
            row_idx <= 3'd0;
            col_idx <= 3'd0;
            idx <= 3'd0;
            valid_subgrid <= 1'b0;
            cycle_count <= 3'd0;
            // Initialize temp arrays
            for (int i = 0; i < 9; i = i + 1) begin
                temp_grid[i] <= 4'd0;
            end
            for (int i = 0; i < 3; i = i + 1) begin
                row_vals[i] <= 4'd0;
                col_vals[i] <= 4'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        valid_count <= 8'd0;
                    end
                end

                INIT: begin
                    // Initialize iteration variables
                    row_mask <= 3'd1;  // Start with row 0 only
                    col_mask <= 3'd1;  // Start with col 0 only
                    row_idx <= 3'd0;
                    col_idx <= 3'd0;
                    subgrid_size <= 3'd0;
                    cycle_count <= cycle_count + 3'd1;
                    // Calculate subgrid size for current masks
                    // Count bits in row_mask and col_mask
                    // Row mask bits
                    subgrid_size <= (row_mask[0] ? 3'd1 : 3'd0) + 
                                   (row_mask[1] ? 3'd1 : 3'd0) + 
                                   (row_mask[2] ? 3'd1 : 3'd0);
                    // Extract subgrid values
                    idx <= 3'd0;
                    // Extract values for current row/col masks
                    // This will be done in CHECK_SUBGRID state
                end

                CHECK_SUBGRID: begin
                    // Check monotonicity for current subgrid
                    if (row_idx < subgrid_size && col_idx < subgrid_size) begin
                        // Build row_vals for current row_idx
                        if (row_idx == 3'd0) begin
                            row_vals[0] <= GRID[col_idx * 3'd3 + 3'd0];
                            row_vals[1] <= GRID[col_idx * 3'd3 + 3'd1];
                            row_vals[2] <= GRID[col_idx * 3'd3 + 3'd2];
                        end else if (row_idx == 3'd1) begin
                            row_vals[0] <= GRID[col_idx * 3'd3 + 3'd3];
                            row_vals[1] <= GRID[col_idx * 3'd3 + 3'd4];
                            row_vals[2] <= GRID[col_idx * 3'd3 + 3'd5];
                        end else begin
                            row_vals[0] <= GRID[col_idx * 3'd3 + 3'd6];
                            row_vals[1] <= GRID[col_idx * 3'd3 + 3'd7];
                            row_vals[2] <= GRID[col_idx * 3'd3 + 3'd8];
                        end
                        
                        // Build col_vals for current col_idx
                        if (col_idx == 3'd0) begin
                            col_vals[0] <= GRID[row_idx * 3'd3 + 3'd0];
                            col_vals[1] <= GRID[row_idx * 3'd3 + 3'd3];
                            col_vals[2] <= GRID[row_idx * 3'd3 + 3'd6];
                        end else if (col_idx == 3'd1) begin
                            col_vals[0] <= GRID[row_idx * 3'd3 + 3'd1];
                            col_vals[1] <= GRID[row_idx * 3'd3 + 3'd4];
                            col_vals[2] <= GRID[row_idx * 3'd3 + 3'd7];
                        end else begin
                            col_vals[0] <= GRID[row_idx * 3'd3 + 3'd2];
                            col_vals[1] <= GRID[row_idx * 3'd3 + 3'd5];
                            col_vals[2] <= GRID[row_idx * 3'd3 + 3'd8];
                        end
                        
                        // Check if current row/col is monotonic
                        if (row_valid && col_valid) begin
                            valid_subgrid <= 1'b1;
                        end else begin
                            valid_subgrid <= 1'b0;
                        end
                        
                        // Move to next column
                        if (col_idx < subgrid_size - 3'd1) begin
                            col_idx <= col_idx + 3'd1;
                        end else begin
                            col_idx <= 3'd0;
                            if (row_idx < subgrid_size - 3'd1) begin
                                row_idx <= row_idx + 3'd1;
                            end
                        end
                    end
                end

                COUNT: begin
                    if (valid_subgrid) begin
                        valid_count <= valid_count + 8'd1;
                    end
                    
                    // Move to next column mask
                    if (col_mask < 3'd7) begin
                        col_mask <= col_mask + 3'd1;
                        row_idx <= 3'd0;
                        col_idx <= 3'd0;
                        valid_subgrid <= 1'b0;
                    end else begin
                        // Move to next row mask
                        if (row_mask < 3'd7) begin
                            row_mask <= row_mask + 3'd1;
                            col_mask <= 3'd1;
                            row_idx <= 3'd0;
                            col_idx <= 3'd0;
                            valid_subgrid <= 1'b0;
                        end
                    end
                    
                    // Update subgrid size for next iteration
                    if (row_mask < 3'd7 || col_mask < 3'd7) begin
                        subgrid_size <= (row_mask[0] ? 3'd1 : 3'd0) + 
                                       (row_mask[1] ? 3'd1 : 3'd0) + 
                                       (row_mask[2] ? 3'd1 : 3'd0);
                    end
                end

                FINISH: begin
                    result <= valid_count;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule