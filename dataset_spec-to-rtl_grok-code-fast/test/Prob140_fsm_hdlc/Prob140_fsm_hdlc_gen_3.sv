module TopModule(
  input  clk,
  input  reset,
  input  in,
  output disc,
  output flag,
  output err
);
  reg [3:0] counter;
  reg disc_ff;
  reg flag_ff;
  reg err_ff;

  assign disc = disc_ff;
  assign flag = flag_ff;
  assign err = err_ff;

  always @(posedge clk) begin
    if (reset) begin
      counter <= 4'd0;
      disc_ff <= 1'b0;
      flag_ff <= 1'b0;
      err_ff <= 1'b0;
    end else begin
      // Detect conditions and update flags
      disc_ff <= ((counter == 4'd5) && (in == 1'b0)) ? 1'b1 : (disc_ff ? 1'b0 : 1'b0);
      flag_ff <= ((counter == 4'd6) && (in == 1'b0)) ? 1'b1 : (flag_ff ? 1'b0 : 1'b0);
      err_ff <= ((counter == 4'd6) && (in == 1'b1)) ? 1'b1 : (err_ff ? 1'b0 : 1'b0);
      // Update counter
      if (in == 1'b0) begin
        counter <= 4'd0;
      end else begin
        counter <= counter + 1;
      end
    end
  end
endmodule