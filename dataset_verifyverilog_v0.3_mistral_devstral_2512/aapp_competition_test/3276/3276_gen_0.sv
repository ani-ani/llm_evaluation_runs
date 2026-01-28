module art_reproduction (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [1:0] grid [0:7][0:7],
    output reg done,
    output reg result
);

    // Parameters
    localparam [5:0] MAX_ITER = 6'd64;
    localparam [2:0] COLOR_W = 2'b00;
    localparam [2:0] COLOR_R = 2'b01;
    localparam [2:0] COLOR_G = 2'b10;
    localparam [2:0] COLOR_B = 2'b11;

    // State machine states
    localparam [2:0] S_IDLE = 3'b000;
    localparam [2:0] S_SCAN = 3'b001;
    localparam [2:0] S_REMOVE = 3'b010;
    localparam [2:0] S_CHECK = 3'b011;
    localparam [2:0] S_DONE = 3'b100;

    // Internal state
    reg [1:0] board [0:7][0:7];
    reg [5:0] iter_count;
    reg [2:0] scan_x, scan_y;
    reg [2:0] state;
    reg all_white;
    reg found_block;
    reg [1:0] block_color;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset state
            done <= 1'b0;
            result <= 1'b0;
            state <= S_IDLE;
            iter_count <= 6'd0;
            scan_x <= 3'd0;
            scan_y <= 3'd0;
            all_white <= 1'b1;
            found_block <= 1'b0;
            // Clear board
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
                        // Copy input grid to internal buffer
                        for (i = 0; i < 8; i = i + 1) begin
                            for (j = 0; j < 8; j = j + 1) begin
                                board[i][j] <= grid[i][j];
                            end
                        end
                        iter_count <= 6'd0;
                        scan_x <= 3'd0;
                        scan_y <= 3'd0;
                        found_block <= 1'b0;
                        state <= S_SCAN;
                    end
                end
                
                S_SCAN: begin
                    // Scan for monochromatic 3x3 block
                    if (scan_x <= 5 && scan_y <= 5) begin
                        // Check current 3x3 block
                        block_color <= board[scan_x][scan_y];
                        if (board[scan_x][scan_y] != COLOR_W &&
                            board[scan_x][scan_y] == board[scan_x][scan_y+1] &&
                            board[scan_x][scan_y] == board[scan_x][scan_y+2] &&
                            board[scan_x][scan_y] == board[scan_x+1][scan_y] &&
                            board[scan_x][scan_y] == board[scan_x+1][scan_y+1] &&
                            board[scan_x][scan_y] == board[scan_x+1][scan_y+2] &&
                            board[scan_x][scan_y] == board[scan_x+2][scan_y] &&
                            board[scan_x][scan_y] == board[scan_x+2][scan_y+1] &&
                            board[scan_x][scan_y] == board[scan_x+2][scan_y+2]) begin
                            found_block <= 1'b1;
                            state <= S_REMOVE;
                        end else begin
                            // Move to next position
                            if (scan_x == 5) begin
                                scan_x <= 3'd0;
                                if (scan_y == 5) begin
                                    scan_y <= 3'd0;
                                    state <= S_CHECK;
                                end else begin
                                    scan_y <= scan_y + 1;
                                end
                            end else begin
                                scan_x <= scan_x + 1;
                            end
                        end
                    end else begin
                        state <= S_CHECK;
                    end
                end
                
                S_REMOVE: begin
                    // Remove the monochromatic block by setting to white
                    board[scan_x][scan_y] <= COLOR_W;
                    board[scan_x][scan_y+1] <= COLOR_W;
                    board[scan_x][scan_y+2] <= COLOR_W;
                    board[scan_x+1][scan_y] <= COLOR_W;
                    board[scan_x+1][scan_y+1] <= COLOR_W;
                    board[scan_x+1][scan_y+2] <= COLOR_W;
                    board[scan_x+2][scan_y] <= COLOR_W;
                    board[scan_x+2][scan_y+1] <= COLOR_W;
                    board[scan_x+2][scan_y+2] <= COLOR_W;
                    
                    found_block <= 1'b0;
                    iter_count <= iter_count + 1;
                    
                    // Move to next scan position
                    if (scan_x == 5) begin
                        scan_x <= 3'd0;
                        if (scan_y == 5) begin
                            scan_y <= 3'd0;
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
                
                S_CHECK: begin
                    // Check if all cells are white
                    all_white <= 1'b1;
                    for (i = 0; i < 8; i = i + 1) begin
                        for (j = 0; j < 8; j = j + 1) begin
                            if (board[i][j] != COLOR_W) begin
                                all_white <= 1'b0;
                            end
                        end
                    end
                    
                    // Check if we should continue or finish
                    if (all_white) begin
                        result <= 1'b1;
                        state <= S_DONE;
                    end else if (iter_count >= MAX_ITER) begin
                        result <= 1'b0;
                        state <= S_DONE;
                    end else begin
                        // Continue scanning from beginning
                        scan_x <= 3'd0;
                        scan_y <= 3'd0;
                        state <= S_SCAN;
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