module tuple_filter (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] data_in,
  input [7:0] mask_in,
  output reg [7:0][7:0] data_out,
  output reg [3:0] valid_cnt,
  output reg done
);

  // Internal pipeline registers
  reg [7:0][7:0] r_data;
  reg [7:0]      r_mask;
  reg             r_start;
  reg [1:0]       cycle; // 0 -> idle, 1 -> stage1, 2 -> stage2

  // Combinational compute of filtered output from r_data and r_mask
  logic [7:0][7:0] next_data_out;
  logic [3:0]      next_valid_cnt;

  always_comb begin
    next_valid_cnt = '0;
    for (int i = 0; i < 8; i++) begin
      if (r_mask[i]) next_valid_cnt = next_valid_cnt + 1;
    end
    next_data_out = '0;
    for (int i = 0; i < 8; i++) begin
      if (r_mask[i]) begin
        next_data_out[next_valid_cnt - 1] = r_data[i];
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_data   <= '0;
      r_mask   <= '0;
      r_start  <= 1'b0;
      cycle    <= 2'b00;
      data_out <= '0;
      valid_cnt<= '0;
      done     <= 1'b0;
    end else begin
      // Pipeline control
      r_start <= start;
      if (r_start) begin
        if (cycle == 2'b00) begin
          // Cycle 1: capture inputs
          r_data <= data_in;
          r_mask <= mask_in;
          cycle  <= 2'b01;
        end else if (cycle == 2'b01) begin
          // Cycle 2: compute and produce results
          data_out <= next_data_out;
          valid_cnt<= next_valid_cnt;
          cycle    <= 2'b10;
        end else begin
          // Remain in stage 2 while r_start stays high
          cycle    <= 2'b10;
        end
        done <= (cycle == 2'b01); // pulse one cycle after the second stage
      end else begin
        // When start is low, clear pipeline and outputs
        r_data   <= '0;
        r_mask   <= '0;
        r_start  <= 1'b0;
        cycle    <= 2'b00;
        data_out <= '0;
        valid_cnt<= '0;
        done     <= 1'b0;
      end
    end
  end

endmodule
