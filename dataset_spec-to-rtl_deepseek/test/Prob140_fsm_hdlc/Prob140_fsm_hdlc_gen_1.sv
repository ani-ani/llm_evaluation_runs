module TopModule(
  input clk, reset, in,
  output reg disc, flag, err
);

  reg [2:0] count;
  reg disc_pending, flag_pending, err_pending;

  always @(posedge clk) begin
    if (reset) begin
      count <= 3'b000;
      disc_pending <= 0;
      flag_pending <= 0;
      err_pending <= 0;
      disc <= 0;
      flag <= 0;
      err <= 0;
    end else begin
      if (in) begin
        if (count < 3'b111) count <= count + 1;
      end else begin
        count <= 3'b000;
      end

      disc_pending <= ((count == 3'b101) && !in) ? 1'b1 : 1'b0;
      flag_pending <= ((count == 3'b110) && !in) ? 1'b1 : 1'b0;
      err_pending <= ((count == 3'b110) && in) ? 1'b1 : 1'b0;

      disc <= disc_pending;
      flag <= flag_pending;
      err <= err_pending;
    end
  end
endmodule