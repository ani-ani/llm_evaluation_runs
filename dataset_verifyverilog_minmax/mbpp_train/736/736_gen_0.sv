module bisect_left (
  input clk,
  input rst_n,
  input start,
  input [3:0] value,
  input [7:0][3:0] array,
  output reg [3:0] index,
  output reg done
);
  // Internal signals and pipeline registers
  reg start_r1, start_r2;
  wire start_pulse;

  reg [2:0] valid_reg;
  reg valid_r1, valid_r2, valid_r3, valid_r4;

  reg busy;
  reg [3:0] low_s0, low_s1, low_s2, low_s3, low_s4;
  reg [3:0] high_s0, high_s1, high_s2, high_s3, high_s4;
  reg [3:0] mid_s1, mid_s2, mid_s3;

  // Edge detection for start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_r1 <= 1'b0;
      start_r2 <= 1'b0;
    end else begin
      start_r1 <= start;
      start_r2 <= start_r1;
    end
  end
  assign start_pulse = start_r1 && ~start_r2;

  // State: busy signals computation in progress
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) busy <= 1'b0;
    else if (start_pulse) busy <= 1'b1;
    else if (done) busy <= 1'b0; // complete after 5 cycles
  end

  // 3-stage binary search pipeline + 2 extra latency stages to meet 5-cycle result
  // Stage 0: Initialize boundaries and token
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_s0  <= 4'd0;
      high_s0 <= 4'd7;
      valid_reg <= 3'b0;
    end else begin
      if (start_pulse) begin
        low_s0  <= 4'd0;
        high_s0 <= 4'd7;
        valid_reg <= 3'b1; // 3-cycle validity token for 3 search stages
      end else begin
        // passthrough (unchanged) when not starting
        low_s0  <= low_s0;
        high_s0 <= high_s0;
        valid_reg <= valid_reg;
      end
    end
  end

  // Shift the validity token through the search stages
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_r1 <= 1'b0;
      valid_r2 <= 1'b0;
      valid_r3 <= 1'b0;
      valid_r4 <= 1'b0;
    end else begin
      if (start_pulse) begin
        valid_r1 <= 1'b1; // stage 1 valid in the next cycle
        valid_r2 <= 1'b0;
        valid_r3 <= 1'b0;
        valid_r4 <= 1'b0;
      end else begin
        valid_r1 <= valid_reg[0];
        valid_r2 <= valid_reg[1];
        valid_r3 <= valid_reg[2];
        valid_r4 <= valid_r3; // keep through latency stages
      end
    end
  end

  // Stage 1
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_s1  <= 4'd0;
      high_s1 <= 4'd0;
      mid_s1  <= 4'd0;
    end else begin
      low_s1  <= low_s0;
      high_s1 <= high_s0;
      mid_s1  <= (low_s0 + high_s0) >> 1; // (low+high)/2
    end
  end

  // Stage 2
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_s2  <= 4'd0;
      high_s2 <= 4'd0;
      mid_s2  <= 4'd0;
    end else begin
      low_s2  <= (valid_reg[0] && (array[mid_s1] < value)) ? (mid_s1 + 1'b1) : low_s1;
      high_s2 <= (valid_reg[0] && (array[mid_s1] < value)) ? high_s1 : (mid_s1 - 1'b1);
      mid_s2  <= (low_s1 + high_s1) >> 1;
    end
  end

  // Stage 3 (final binary search stage)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_s3  <= 4'd0;
      high_s3 <= 4'd0;
      mid_s3  <= 4'd0;
    end else begin
      low_s3  <= (valid_reg[1] && (array[mid_s2] < value)) ? (mid_s2 + 1'b1) : low_s2;
      high_s3 <= (valid_reg[1] && (array[mid_s2] < value)) ? high_s2 : (mid_s2 - 1'b1);
      mid_s3  <= (low_s2 + high_s2) >> 1;
    end
  end

  // Latency stages to make result available at cycle 5 from start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      low_s4  <= 4'd0;
      high_s4 <= 4'd0;
    end else begin
      low_s4  <= low_s3;
      high_s4 <= high_s3;
    end
  end

  // Done flag: result is valid 5 cycles after start
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) done <= 1'b0;
    else if (valid_r4) done <= 1'b1; // valid token after latency stages
    else done <= 1'b0;
  end

  // Output index (final low after 3 search stages, held through latency stages)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) index <= 4'd0;
    else if (done) index <= low_s4; // low after 3 iterations, delayed to meet 5-cycle timing
    else index <= 4'd0;
  end
endmodule
