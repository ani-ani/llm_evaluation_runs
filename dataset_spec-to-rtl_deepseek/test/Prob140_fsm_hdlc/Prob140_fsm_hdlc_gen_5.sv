module TopModule(
  input clk,
  input reset,
  input in,
  output disc,
  output flag,
  output err
);

  reg [2:0] state;
  reg set_disc;
  reg set_flag;
  reg set_err;
  reg disc_reg;
  reg flag_reg;
  reg err_reg;

  assign disc = disc_reg;
  assign flag = flag_reg;
  assign err = err_reg;

  always @(posedge clk) begin
    if (reset) begin
      state <= 3'd0;
      disc_reg <= 0;
      flag_reg <= 0;
      err_reg <= 0;
      set_disc <= 0;
      set_flag <= 0;
      set_err <= 0;
    end else begin
      set_disc <= 0;
      set_flag <= 0;
      set_err <= 0;
      case (state)
        3'd0: begin
          if (in) state <= 3'd1;
        end
        3'd1: begin
          if (in) state <= 3'd2;
          else state <= 3'd0;
        end
        3'd2: begin
          if (in) state <= 3'd3;
          else state <= 3'd0;
        end
        3'd3: begin
          if (in) state <= 3'd4;
          else state <= 3'd0;
        end
        3'd4: begin
          if (in) state <= 3'd5;
          else state <= 3'd0;
        end
        3'd5: begin
          if (in) state <= 3'd6;
          else begin
            state <= 3'd0;
            set_disc <= 1;
          end
        end
        3'd6: begin
          if (in) begin
            state <= 3'd7;
            set_err <= 1;
          end else begin
            state <= 3'd0;
            set_flag <= 1;
          end
        end
        3'd7: begin
          if (in) set_err <= 1;
          else begin
            state <= 3'd0;
          end
        end
      endcase
      disc_reg <= set_disc;
      flag_reg <= set_flag;
      err_reg <= set_err;
    end
  end
endmodule