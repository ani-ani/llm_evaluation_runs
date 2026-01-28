module monotonic_subgrid_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] r,
    input wire [1:0] c,
    input wire [7:0] grid_0_0,
    input wire [7:0] grid_0_1,
    input wire [7:0] grid_0_2,
    input wire [7:0] grid_1_0,
    input wire [7:0] grid_1_1,
    input wire [7:0] grid_1_2,
    input wire [7:0] grid_2_0,
    input wire [7:0] grid_2_1,
    input wire [7:0] grid_2_2,
    output reg [7:0] count,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE        = 4'd0;
    localparam [3:0] LOAD_GRID   = 4'd1;
    localparam [3:0] INIT_MASKS  = 4'd2;
    localparam [3:0] CHECK       = 4'd3;
    localparam [3:0] CHECK_ROWS  = 4'd4;
    localparam [3:0] CHECK_COLS  = 4'd5;
    localparam [3:0] CHECK_SEQ   = 4'd6;
    localparam [3:0] INC_VALID   = 4'd7;
    localparam [3:0] NEXT_COL    = 4'd8;
    localparam [3:0] NEXT_ROW    = 4'd9;
    localparam [3:0] DONE_STATE  = 4'd10;

    // Internal registers
    reg [3:0] state, next_state;
    reg [7:0] grid [0:2][0:2];
    reg [2:0] row_mask;
    reg [2:0] col_mask;
    reg [7:0] temp_count;
    reg [1:0] row_idx;
    reg [1:0] col_idx;
    reg [1:0] seq_idx;
    reg [1:0] valid_count;
    reg [2:0] row_valid;
    reg [2:0] col_valid;
    reg row_ok;
    reg col_ok;
    reg seq_ok;
    reg [7:0] val0, val1, val2;
    reg [1:0] max_rows;
    reg [1:0] max_cols;

    // Next state logic
    always @(*) begin
        case (state)
            IDLE:        next_state = start ? LOAD_GRID : IDLE;
            LOAD_GRID:   next_state = INIT_MASKS;
            INIT_MASKS:  next_state = CHECK;
            CHECK:       next_state = CHECK_ROWS;
            CHECK_ROWS:  next_state = CHECK_COLS;
            CHECK_COLS:  next_state = CHECK_SEQ;
            CHECK_SEQ:   next_state = INC_VALID;
            INC_VALID:   next_state = NEXT_COL;
            NEXT_COL:    next_state = (col_mask < max_cols) ? CHECK : NEXT_ROW;
            NEXT_ROW:    next_state = (row_mask < max_rows) ? CHECK : DONE_STATE;
            DONE_STATE:  next_state = IDLE;
            default:     next_state = IDLE;
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 8'd0;
            done <= 1'b0;
            temp_count <= 8'd0;
            row_mask <= 3'd0;
            col_mask <= 3'd0;
            row_idx <= 2'd0;
            col_idx <= 2'd0;
            seq_idx <= 2'd0;
            valid_count <= 2'd0;
            row_valid <= 3'd0;
            col_valid <= 3'd0;
            row_ok <= 1'b0;
            col_ok <= 1'b0;
            seq_ok <= 1'b0;
            val0 <= 8'd0;
            val1 <= 8'd0;
            val2 <= 8'd0;
            max_rows <= 2'd0;
            max_cols <= 2'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end
                
                LOAD_GRID: begin
                    // Load individual grid elements
                    grid[0][0] <= grid_0_0;
                    grid[0][1] <= grid_0_1;
                    grid[0][2] <= grid_0_2;
                    grid[1][0] <= grid_1_0;
                    grid[1][1] <= grid_1_1;
                    grid[1][2] <= grid_1_2;
                    grid[2][0] <= grid_2_0;
                    grid[2][1] <= grid_2_1;
                    grid[2][2] <= grid_2_2;
                    max_rows <= r;
                    max_cols <= c;
                end
                
                INIT_MASKS: begin
                    temp_count <= 8'd0;
                    row_mask <= 3'd1;
                    col_mask <= 3'd1;
                end
                
                CHECK: begin
                    valid_count <= 2'd0;
                    row_valid <= 3'd0;
                    col_valid <= 3'd0;
                    row_idx <= 2'd0;
                end
                
                CHECK_ROWS: begin
                    if (row_idx < max_rows) begin
                        if (row_mask[row_idx]) begin
                            row_valid[row_idx] <= 1'b1;
                        end
                        row_idx <= row_idx + 2'd1;
                    end else begin
                        row_ok <= (row_valid != 3'd0);
                    end
                end
                
                CHECK_COLS: begin
                    col_idx <= 2'd0;
                    col_ok <= 1'b0;
                end
                
                CHECK_SEQ: begin
                    if (col_idx < max_cols && !col_ok) begin
                        if (col_mask[col_idx]) begin
                            col_valid[col_idx] <= 1'b1;
                            col_ok <= 1'b1;
                        end else begin
                            col_idx <= col_idx + 2'd1;
                        end
                    end
                    seq_idx <= 2'd0;
                    val0 <= grid[row_idx][col_idx];
                    val1 <= grid[row_idx][col_idx + 2'd1];
                    val2 <= grid[row_idx][col_idx + 2'd2];
                end
                
                INC_VALID: begin
                    if (row_ok && col_ok) begin
                        seq_ok <= 1'b1;
                    end else begin
                        seq_ok <= 1'b0;
                    end
                    
                    if (seq_ok) begin
                        valid_count <= valid_count + 2'd1;
                    end
                end
                
                NEXT_COL: begin
                    if (valid_count == 2'd0) begin
                        // No valid subgrid found
                    end
                    if (row_mask < max_rows) begin
                        if (col_mask < max_cols) begin
                            col_mask <= col_mask + 3'd1;
                        end else begin
                            col_mask <= 3'd1;
                        end
                    end
                end
                
                NEXT_ROW: begin
                    if (row_mask < max_rows) begin
                        row_mask <= row_mask + 3'd1;
                        col_mask <= 3'd1;
                    end
                end
                
                DONE_STATE: begin
                    count <= temp_count;
                    done <= 1'b1;
                end
            endcase
            
            // Increment count after processing each valid subgrid
            if (state == INC_VALID && seq_ok) begin
                temp_count <= temp_count + 8'd1;
            end
        end
    end
endmodule