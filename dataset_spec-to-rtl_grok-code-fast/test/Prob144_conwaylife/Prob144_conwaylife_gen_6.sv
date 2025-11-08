module TopModule (
    input clk,
    input load,
    input [255:0] data,
    output [255:0] q
);

    reg [255:0] q_reg;
    reg [255:0] next_q;
    assign q = q_reg;
    
    function automatic int count_neighbors(input reg [255:0] state, input int row, input int col);
        int count = 0;
        int di, dj;
        for (int x = -1; x <= 1; x++) begin
            for (int y = -1; y <= 1; y++) begin
                if (x != 0 || y != 0) begin
                    di = (row + x + 16) % 16;
                    dj = (col + y + 16) % 16;
                    if (state[di*16 + dj]) count++;
                end
            end
        end
        return count;
    endfunction
    
    always_comb begin
        next_q = q_reg;
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                int neighbors = count_neighbors(q_reg, i, j);
                logic current = q_reg[i*16 + j];
                logic new_state;
                if (neighbors == 3) new_state = 1;
                else if (neighbors == 2) new_state = current;
                else new_state = 0;
                next_q[i*16 + j] = new_state;
            end
        end
    end
    
    always_ff @(posedge clk) begin
        if (load) q_reg <= data;
        else q_reg <= next_q;
    end

endmodule