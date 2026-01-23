module max_polygon_area (
  input clk,
  input rst_n,
  input start,
  input [3:0] segment_length,
  input [2:0] num_segments,
  input load_segment,
  output reg [31:0] max_area,
  output reg done
);

  // Pre-computed constants (Q16.16 format)
  localparam [31:0] TAN_PI_3 = 32'h000093BE; // 37838
  localparam [31:0] TAN_PI_4 = 32'h00010000; // 65536
  localparam [31:0] TAN_PI_5 = 32'h0000BA1E; // 47626
  localparam [31:0] TAN_PI_6 = 32'h000093BE; // 37838
  localparam [31:0] TAN_PI_7 = 32'h00007B44; // 31564
  localparam [31:0] TAN_PI_8 = 32'h00006A08; // 27144

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_SEGMENTS,
    COUNT_FREQ,
    COMPUTE_AREA,
    DONE
  } state_t;

  state_t state, next_state;

  // Segment storage and frequency count
  reg [3:0] segments [0:7];
  reg [3:0] freq [1:10]; // Frequency count for lengths 1-10
  reg [2:0] segment_count;
  reg [2:0] load_index;
  reg [2:0] k; // Current polygon size
  reg [3:0] s; // Current segment length
  reg [31:0] current_area;
  reg [31:0] temp_area;
  reg [2:0] cycle_count;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_area <= 0;
      segment_count <= 0;
      load_index <= 0;
      cycle_count <= 0;
      for (int i = 0; i < 8; i++) segments[i] <= 0;
      for (int i = 1; i <= 10; i++) freq[i] <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_SEGMENTS;
      end
      LOAD_SEGMENTS: begin
        if (load_index == num_segments - 1) next_state = COUNT_FREQ;
      end
      COUNT_FREQ: begin
        next_state = COMPUTE_AREA;
      end
      COMPUTE_AREA: begin
        if (cycle_count == 99) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load segments
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == LOAD_SEGMENTS && load_segment) begin
      segments[load_index] <= segment_length;
      load_index <= load_index + 1;
    end
  end

  // Count frequencies
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == COUNT_FREQ) begin
      for (int i = 1; i <= 10; i++) freq[i] <= 0;
      for (int i = 0; i < num_segments; i++) begin
        if (segments[i] >= 1 && segments[i] <= 10) begin
          freq[segments[i]] <= freq[segments[i]] + 1;
        end
      end
      next_state = COMPUTE_AREA;
    end
  end

  // Compute maximum area
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (state == COMPUTE_AREA) begin
      if (cycle_count == 0) begin
        max_area <= 0;
        k <= 3;
        s <= 1;
      end else begin
        // Compute area for current k and s
        case (k)
          3: temp_area = (3 * s * s * 65536) / (4 * TAN_PI_3);
          4: temp_area = (4 * s * s * 65536) / (4 * TAN_PI_4);
          5: temp_area = (5 * s * s * 65536) / (4 * TAN_PI_5);
          6: temp_area = (6 * s * s * 65536) / (4 * TAN_PI_6);
          7: temp_area = (7 * s * s * 65536) / (4 * TAN_PI_7);
          8: temp_area = (8 * s * s * 65536) / (4 * TAN_PI_8);
        endcase

        // Check if we have enough segments of length s
        if (freq[s] >= k) begin
          if (temp_area > max_area) begin
            max_area <= temp_area;
          end
        end

        // Move to next s or k
        if (s == 10) begin
          s <= 1;
          if (k == 8) begin
            k <= 3;
          end else begin
            k <= k + 1;
          end
        end else begin
          s <= s + 1;
        end
      end

      cycle_count <= cycle_count + 1;
      if (cycle_count == 99) begin
        done <= 1;
      end
    end
  end

  // Reset done signal when leaving DONE state
  always @(posedge clk) begin
    if (!rst_n) begin
      done <= 0;
    end else if (state == DONE && !start) begin
      done <= 0;
    end
  end

endmodule