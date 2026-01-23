module dragon_sequence_solver (
  input clk,
  input rst_n,
  input start,
  input [4:0] sequence_length,
  input [15:0] sequence_data,
  output reg [7:0] max_length,
  output reg done
);

  // State definitions
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] READING = 2'b01;
  localparam [1:0] PROCESSING = 2'b10;
  localparam [1:0] DONE = 2'b11;

  // State register
  reg [1:0] state, next_state;

  // DP state counters
  reg [4:0] dp [0:3];
  reg [4:0] next_dp [0:3];

  // Processing index
  reg [4:0] index, next_index;

  // Current value
  reg [1:0] current_value;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 0;
      max_length <= 0;
      done <= 0;
      dp[0] <= 0;
      dp[1] <= 0;
      dp[2] <= 0;
      dp[3] <= 0;
    end else begin
      state <= next_state;
      index <= next_index;
      dp[0] <= next_dp[0];
      dp[1] <= next_dp[1];
      dp[2] <= next_dp[2];
      dp[3] <= next_dp[3];
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    next_index = index;
    next_dp[0] = dp[0];
    next_dp[1] = dp[1];
    next_dp[2] = dp[2];
    next_dp[3] = dp[3];

    case (state)
      IDLE: begin
        if (start) begin
          next_state = READING;
          next_index = 0;
          next_dp[0] = 0;
          next_dp[1] = 0;
          next_dp[2] = 0;
          next_dp[3] = 0;
          max_length = 0;
          done = 0;
        end
      end

      READING: begin
        if (index < sequence_length) begin
          next_state = PROCESSING;
          next_index = index + 1;
        end else begin
          next_state = DONE;
        end
      end

      PROCESSING: begin
        if (index < sequence_length) begin
          next_state = READING;
        end else begin
          next_state = DONE;
        end
      end

      DONE: begin
        if (start) begin
          next_state = READING;
          next_index = 0;
          next_dp[0] = 0;
          next_dp[1] = 0;
          next_dp[2] = 0;
          next_dp[3] = 0;
          max_length = 0;
          done = 0;
        end
      end
    endcase
  end

  // Current value extraction
  always @(*) begin
    current_value = sequence_data[(index << 1) + 1 : (index << 1)];
  end

  // DP state update logic
  always @(*) begin
    if (state == PROCESSING) begin
      if (current_value == 2'b01) begin // Value 1
        next_dp[0] = dp[0] + 1;
        next_dp[2] = (dp[2] + 1) > (dp[1] + 1) ? (dp[2] + 1) : (dp[1] + 1);
      end else if (current_value == 2'b10) begin // Value 2
        next_dp[1] = (dp[1] + 1) > (dp[0] + 1) ? (dp[1] + 1) : (dp[0] + 1);
        next_dp[3] = (dp[3] + 1) > (dp[2] + 1) ? (dp[3] + 1) : (dp[2] + 1);
      end
    end
  end

  // Max length update
  always @(*) begin
    if (state == PROCESSING || state == DONE) begin
      max_length = dp[0];
      if (dp[1] > max_length) max_length = dp[1];
      if (dp[2] > max_length) max_length = dp[2];
      if (dp[3] > max_length) max_length = dp[3];
    end
  end

  // Done signal
  always @(*) begin
    done = (state == DONE);
  end

endmodule