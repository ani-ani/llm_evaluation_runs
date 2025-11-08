module TopModule (
    input        clk,
    input        load,
    input [255:0] data,
    output [255:0] q
);
    reg [255:0] q_reg;

    function integer count_neighbors(integer r, integer c, reg [255:0] grid);
        integer cnt = 0;
        integer dr, dc, nr, nc;
        for (dr = -1; dr <= 1; dr = dr + 1) begin
            for (dc = -1; dc <= 1; dc = dc + 1) begin
                if (dr != 0 || dc != 0) begin
                    nr = (r + dr + 16) % 16;
                    nc = (c + dc + 16) % 16;
                    if (grid[nr*16 + nc]) cnt = cnt + 1;
                end
            end
        end
        return cnt;
    endfunction

    always @(posedge clk) begin
        reg [255:0] next_grid;
        if (load) begin
            q_reg <= data;
        end else begin
            integer row, col, cnt;
            for (row = 0; row < 16; row = row + 1) begin
                for (col = 0; col < 16; col = col + 1) begin
                    cnt = count_neighbors(row, col, q_reg);
                    if (cnt <= 1) next_grid[row*16 + col] = 1'b0;
                    else if (cnt == 2) next_grid[row*16 + col] = q_reg[row*16 + col];
                    else if (cnt == 3) next_grid[row*16 + col] = 1'b1;
                    else next_grid[row*16 + col] = 1'b0;
                end
            end
            q_reg <= next_grid;
        end
    end

    assign q = q_reg;
endmodule