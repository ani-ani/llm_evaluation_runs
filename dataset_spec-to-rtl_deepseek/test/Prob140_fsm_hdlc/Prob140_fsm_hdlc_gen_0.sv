module TopModule (
  input logic clk,
  input logic reset,
  input logic in,
  output logic disc,
  output logic flag,
  output logic err
);

  logic [3:0] counter;
  logic error_flag;

  always_ff @(posedge clk) begin
    if (reset) begin
      counter <= 4'd0;
      disc <= 1'b0;
      flag <= 1'b0;
      error_flag <= 1'b0;
    end else begin
      if (in) begin
        if (counter < 7) counter <= counter + 1;
      end else begin
        counter <= 4'd0;
      end
      disc <= (counter == 5) && (!in);
      flag <= (counter == 6) && (!in);
      if (in && (counter == 6)) error_flag <= 1'b1;
      else if (!in) error_flag <= 1'b0;
    end
  end

  assign err = error_flag;
endmodule