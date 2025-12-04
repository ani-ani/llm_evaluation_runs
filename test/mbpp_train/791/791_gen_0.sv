module tuple_filter(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0][7:0] data_in,
  input      [7:0]   mask_in,
  output reg [7:0][7:0] data_out,
  output reg [3:0]   valid_cnt,
  output reg         done
);

  // Pipeline stage 0: latch inputs and initialize
  reg [7:0][7:0] data_in_reg;
  reg [7:0]      mask_in_reg;

  // Pipeline stage 1: partial processing
  reg [7:0][7:0] stage1_data;
  reg [3:0]      stage1_cnt;
  reg            stage1_valid;

  // Pipeline stage 2: final outputs
  reg            stage2_valid;

  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_in_reg  <= '{default:8'b0};
      mask_in_reg  <= 8'b0;
      stage1_data  <= '{default:8'b0};
      stage1_cnt   <= 4'd0;
      stage1_valid <= 1'b0;
      stage2_valid <= 1'b0;
      data_out     <= '{default:8'b0};
      valid_cnt    <= 4'd0;
      done         <= 1'b0;
    end else begin
      // Default done low; will be pulsed when stage2_valid is set
      done <= 1'b0;

      // Stage 0: Capture inputs on start
      if (start) begin
        data_in_reg <= data_in;
        mask_in_reg <= mask_in;
      end

      // Stage 1: Process captured inputs from previous cycle when start was asserted
      stage1_valid <= start; // stage1_valid goes high one cycle after start
      if (start) begin
        stage1_cnt  <= 4'd0;
        stage1_data <= '{default:8'b0};
        for (i = 0; i < 8; i = i + 1) begin
          if (mask_in[i]) begin
            stage1_data[stage1_cnt] <= data_in[i];
            stage1_cnt <= stage1_cnt + 1'b1;
          end
        end
      end

      // Stage 2: Register outputs from stage1
      stage2_valid <= stage1_valid; // stage2_valid high two cycles after start
      if (stage1_valid) begin
        data_out  <= stage1_data;
        valid_cnt <= stage1_cnt;
      end

      // Generate done pulse one cycle when outputs are valid
      if (stage2_valid) begin
        done <= 1'b1;
      end
    end
  end

endmodule