module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);
    wire [255:0] next_q;
    
    always_ff @(posedge clk) begin
        if (load)
            q <= data;
        else
            q <= next_q;
    end
    
    always_comb begin
        for (int i = 0; i < 16; i++) begin
            for (int j = 0; j < 16; j++) begin
                int count = 0;
                for (int di = -1; di <= 1; di++) begin
                    for (int dj = -1; dj <= 1; dj++) begin
                        if (di != 0 || dj != 0) begin
                            int ni = (i + di + 16) % 16;
                            int nj = (j + dj + 16) % 16;
                            if (q[ni * 16 + nj]) count++;
                        end
                    end
                end
                next_q[i * 16 + j] = (count == 3) || (count == 2 && q[i * 16 + j]);
            end
        end
    end
endmodule