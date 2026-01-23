module optimize_harvard (
  input [3:0] b,
  input [5:0] program_length,
  input [5:0] program [0:31],
  input [3:0] bank_assignment [0:13],
  output reg [31:0] total_cost
);

  reg [3:0] current_BSR = 15;
  integer i;
  reg [5:0] var;
  reg [3:0] bank;
  reg [31:0] cost = 0;

  always @* begin
    cost = 0;
    current_BSR = 15;
    for (i = 0; i < program_length; i = i + 1) begin
      var = program[i];
      bank = bank_assignment[var];
      if (bank == 0) begin
        cost = cost + 1;
      end else if (current_BSR == bank) begin
        cost = cost + 1;
      end else begin
        cost = cost + 2;
        current_BSR = bank;
      end
    end
    total_cost = cost;
  end

endmodule