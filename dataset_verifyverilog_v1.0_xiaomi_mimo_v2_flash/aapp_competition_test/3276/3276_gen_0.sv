module art_reproduction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] grid [0:7][0:7],
    output reg done,
    output reg result
);

parameter MAX_ITER = 64;
parameter GRID_SIZE = 8;
localparam [1:0] COLOR_W = 2'b00;
localparam [1:0] COLOR_R = 2'b01;
localparam [1:0] COLOR_G = 2'b10;
localparam [1:0] COLOR_B = 2'b11;

reg [1:0] board [0:7][0:7];
reg [5:0] iter_count;
reg [2:0] scan_x, scan_y;
reg [2:0] scan_internal_x, scan_internal_y;
reg scanning;
reg found_block;
reg [1:0] block_color;
reg all_white;
reg [2:0] temp_x, temp_y;

localparam [2:0] S_IDLE = 3'b000;
localparam [2:0] S_SCAN = 3'b001;
localparam [2:0] S_REMOVE = 3'b010;
localparam [2:0] S_CHECK = 3'b011;
localparam [2:0] S_DONE = 3'b100;
localparam [2:0] S_CHECK_CELL = 3'b101;
reg [2:0] state;

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        done <= 1'b0;
        result <= 1'b0;
        state <= S_IDLE;
        iter_count <= 6'b0;
        scan_x <= 3'b0;
        scan_y <= 3'b0;
        scan_internal_x <= 3'b0;
        scan_internal_y <= 3'b0;
        scanning <= 1'b0;
        found_block <= 1'b0;
        all_white <= 1'b1;
        for (i = 0; i < 8; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                board[i][j] <= COLOR_W;
            end
        end
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            board[i][j] <= grid[i][j];
                        end
                    end
                    iter_count <= 6'b0;
                    state <= S_SCAN;
                    scan_x <= 3'b0;
                    scan_y <= 3'b0;
                    found_block <= 1'b0;
                end
            end
            
            S_SCAN: begin
                if (scan_x <= 5 && scan_y <= 5) begin
                    block_color <= board[scan_x][scan_y];
                    scan_internal_x <= 3'b0;
                    scan_internal_y <= 3'b0;
                    found_block <= 1'b1;
                    state <= S_CHECK_CELL;
                end else begin
                    state <= S_CHECK;
                end
            end
            
            S_CHECK_CELL: begin
                temp_x <= scan_x + scan_internal_x;
                temp_y <= scan_y + scan_internal_y;
                if (board[scan_x][scan_y] != COLOR_W && 
                    board[scan_x + scan_internal_x][scan_y + scan_internal_y] != block_color) begin
                    found_block <= 1'b0;
                    state <= S_SCAN_NEXT;
                end else if (scan_internal_y == 2 && scan_internal_x == 2) begin
                    if (found_block) begin
                        state <= S_REMOVE;
                    end else begin
                        state <= S_SCAN_NEXT;
                    end
                end else begin
                    if (scan_internal_y == 2) begin
                        scan_internal_y <= 3'b0;
                        scan_internal_x <= scan_internal_x + 1;
                    end else begin
                        scan_internal_y <= scan_internal_y + 1;
                    end
                    state <= S_CHECK_CELL;
                end
            end
            
            S_SCAN_NEXT: begin
                if (scan_x == 5) begin
                    scan_x <= 3'b0;
                    if (scan_y == 5) begin
                        scan_y <= 3'b0;
                        state <= S_CHECK;
                    end else begin
                        scan_y <= scan_y + 1;
                        state <= S_SCAN;
                    end
                end else begin
                    scan_x <= scan_x + 1;
                    state <= S_SCAN;
                end
            end
            
            S_REMOVE: begin
                board[scan_x][scan_y] <= COLOR_W;
                board[scan_x][scan_y+1] <= COLOR_W;
                board[scan_x][scan_y+2] <= COLOR_W;
                board[scan_x+1][scan_y] <= COLOR_W;
                board[scan_x+1][scan_y+1] <= COLOR_W;
                board[scan_x+1][scan_y+2] <= COLOR_W;
                board[scan_x+2][scan_y] <= COLOR_W;
                board[scan_x+2][scan_y+1] <= COLOR_W;
                board[scan_x+2][scan_y+2] <= COLOR_W;
                
                iter_count <= iter_count + 1;
                state <= S_SCAN_NEXT;
            end
            
            S_CHECK: begin
                all_white <= 1'b1;
                scan_x <= 3'b0;
                scan_y <= 3'b0;
                state <= S_CHECK_CELL;
            end
            
            S_CHECK_CELL: begin
                if (board[scan_x][scan_y] != COLOR_W) begin
                    all_white <= 1'b0;
                end
                if (scan_y == 7) begin
                    if (scan_x == 7) begin
                        if (all_white) begin
                            result <= 1'b1;
                            state <= S_DONE;
                        end else if (iter_count >= MAX_ITER) begin
                            result <= 1'b0;
                            state <= S_DONE;
                        end else begin
                            scan_x <= 3'b0;
                            scan_y <= 3'b0;
                            state <= S_SCAN;
                        end
                    end else begin
                        scan_x <= scan_x + 1;
                        scan_y <= 3'b0;
                        state <= S_CHECK_CELL;
                    end
                end else begin
                    scan_y <= scan_y + 1;
                    state <= S_CHECK_CELL;
                end
            end
            
            S_DONE: begin
                done <= 1'b1;
                if (!start) begin
                    state <= S_IDLE;
                end
            end
            
            default: begin
                state <= S_IDLE;
            end
        endcase
    end
end

endmodule