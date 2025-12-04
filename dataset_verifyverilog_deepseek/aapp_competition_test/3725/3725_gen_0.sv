module frog_flower_sync(
  input clk,
  input rst_n,
  input start,
  input [15:0] m,
  input [15:0] h1, a1, x1, y1,
  input [15:0] h2, a2, x2, y2,
  output reg [11:0] time_out,
  output reg done,
  output reg fail
);

  reg [15:0] h1_reg, h2_reg;
  reg [11:0] count_reg;
  reg running;
  wire [15:0] next_h1, next_h2;
  
  wire [15:0] current_h1 = (running) ? h1_reg : h1;
  wire [15:0] current_h2 = (running) ? h2_reg : h2;
  assign next_h1 = (x1 * current_h1 + y1) % m;
  assign next_h2 = (x2 * current_h2 + y2) % m;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      fail <= 1'b0;
      time_out <= 12'b0;
      h1_reg <= 16'b0;
      h2_reg <= 16'b0;
      count_reg <= 12'b0;
      running <= 1'b0;
    end else if (!start) begin
      done <= 1'b0;
      fail <= 1'b0;
      time_out <= 12'b0;
      h1_reg <= 16'b0;
      h2_reg <= 16'b0;
      count_reg <= 12'b0;
      running <= 1'b0;
    end else begin
      if (done) begin
        // Hold state
      end else begin
        if (!running) begin
          // Initial cycle
          h1_reg <= h1;
          h2_reg <= h2;
          count_reg <= 12'b0;
          running <= 1'b1;
          if ((next_h1 == a1) && (next_h2 == a2)) begin
            done <= 1'b1;
            time_out <= 12'b0;
            fail <= 1'b0;
          end
        end else begin
          if ((next_h1 == a1) && (next_h2 == a2)) begin
            done <= 1'b1;
            time_out <= count_reg;
            fail <= 1'b0;
          end else if (count_reg == 12'hBFF) begin  // 3071
            done <= 1'b1;
            fail <= 1'b1;
          end else begin
            h1_reg <= next_h1;
            h2_reg <= next_h2;
            count_reg <= count_reg + 1'b1;
          end
        end
      end
    end
  end
endmodule