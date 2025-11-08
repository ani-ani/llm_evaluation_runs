module TopModule(
  input logic clk,
  input logic load,
  input logic [255:0] data,
  output logic [255:0] q
);

  logic [255:0] next_q;

  always_comb begin
    next_q = 0;
    for (int r = 0; r < 16; r++) begin
      for (int c = 0; c < 16; c++) begin
        int count = 0;
        count += q[((r-1+16)%16 * 16) + ((c-1+16)%16)];
        count += q[((r-1+16)%16 * 16) + c];
        count += q[((r-1+16)%16 * 16) + ((c+1)%16)];
        count += q[(r * 16) + ((c-1+16)%16)];
        count += q[(r * 16) + ((c+1)%16)];
        count += q[((r+1)%16 * 16) + ((c-1+16)%16)];
        count += q[((r+1)%16 * 16) + c];
        count += q[((r+1)%16 * 16) + ((c+1)%16)];
        logic curr = q[r*16 + c];
        logic next_cell;
        if (count <= 1) next_cell = 1'b0;
        else if (count == 2) next_cell = curr;
        else if (count == 3) next_cell = 1'b1;
        else next_cell = 1'b0;
        next_q[r*16 + c] = next_cell;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (load) q <= data;
    else q <= next_q;
  end

endmodule