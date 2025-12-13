module max_frequency (
  input  logic                 clk,
  input  logic                 rst_n,
  input  logic                 start,
  input  logic [15:0][7:0]     data_array,
  output logic [7:0]           result,
  output logic                 done
);

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    COUNT = 2'b01,
    SCAN  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Frequency memory: 256 entries, enough bits to count up to 16 (5 bits)
  logic [4:0] freq_mem [0:255];

  // Counters
  logic [7:0]  scan_idx;       // 0-255 for SCAN
  logic [4:0]  process_cnt;    // 0-15 for COUNT

  // Latched data index & value for counting
  logic [3:0]  data_idx;       // index into 16-element array
  logic [7:0]  data_val;       // current data value from array

  // Track max frequency and corresponding value during SCAN
  logic [4:0]  max_freq;
  logic [7:0]  max_val;

  // Start edge detection
  logic start_d;

  // Sequential logic: state, counters, memories, outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      start_d     <= 1'b0;
      process_cnt <= 5'd0;
      data_idx    <= 4'd0;
      data_val    <= 8'd0;
      scan_idx    <= 8'd0;
      max_freq    <= 5'd0;
      max_val     <= 8'd0;
      result      <= 8'd0;
      done        <= 1'b0;
      // Initialize frequency memory to 0 on reset
      // Synchronous clear for synthesis-friendliness: handled by state machine
      // Here we explicitly clear in reset for simulation; tools may map appropriately
      integer i;
      for (i = 0; i < 256; i = i + 1) begin
        freq_mem[i] <= 5'd0;
      end
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          result      <= result; // hold
          process_cnt <= 5'd0;
          data_idx    <= 4'd0;
          scan_idx    <= 8'd0;
          max_freq    <= 5'd0;
          max_val     <= 8'd0;
          // Clear frequency memory after detecting start edge
          if (!start_d && start) begin
            integer j;
            for (j = 0; j < 256; j = j + 1) begin
              freq_mem[j] <= 5'd0;
            end
          end
        end

        COUNT: begin
          done <= 1'b0;
          // Load current data index and value
          data_idx <= process_cnt[3:0];
          data_val <= data_array[process_cnt[3:0]];

          // Increment the frequency for current data_val
          freq_mem[data_val] <= freq_mem[data_val] + 5'd1;

          // Advance count
          process_cnt <= process_cnt + 5'd1;
        end

        SCAN: begin
          done <= 1'b0;
          // Compare current frequency with max_freq
          if (freq_mem[scan_idx] > max_freq) begin
            max_freq <= freq_mem[scan_idx];
            max_val  <= scan_idx;
          end
          // Advance scan index
          scan_idx <= scan_idx + 8'd1;
        end

        DONE: begin
          done   <= 1'b1;
          result <= max_val;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        // Wait for rising edge of start
        if (!start_d && start)
          next_state = COUNT;
      end

      COUNT: begin
        // After processing 16 elements, move to SCAN
        if (process_cnt == 5'd16)
          next_state = SCAN;
      end

      SCAN: begin
        // After scanning all 256 values, move to DONE
        if (scan_idx == 8'd255)
          next_state = DONE;
      end

      DONE: begin
        // Stay in DONE until start is deasserted, then go back to IDLE
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule