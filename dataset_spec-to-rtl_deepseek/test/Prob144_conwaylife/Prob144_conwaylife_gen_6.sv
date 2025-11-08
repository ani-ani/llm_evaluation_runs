module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);
    reg [255:0] new_q;
    always @(posedge clk) begin
        if (load) begin
            q <= data;
        end else begin
            for (int i = 0; i < 16; i++) begin
                for (int j = 0; j < 16; j++) begin
                    int count = 0;
                    for (int di = -1; di <= 1; di++) begin
                        for (int dj = -1; dj <= 1; dj++) begin
                            if (di != 0 || dj != 0) begin
                                int ni = (i + di + 16) % 16;
                                int nj = (j + dj + 16) % 16;
                                int index = ni * 16 + nj;
                                count += q[index];
                            end
                        end
                    end
                    int newval;
                    if (count < 2) newval = 0;
                    else if (count == 2) newval = q[i*16 + j];
                    else if (count == 3) newval = 1;
                    else newval = 0;
                    new_q[i*16 + j] = newval;
                end
            end
            q <= new_q;
        end
    end
endmodule