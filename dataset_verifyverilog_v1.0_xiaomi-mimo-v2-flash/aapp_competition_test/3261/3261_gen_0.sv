module hedgehog_grey(
    input clk,
    input rst_n,
    input start,
    input [3:0] row_limit,
    input [3:0] col_limit,
    input [15:0] k,
    output reg [15:0] result,
    output reg done
);

// State declarations
localparam [1:0] IDLE     = 2'd0;
localparam [1:0] PROCESS  = 2'd1;
localparam [1:0] FINISH   = 2'd2;

reg [1:0] state;
reg [15:0] step_cnt;
reg [3:0] r;
reg [3:0] c;
reg dir;  // 0 = left->right, 1 = right->left

wire [3:0] max_row;
wire [3:0] max_col;

// Calculate limits (grid is 0 to limit-1)
assign max_row = (row_limit == 4'd0) ? 4'd0 : row_limit - 4'd1;
assign max_col = (col_limit == 4'd0) ? 4'd0 : col_limit - 4'd1;

// Combinational logic for next coordinates
reg [3:0] next_r;
reg [3:0] next_c;
reg next_dir;

always @(*) begin
    // Default: stay at current position
    next_r = r;
    next_c = c;
    next_dir = dir;
    
    // Check if we can move horizontally
    if (!dir) begin  // Moving left->right
        if (c < max_col) begin
            next_c = c + 4'd1;
        end else begin
            // Hit right edge, need to move down
            if (r < max_row) begin
                next_r = r + 4'd1;
                next_c = c;  // Stay in place for now
                next_dir = 1'b1;  // Switch to right->left
            end
        end
    end else begin  // Moving right->left
        if (c > 4'd0) begin
            next_c = c - 4'd1;
        end else begin
            // Hit left edge, need to move down
            if (r < max_row) begin
                next_r = r + 4'd1;
                next_c = c;  // Stay in place for now
                next_dir = 1'b0;  // Switch to left->right
            end
        end
    end
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        result <= 16'd0;
        done <= 1'b0;
        step_cnt <= 16'd0;
        r <= 4'd0;
        c <= 4'd0;
        dir <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                step_cnt <= 16'd0;
                r <= 4'd0;
                c <= 4'd0;
                dir <= 1'b0;
                result <= 16'd0;
                if (start) begin
                    if (k == 16'd0) begin
                        state <= FINISH;
                        done <= 1'b1;
                    end else begin
                        state <= PROCESS;
                        // Check initial cell (0,0)
                        if ((4'd0 & 4'd0) == 4'd0) begin
                            result <= 16'd1;
                        end
                    end
                end
            end
            
            PROCESS: begin
                // Check if reached step limit
                if (step_cnt >= (k - 16'd1)) begin
                    state <= FINISH;
                    done <= 1'b1;
                end else begin
                    // Move to next cell
                    r <= next_r;
                    c <= next_c;
                    dir <= next_dir;
                    step_cnt <= step_cnt + 16'd1;
                    
                    // Check if next cell is grey (after moving)
                    if (next_r <= max_row && next_c <= max_col) begin
                        if ((next_r & next_c) == 4'd0) begin
                            result <= result + 16'd1;
                        end
                    end
                end
            end
            
            FINISH: begin
                done <= 1'b0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule