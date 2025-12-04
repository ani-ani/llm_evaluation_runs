module stone_pile (
  input clk,
  input rst_n,
  input start,
  input [4:0] n,
  output logic [4:0] levels [0:7],
  output logic done
);

  logic [3:0] shft_reg;
  logic [4:0] next_val;
  logic done_next;
  integer i;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (i = 0; i < 8; i++) levels[i] <= 5'h0;
      shft_reg <= 4'h0;
      done <= 1'b0;
    end else begin
      // Shift register: 1 at the active position (0..7), 0 otherwise
      shft_reg <= {shft_reg[2:0], start};

      // Sequential output update: valid on cycle i when shft_reg[i] is 1
      for (i = 0; i < 8; i++) begin
        if (shft_reg[i]) begin
          levels[i] <= next_val;
        end
      end

      // done asserts 10 cycles after start: (2-cycle reset for shift) + 8 processing cycles
      done <= done_next;
    end
  end

  // Increment logic: level[i] = level[i-1] + 2
  assign next_val = levels[0] + 5'd2; // levels[0] was set in previous cycle when shft_reg[0] was 1

  // done timing: 10 cycles after start
  logic [3:0] cnt_dly;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt_dly <= 4'h0;
    end else begin
      // 10 cycles total after start: delay pipeline: 2 + 8
      cnt_dly <= {cnt_dly[2:0], start};
    end
  end
  assign done_next = cnt_dly[3] ? 1'b1 : 1'b0;

endmodule