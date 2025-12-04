module virus_spread_tracker(
  input clk,
  input rst_n,
  input start,
  input [1:0] days,
  input [7:0] initial_infected,
  input [15:0] s [0:7],
  input [15:0] t [0:7],
  output reg [7:0] infected_mask,
  output reg done
);

  reg [7:0] current_infected;
  reg [7:0] next_infected;
  reg [1:0] day_cnt;

  always_comb begin
    next_infected = current_infected;
    if (!done) begin
      for (int i = 0; i < 8; i++) begin
        if (!current_infected[i]) begin
          bit any_overlap = 1'b0;
          for (int j = 0; j < 8; j++) begin
            if (current_infected[j]) begin
              if ((s[i] <= t[j] && t[i] >= s[j]) || (s[i] == t[i] && s[i] == s[j])) begin
                any_overlap = 1'b1;
              end
            end
          end
          if (any_overlap) next_infected[i] = 1'b1;
        end
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_infected <= 8'b0;
      day_cnt <= 2'b0;
      done <= 1'b0;
      infected_mask <= 8'b0;
    end else begin
      if (start) begin
        current_infected <= initial_infected;
        day_cnt <= 2'b0;
        done <= (days == 2'b0);
        infected_mask <= (days == 2'b0) ? initial_infected : 8'b0;
      end else if (!done) begin
        if (day_cnt == days) begin
          infected_mask <= current_infected;
          done <= 1'b1;
        end else begin
          current_infected <= next_infected;
          day_cnt <= day_cnt + 1;
        end
      end
    end
  end
endmodule