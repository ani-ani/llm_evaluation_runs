module task_threshold(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [31:0] power [0:3],
  input reg [7:0] processors [0:3],
  output reg [31:0] result,
  output reg done
);

  // Internal registers
  reg [31:0] power_reg [0:3];
  reg [7:0] proc_reg [0:3];
  reg start_r;
  wire start_pulse;
  reg [1:0] state;
  localparam IDLE = 2'b00;
  localparam RUN = 2'b01;
  reg [6:0] cnt;
  reg [31:0] result_reg;
  reg done_reg;

  // Detect start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_r <= 1'b0;
    else       start_r <= start;
  end
  assign start_pulse = start && (!start_r);

  // Compute minimal threshold (combinatorial)
  function [31:0] compute_min_threshold;
    input [31:0] p [0:3];
    input [7:0] pr [0:3];
    longint min_val;
    int mask;
    int firstIdx [4];
    int secondIdx[4];
    int firstCnt, secondCnt;
    int i, j, k;
    int valid;
    longint sumP;
    longint sumPr;
    longint thresh;

    min_val = 64'h7FFFFFFFFFFFFFFF;
    for (mask = 0; mask < 16; mask++) begin
      firstCnt = 0;
      secondCnt = 0;
      for (i = 0; i < 4; i++) begin
        if ((mask >> i) & 1) begin
          firstIdx[firstCnt] = i;
          firstCnt++;
        end else begin
          secondIdx[secondCnt] = i;
          secondCnt++;
        end
      end
      // Must have enough first tasks for the seconds
      if (firstCnt < secondCnt) continue;

      valid = 0;
      if (secondCnt == 0) begin
        valid = 1; // No second tasks -> always valid
      end else if (secondCnt == 1) begin
        for (i = 0; i < firstCnt && !valid; i++) begin
          if (p[firstIdx[i]] > p[secondIdx[0]]) valid = 1;
        end
      end else if (secondCnt == 2) begin
        // Assignment 1: second[0] -> first[i], second[1] -> first[j]
        for (i = 0; i < firstCnt && !valid; i++) begin
          if (p[firstIdx[i]] > p[secondIdx[0]]) begin
            for (j = 0; j < firstCnt && !valid; j++) begin
              if (j == i) continue;
              if (p[firstIdx[j]] > p[secondIdx[1]]) valid = 1;
            end
          end
        end
        // Assignment 2: second[1] -> first[i], second[0] -> first[j]
        if (!valid) begin
          for (i = 0; i < firstCnt && !valid; i++) begin
            if (p[firstIdx[i]] > p[secondIdx[1]]) begin
              for (j = 0; j < firstCnt && !valid; j++) begin
                if (j == i) continue;
                if (p[firstIdx[j]] > p[secondIdx[0]]) valid = 1;
              end
            end
          end
        end
      end
      if (!valid) continue;

      // Compute sums for first tasks
      sumP = 0;
      sumPr = 0;
      for (k = 0; k < firstCnt; k++) begin
        sumP  += p[firstIdx[k]];
        sumPr += pr[firstIdx[k]];
      end

      // Ceil division of (sumP/sumPr)*1000, avoid division by zero
      if (sumPr == 0) thresh = 0;
      else thresh = (sumP * 1000 + sumPr - 1) / sumPr;
      if (thresh < min_val) min_val = thresh;
    end
    compute_min_threshold = min_val[31:0];
  endfunction

  wire [31:0] min_thresh = compute_min_threshold(power_reg, proc_reg);

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      cnt        <= 7'd0;
      result_reg <= 32'd0;
      done_reg   <= 1'b0;
      for (int i = 0; i < 4; i++) begin
        power_reg[i] <= 32'd0;
        proc_reg[i]  <= 8'd0;
      end
    end else begin
      if (state == IDLE) begin
        if (start_pulse) begin
          // Latch inputs
          for (int i = 0; i < 4; i++) begin
            power_reg[i] <= power[i];
            proc_reg[i]  <= processors[i];
          end
          state <= RUN;
          cnt   <= 7'd0;
          result_reg <= 32'd0;
          done_reg   <= 1'b0;
        end
      end else if (state == RUN) begin
        if (cnt == 7'd49) begin
          result_reg <= min_thresh;
          done_reg   <= 1'b1;
          state <= IDLE;
        end else begin
          cnt <= cnt + 1;
        end
      end
    end
  end

  // Drive outputs
  assign result = result_reg;
  assign done   = done_reg;

endmodule