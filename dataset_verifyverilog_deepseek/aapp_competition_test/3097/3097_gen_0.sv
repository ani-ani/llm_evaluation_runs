module interval_counter(
  input [15:0] A,
  input [15:0] B,
  output reg [31:0] count
);

  logic [31:0] rom [0:65535];

  initial begin
    for (int i = 0; i <= 65535; i++) begin
      rom[i] = 32'd0;
    end
  end

  always_comb begin
    count = 0;
    for (int i = A; i <= B; i++) begin
      count = count + rom[i];
    end
  end

endmodule