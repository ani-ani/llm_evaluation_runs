module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);

    wire [255:0] q_next;

    genvar r, c;
    generate
        for (r = 0; r < 16; r = r + 1) begin : row
            for (c = 0; c < 16; c = c + 1) begin : col
                localparam i = r * 16 + c;
                localparam up = (r - 1 + 16) % 16;
                localparam down = (r + 1) % 16;
                localparam left = (c - 1 + 16) % 16;
                localparam right = (c + 1) % 16;

                logic [3:0] count;
                assign count = q[up * 16 + left] + q[up * 16 + c] + q[up * 16 + right] +
                               q[r * 16 + left] + q[r * 16 + right] +
                               q[down * 16 + left] + q[down * 16 + c] + q[down * 16 + right];

                wire new_val;
                assign new_val = (count == 4'd3) || ((count == 4'd2) && q[i]);
                assign q_next[i] = new_val;
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (load) begin
            q <= data;
        end else begin
            q <= q_next;
        end
    end

endmodule