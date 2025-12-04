module simple_power(
  input        clk,
  input        rst_n,
  input        start,
  input [15:0] x,
  input [15:0] n,
  output reg   result,
  output reg   done
);

  // States
  localparam IDLE  = 2'b00;
  localparam CALC  = 2'b01;
  localparam DONE  = 2'b10;

  reg [1:0]  state;
  reg [15:0] power_reg;
  reg [4:0]  iter_cnt; // up to 16 iterations

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      power_reg <= 16'd0;
      iter_cnt  <= 5'd0;
      result    <= 1'b0;
      done      <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done   <= 1'b0;
          result <= 1'b0;
          if (start) begin
            // Special case: x == 1 -> true for any n
            if (x == 16'd1) begin
              result    <= 1'b1;
              done      <= 1'b1;
              state     <= DONE;
            end else begin
              power_reg <= 16'd1; // start from n^0
              iter_cnt  <= 5'd0;
              state     <= CALC;
            end
          end
        end

        CALC: begin
          // Perform next multiplication
          power_reg <= power_reg * n;
          iter_cnt  <= iter_cnt + 1'b1;

          // Evaluate based on next power value using blocking-style temporaries
          // to reflect the value after multiplication
          begin : check_block
            reg [15:0] next_power;
            next_power = power_reg * n;

            if (next_power == x) begin
              result <= 1'b1;
              done   <= 1'b1;
              state  <= DONE;
            end else if (next_power > x || iter_cnt == 5'd15) begin
              // Exceeded x or reached max iterations (16)
              result <= 1'b0;
              done   <= 1'b1;
              state  <= DONE;
            end
          end
        end

        DONE: begin
          // Hold result and done until next start
          if (start) begin
            done   <= 1'b0;
            result <= 1'b0;
            // Special case: x == 1 -> true for any n
            if (x == 16'd1) begin
              result    <= 1'b1;
              done      <= 1'b1;
              state     <= DONE;
            end else begin
              power_reg <= 16'd1;
              iter_cnt  <= 5'd0;
              state     <= CALC;
            end
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule