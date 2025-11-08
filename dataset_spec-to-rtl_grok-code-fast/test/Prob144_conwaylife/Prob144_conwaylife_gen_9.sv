module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);
    wire [255:0] next_q;
    genvar x, y;
    generate
        for (x = 0; x < 16; x = x + 1) begin: row
            for (y = 0; y < 16; y = y + 1) begin: col
                localparam ix0 = (x - 1 + 16) % 16;
                localparam iy0 = (y - 1 + 16) % 16;
                localparam ix1 = (x - 1 + 16) % 16;
                localparam iy1 = y % 16;
                localparam ix2 = (x - 1 + 16) % 16;
                localparam iy2 = (y + 1) % 16;
                localparam ix3 = x % 16;
                localparam iy3 = (y - 1 + 16) % 16;
                localparam ix4 = x % 16;
                localparam iy4 = (y + 1) % 16;
                localparam ix5 = (x + 1) % 16;
                localparam iy5 = (y - 1 + 16) % 16;
                localparam ix6 = (x + 1) % 16;
                localparam iy6 = y % 16;
                localparam ix7 = (x + 1) % 16;
                localparam iy7 = (y + 1) % 16;
                wire [3:0] count = q[ix0*16 + iy0] + q[ix1*16 + iy1] + q[ix2*16 + iy2] +
                                   q[ix3*16 + iy3] + q[ix4*16 + iy4] + q[ix5*16 + iy5] +
                                   q[ix6*16 + iy6] + q[ix7*16 + iy7];
                assign next_q[x*16 + y] = (count == 4'd3) | (count == 4'd2 & q[x*16 + y]);
            end
        end
    endgenerate
    always @(posedge clk) begin
        if (load) begin
            q <= data;
        end else begin
            q <= next_q;
        end
    end
endmodule