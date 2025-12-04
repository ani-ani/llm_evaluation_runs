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

  reg [7:0][7:0] data_reg;
  reg [7:0] mask_reg;
  reg start_dly1, start_dly2;

  always_comb begin
    integer j = 0;
    reg [7:0][7:0] packed_data;
    reg [3:0] count;

    packed_data = '0;
    count = '0;

    for (int i = 0; i < 8; i++) begin
      if (mask_reg[i]) begin
        packed_data[j] = data_reg[i];
        j = j + 1;
      end
    end

    count = j[3:0];

    // Assign to temporary outputs
    data_out = packed_data;
    valid_cnt = count;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_reg <= '0;
      mask_reg <= '0;
      data_out <= '0;
      valid_cnt <= '0;
      done <= 1'b0;
      start_dly1 <= 1'b0;
      start_dly2 <= 1'b0;
    end
    else begin
      // Delay start by 2 cycles
      start_dly1 <= start;
      start_dly2 <= start_dly1;

      // Latch inputs when start is asserted
      if (start) begin
        data_reg <= data_in;
        mask_reg <= mask_in;
      end

      // Reset done unless processing completed
      done <= start_dly2;
    end
  end
endmodule