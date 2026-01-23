module string_compressor (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [15:0] a_cost,
  input [15:0] b_cost,
  input [3:0] str_len,
  output reg [15:0] min_cost,
  output reg done
);

  // Internal signals
  reg [2:0] state;
  reg [3:0] load_count;
  reg [7:0] string_buf [0:15];
  reg [15:0] dp [0:16];
  reg [3:0] str_len_reg;
  reg [7:0] done_delay_counter;
  reg string_ready;

  // State machine and control
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= 3'd0;
      load_count <= 4'd0;
      str_len_reg <= 4'd0;
      string_buf <= 16'b0;
      for (int i=0; i<17; i++) dp[i] <= 16'd0;
      done_delay_counter <= 8'd0;
      min_cost <= 16'd0;
      done <= 1'b0;
    end else begin
      case (state)
        3'd0: // IDLE
          if (start) state <= 3'd1; // LOAD
        3'd1: // LOAD
          if (start) begin
            if (load_count == 4'd0) str_len_reg <= str_len;
            if (load_count < str_len_reg) begin
              string_buf[load_count] <= char_in;
              load_count <= load_count + 1;
              if (load_count == str_len_reg) state <= 3'd2; // COMPUTE
            end
          end
        3'd2: // COMPUTE
          state <= 3'd3; // WAIT
          done_delay_counter <= 8'd256;
        3'd3: // WAIT
          if (done_delay_counter == 0) begin
            state <= 3'd4; // DONE
            min_cost <= dp[str_len_reg];
            done <= 1'b1;
          end else begin
            done_delay_counter <= done_delay_counter - 1;
          end
        3'd4: // DONE
          done <= 1'b1;
          min_cost <= dp[str_len_reg]; // keep output stable
      endcase
    end
  end

  // Compute DP when string is ready
  always @(*) begin
    if (!string_ready) begin
      dp[0] <= 16'd0;
      for (int i=1; i<17; i++) dp[i] <= 16'd0;
    end else begin
      dp[0] = 16'd0;
      // i=1
      dp[1] = dp[0] + a_cost;
      // i=2
      dp[2] = dp[1] + a_cost;
      if (string_buf[1] == string_buf[0]) dp[2] = min(dp[2], dp[0] + b_cost);
      // i=3
      dp[3] = dp[2] + a_cost;
      if (string_buf[2] == string_buf[0]) dp[3] = min(dp[3], dp[0] + b_cost);
      if (string_buf[2] == string_buf[1]) dp[3] = min(dp[3], dp[1] + b_cost);
      // i=4
      dp[4] = dp[3] + a_cost;
      if (string_buf[3] == string_buf[0]) dp[4] = min(dp[4], dp[0] + b_cost);
      if (string_buf[3] == string_buf[1]) dp[4] = min(dp[4], dp[1] + b_cost);
      if (string_buf[3] == string_buf[2]) dp[4] = min(dp[4], dp[2] + b_cost);
      // i=5
      dp[5] = dp[4] + a_cost;
      if (string_buf[4] == string_buf[0]) dp[5] = min(dp[5], dp[0] + b_cost);
      if (string_buf[4] == string_buf[1]) dp[5] = min(dp[5], dp[1] + b_cost);
      if (string_buf[4] == string_buf[2]) dp[5] = min(dp[5], dp[2] + b_cost);
      if (string_buf[4] == string_buf[3]) dp[5] = min(dp[5], dp[3] + b_cost);
      // i=6
      dp[6] = dp[5] + a_cost;
      if (string_buf[5] == string_buf[0]) dp[6] = min(dp[6], dp[0] + b_cost);
      if (string_buf[5] == string_buf[1]) dp[6] = min(dp[6], dp[1] + b_cost);
      if (string_buf[5] == string_buf[2]) dp[6] = min(dp[6], dp[2] + b_cost);
      if (string_buf[5] == string_buf[3]) dp[6] = min(dp[6], dp[3] + b_cost);
      if (string_buf[5] == string_buf[4]) dp[6] = min(dp[6], dp[4] + b_cost);
      // i=7
      dp[7] = dp[6] + a_cost;
      if (string_buf[6] == string_buf[0]) dp[7] = min(dp[7], dp[0] + b_cost);
      if (string_buf[6] == string_buf[1]) dp[7] = min(dp[7], dp[1] + b_cost);
      if (string_buf[6] == string_buf[2]) dp[7] = min(dp[7], dp[2] + b_cost);
      if (string_buf[6] == string_buf[3]) dp[7] = min(dp[7], dp[3] + b_cost);
      if (string_buf[6] == string_buf[4]) dp[7] = min(dp[7], dp[4] + b_cost);
      if (string_buf[6] == string_buf[5]) dp[7] = min(dp[7], dp[5] + b_cost);
      // i=8
      dp[8] = dp[7] + a_cost;
      if (string_buf[7] == string_buf[0]) dp[8] = min(dp[8], dp[0] + b_cost);
      if (string_buf[7] == string_buf[1]) dp[8] = min(dp[8], dp[1] + b_cost);
      if (string_buf[7] == string_buf[2]) dp[8] = min(dp[8], dp[2] + b_cost);
      if (string_buf[7] == string_buf[3]) dp[8] = min(dp[8], dp[3] + b_cost);
      if (string_buf[7] == string_buf[4]) dp[8] = min(dp[8], dp[4] + b_cost);
      if (string_buf[7] == string_buf[5]) dp[8] = min(dp[8], dp[5] + b_cost);
      if (string_buf[7] == string_buf[6]) dp[8] = min(dp[8], dp[6] + b_cost);
      // i=9
      dp[9] = dp[8] + a_cost;
      if (string_buf[8] == string_buf[0]) dp[9] = min(dp[9], dp[0] + b_cost);
      if (string_buf[8] == string_buf[1]) dp[9] = min(dp[9], dp[1] + b_cost);
      if (string_buf[8] == string_buf[2]) dp[9] = min(dp[9], dp[2] + b_cost);
      if (string_buf[8] == string_buf[3]) dp[9] = min(dp[9], dp[3] + b_cost);
      if (string_buf[8] == string_buf[4]) dp[9] = min(dp[9], dp[4] + b_cost);
      if (string_buf[8] == string_buf[5]) dp[9] = min(dp[9], dp[5] + b_cost);
      if (string_buf[8] == string_buf[6]) dp[9] = min(dp[9], dp[6] + b_cost);
      if (string_buf[8] == string_buf[7]) dp[9] = min(dp[9], dp[7] + b_cost);
      // i=10
      dp[10] = dp[9] + a_cost;
      if (string_buf[9] == string_buf[0]) dp[10] = min(dp[10], dp[0] + b_cost);
      if (string_buf[9] == string_buf[1]) dp[10] = min(dp[10], dp[1] + b_cost);
      if (string_buf[9] == string_buf[2]) dp[10] = min(dp[10], dp[2] + b_cost);
      if (string_buf[9] == string_buf[3]) dp[10] = min(dp[10], dp[3] + b_cost);
      if (string_buf[9] == string_buf[4]) dp[10] = min(dp[10], dp[4] + b_cost);
      if (string_buf[9] == string_buf[5]) dp[10] = min(dp[10], dp[5] + b_cost);
      if (string_buf[9] == string_buf[6]) dp[10] = min(dp[10], dp[6] + b_cost);
      if (string_buf[9] == string_buf[7]) dp[10] = min(dp[10], dp[7] + b_cost);
      if (string_buf[9] == string_buf[8]) dp[10] = min(dp[10], dp[8] + b_cost);
      // i=11
      dp[11] = dp[10] + a_cost;
      if (string_buf[10] == string_buf[0]) dp[11] = min(dp[11], dp[0] + b_cost);
      if (string_buf[10] == string_buf[1]) dp[11] = min(dp[11], dp[1] + b_cost);
      if (string_buf[10] == string_buf[2]) dp[11] = min(dp[11], dp[2] + b_cost);
      if (string_buf[10] == string_buf[3]) dp[11] = min(dp[11], dp[3] + b_cost);
      if (string_buf[10] == string_buf[4]) dp[11] = min(dp[11], dp[4] + b_cost);
      if (string_buf[10] == string_buf[5]) dp[11] = min(dp[11], dp[5] + b_cost);
      if (string_buf[10] == string_buf[6]) dp[11] = min(dp[11], dp[6] + b_cost);
      if (string_buf[10] == string_buf[7]) dp[11] = min(dp[11], dp[7] + b_cost);
      if (string_buf[10] == string_buf[8]) dp[11] = min(dp[11], dp[8] + b_cost);
      if (string_buf[10] == string_buf[9]) dp[11] = min(dp[11], dp[9] + b_cost);
      // i=12
      dp[12] = dp[11] + a_cost;
      if (string_buf[11] == string_buf[0]) dp[12] = min(dp[12], dp[0] + b_cost);
      if (string_buf[11] == string_buf[1]) dp[12] = min(dp[12], dp[1] + b_cost);
      if (string_buf[11] == string_buf[2]) dp[12] = min(dp[12], dp[2] + b_cost);
      if (string_buf[11] == string_buf[3]) dp[12] = min(dp[12], dp[3] + b_cost);
      if (string_buf[11] == string_buf[4]) dp[12] = min(dp[12], dp[4] + b_cost);
      if (string_buf[11] == string_buf[5]) dp[12] = min(dp[12], dp[5] + b_cost);
      if (string_buf[11] == string_buf[6]) dp[12] = min(dp[12], dp[6] + b_cost);
      if (string_buf[11] == string_buf[7]) dp[12] = min(dp[12], dp[7] + b_cost);
      if (string_buf[11] == string_buf[8]) dp[12] = min(dp[12], dp[8] + b_cost);
      if (string_buf[11] == string_buf[9]) dp[12] = min(dp[12], dp[9] + b_cost);
      if (string_buf[11] == string_buf[10]) dp[12] = min(dp[12], dp[10] + b_cost);
      // i=13
      dp[13] = dp[12] + a_cost;
      if (string_buf[12] == string_buf[0]) dp[13] = min(dp[13], dp[0] + b_cost);
      if (string_buf[12] == string_buf[1]) dp[13] = min(dp[13], dp[1] + b_cost);
      if (string_buf[12] == string_buf[2]) dp[13] = min(dp[13], dp[2] + b_cost);
      if (string_buf[12] == string_buf[3]) dp[13] = min(dp[13], dp[3] + b_cost);
      if (string_buf[12] == string_buf[4]) dp[13] = min(dp[13], dp[4] + b_cost);
      if (string_buf[12] == string_buf[5]) dp[13] = min(dp[13], dp[5] + b_cost);
      if (string_buf[12] == string_buf[6]) dp[13] = min(dp[13], dp[6] + b_cost);
      if (string_buf[12] == string_buf[7]) dp[13] = min(dp[13], dp[7] + b_cost);
      if (string_buf[12] == string_buf[8]) dp[13] = min(dp[13], dp[8] + b_cost);
      if (string_buf[12] == string_buf[9]) dp[13] = min(dp[13], dp[9] + b_cost);
      if (string_buf[12] == string_buf[10]) dp[13] = min(dp[13], dp[10] + b_cost);
      if (string_buf[12] == string_buf[11]) dp[13] = min(dp[13], dp[11] + b_cost);
      // i=14
      dp[14] = dp[13] + a_cost;
      if (string_buf[13] == string_buf[0]) dp[14] = min(dp[14], dp[0] + b_cost);
      if (string_buf[13] == string_buf[1]) dp[14] = min(dp[14], dp[1] + b_cost);
      if (string_buf[13] == string_buf[2]) dp[14] = min(dp[14], dp[2] + b_cost);
      if (string_buf[13] == string_buf[3]) dp[14] = min(dp[14], dp[3] + b_cost);
      if (string_buf[13] == string_buf[4]) dp[14] = min(dp[14], dp[4] + b_cost);
      if (string_buf[13] == string_buf[5]) dp[14] = min(dp[14], dp[5] + b_cost);
      if (string_buf[13] == string_buf[6]) dp[14] = min(dp[14], dp[6] + b_cost);
      if (string_buf[13] == string_buf[7]) dp[14] = min(dp[14], dp[7] + b_cost);
      if (string_buf[13] == string_buf[8]) dp[14] = min(dp[14], dp[8] + b_cost);
      if (string_buf[13] == string_buf[9]) dp[14] = min(dp[14], dp[9] + b_cost);
      if (string_buf[13] == string_buf[10]) dp[14] = min(dp[14], dp[10] + b_cost);
      if (string_buf[13] == string_buf[11]) dp[14] = min(dp[14], dp[11] + b_cost);
      if (string_buf[13] == string_buf[12]) dp[14] = min(dp[14], dp[12] + b_cost);
      // i=15
      dp[15] = dp[14] + a_cost;
      if (string_buf[14] == string_buf[0]) dp[15] = min(dp[15], dp[0] + b_cost);
      if (string_buf[14] == string_buf[1]) dp[15] = min(dp[15], dp[1] + b_cost);
      if (string_buf[14] == string_buf[2]) dp[15] = min(dp[15], dp[2] + b_cost);
      if (string_buf[14] == string_buf[3]) dp[15] = min(dp[15], dp[3] + b_cost);
      if (string_buf[14] == string_buf[4]) dp[15] = min(dp[15], dp[4] + b_cost);
      if (string_buf[14] == string_buf[5]) dp[15] = min(dp[15], dp[5] + b_cost);
      if (string_buf[14] == string_buf[6]) dp[15] = min(dp[15], dp[6] + b_cost);
      if (string_buf[14] == string_buf[7]) dp[15] = min(dp[15], dp[7] + b_cost);
      if (string_buf[14] == string_buf[8]) dp[15] = min(dp[15], dp[8] + b_cost);
      if (string_buf[14] == string_buf[9]) dp[15] = min(dp[15], dp[9] + b_cost);
      if (string_buf[14] == string_buf[10]) dp[15] = min(dp[15], dp[10] + b_cost);
      if (string_buf[14] == string_buf[11]) dp[15] = min(dp[15], dp[11] + b_cost);
      if (string_buf[14] == string_buf[12]) dp[15] = min(dp[15], dp[12] + b_cost);
      if (string_buf[14] == string_buf[13]) dp[15] = min(dp[15], dp[13] + b_cost);
      // i=16
      dp[16] = dp[15] + a_cost;
      if (string_buf[15] == string_buf[0]) dp[16] = min(dp[16], dp[0] + b_cost);
      if (string_buf[15] == string_buf[1]) dp[16] = min(dp[16], dp[1] + b_cost);
      if (string_buf[15] == string_buf[2]) dp[16] = min(dp[16], dp[2] + b_cost);
      if (string_buf[15] == string_buf[3]) dp[16] = min(dp[16], dp[3] + b_cost);
      if (string_buf[15] == string_buf[4]) dp[16] = min(dp[16], dp[4] + b_cost);
      if (string_buf[15] == string_buf[5]) dp[16] = min(dp[16], dp[5] + b_cost);
      if (string_buf[15] == string_buf[6]) dp[16] = min(dp[16], dp[6] + b_cost);
      if (string_buf[15] == string_buf[7]) dp[16] = min(dp[16], dp[7] + b_cost);
      if (string_buf[15] == string_buf[8]) dp[16] = min(dp[16], dp[8] + b_cost);
      if (string_buf[15] == string_buf[9]) dp[16] = min(dp[16], dp[9] + b_cost);
      if (string_buf[15] == string_buf[10]) dp[16] = min(dp[16], dp[10] + b_cost);
      if (string_buf[15] == string_buf[11]) dp[16] = min(dp[16], dp[11] + b_cost);
      if (string_buf[15] == string_buf[12]) dp[16] = min(dp[16], dp[12] + b_cost);
      if (string_buf[15] == string_buf[13]) dp[16] = min(dp[16], dp[13] + b_cost);
      if (string_buf[15] == string_buf[14]) dp[16] = min(dp[16], dp[14] + b_cost);

  // Assign string_ready
  assign string_ready = (load_count == str_len_reg);
endmodule