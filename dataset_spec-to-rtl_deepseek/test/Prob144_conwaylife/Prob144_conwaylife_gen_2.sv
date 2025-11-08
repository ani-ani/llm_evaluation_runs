module TopModule(
    input clk,
    input load,
    input [255:0] data,
    output reg [255:0] q
);

    genvar rr, cc;

    wire [255:0] next_q;

    generate
        for (rr = 0; rr < 16; rr = rr + 1) begin: rows
            wire [15:0] next_state_row;
            for (cc = 0; cc < 16; cc = cc + 1) begin: columns
                wire [3:0] live_neighbors;
                wire next_bit;
                assign live_neighbors =
                    q[((rr - 1 + 16) % 16) * 16 + (cc - 1 + 16) % 16] +
                    q[((rr - 1 + 16) % 16) * 16 + cc] +
                    q[((rr - 1 + 16) % 16) * 16 + (cc + 1) % 16] +
                    q[rr * 16 + (cc - 1 + 16) % 16] +
                    q[rr * 16 + (cc + 1) % 16] +
                    q[((rr + 1) % 16) * 16 + (cc - 1 + 16) % 16] +
                    q[((rr + 1) % 16) * 16 + cc] +
                    q[((rr + 1) % 16) * 16 + (cc + 1) % 16];
                assign next_bit = (live_neighbors == 4'd3) || (live_neighbors == 4'd2 && q[rr * 16 + cc]);
                assign next_state_row[cc] = next_bit;
            end
            assign next_q[((15 - rr) * 16) + 15 -: 16] = next_state_row;
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