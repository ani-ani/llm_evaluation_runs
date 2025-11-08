module TopModule (
  input clk,
  input reset,
  input in,
  output reg disc,
  output reg flag,
  output reg err
);

  reg [2:0] count;
  reg prev_disc;
  reg prev_flag;
  reg prev_err;

  always_ff @(posedge clk) begin
    if (reset) begin
      count <= 3'b000;
      prev_disc <= 1'b0;
      prev_flag <= 1'b0;
      prev_err <= 1'b0;
      disc <= 1'b0;
      flag <= 1'b0;
      err <= 1'b0;
    end else begin
      logic curr_disc = (count == 3'd5 && in == 1'b0);
      logic curr_flag = (count == 3'd6 && in == 1'b0);
      logic curr_err;
      if (count >= 3'd7) begin
        curr_err = 1'b1;
      end else if (count == 3'd6 && in == 1'b1) begin
        curr_err = 1'b1;
      end else begin
        curr_err = 1'b0;
      end
      disc <= prev_disc;
      flag <= prev_flag;
      err <= prev_err;
      prev_disc <= curr_disc;
      prev_flag <= curr_flag;
      prev_err <= curr_err;
      if (in == 1'b0) begin
        count <= 3'b000;
      end else begin
        if (count < 3'd7) begin
          count <= count + 1'b1;
        end else begin
          count <= 3'd7;
        end
      end
    end
  end
endmodule