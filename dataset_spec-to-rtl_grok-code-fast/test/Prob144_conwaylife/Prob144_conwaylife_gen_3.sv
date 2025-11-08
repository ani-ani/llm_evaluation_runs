module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output [255:0] q
);
    reg [255:0] q_reg;
    assign q = q_reg;

    always @(posedge clk) begin
        if (load) begin
            q_reg <= data;
        end else begin
            for (int i = 0; i < 16; i++) begin
                for (int j = 0; j < 16; j++) begin
                    int count = 0;
                    for (int di = -1; di <= 1; di++) begin
                        for (int dj = -1; dj <= 1; dj++) begin
                            if (di == 0 && dj == 0) continue;
                            int ni = (i + di + 16) % 16;
                            int nj = (j + dj + 16) % 16;
                            count += q_reg[ni * 16 + nj];
                        end
                    end
                    int current = q_reg[i * 16 + j];
                    int new_state;
                    if (count < 2 || count > 3) begin
                        new_state = 0;
                    end else if (count == 3) begin
                        new_state = 1;
                    end else begin
                        new_state = current;
                    end
                    q_reg[i * 16 + j] <= new_state;
                end
            end
        end
    end
endmodule