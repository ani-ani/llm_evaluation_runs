module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);
    reg [255:0] next_q;
    
    always @(posedge clk) begin
        if(load) q <= data;
        else q <= next_q;
    end
    
    always @(*) begin
        reg [3:0] sum;
        for(int r=0; r<16; r++) begin
            for(int c=0; c<16; c++) begin
                sum = 0;
                for(int dr=-1; dr<=1; dr++) begin
                    for(int dc=-1; dc<=1; dc++) begin
                        if(!(dr==0 && dc==0)) begin
                            int nr = (r + dr + 16) % 16;
                            int nc = (c + dc + 16) % 16;
                            sum += q[nr*16 + nc];
                        end
                    end
                end
                // rules
                if(sum == 2) next_q[r*16 + c] = q[r*16 + c];
                else if(sum == 3) next_q[r*16 + c] = 1'b1;
                else next_q[r*16 + c] = 1'b0;
            end
        end
    end
endmodule