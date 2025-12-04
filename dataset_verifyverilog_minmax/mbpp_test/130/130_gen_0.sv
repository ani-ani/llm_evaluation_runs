module max_frequency (
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] data_array,
  output reg [7:0] result,
  output reg done
);

  // Frequency count memory: 256 entries x 5 bits (0..16)
  reg [4:0] freq_mem [0:255];
  reg [7:0] freq_addr;
  reg [4:0] freq_din, freq_dout;
  reg freq_we;

  // FSM state
  typedef enum logic [2:0] {IDLE=0, COUNT=1, SCAN=2, DONE=3} state_t;
  state_t state;

  // Control counters
  reg [8:0] count_idx;     // 0..271 (total 272 cycles after start)
  reg [7:0] scan_idx;      // 0..255 for scanning phase
  reg [7:0] cur_data;      // Current data_array element being processed
  reg [4:0] cur_count;     // Count read from memory
  reg [4:0] next_count;    // Incremented count
  reg [7:0] max_index;     // Current value with max frequency (first occurrence on tie)
  reg [4:0] max_count;     // Current max count
  reg [4:0] next_max_count;
  reg [7:0] next_result;
  reg start_re;

  // Single-port RAM behavior (write-first when WE=1)
  always_ff @(posedge clk) begin
    if (freq_we) begin
      freq_mem[freq_addr] <= freq_din;
      freq_dout <= freq_din;
    end else begin
      freq_dout <= freq_mem[freq_addr];
    end
  end

  // Edge detection for start (synchronous to clk)
  always_ff @(posedge clk) begin
    start_re <= start;
  end
  wire start_pulse = start && !start_re;

  // Main control FSM
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count_idx <= 9'd0;
      scan_idx <= 8'd0;
      freq_we <= 1'b0;
      freq_addr <= 8'd0;
      freq_din <= 5'd0;
      cur_data <= 8'd0;
      cur_count <= 5'd0;
      next_count <= 5'd0;
      max_index <= 8'd0;
      max_count <= 5'd0;
      next_max_count <= 5'd0;
      next_result <= 8'd0;
    end else begin
      // Defaults (combinational-like within FF)
      freq_we <= 1'b0;
      freq_din <= 5'd0;
      next_count <= cur_count + 1'b1;
      next_max_count <= max_count;

      case (state)
        IDLE: begin
          if (start_pulse) begin
            state <= COUNT;
            count_idx <= 9'd0;  // Start counting for 272 cycles (0..271)
          end
        end

        COUNT: begin
          if (count_idx < 9'd255) begin
            // Initialize frequency memory to 0
            freq_addr <= count_idx[7:0];
            freq_we <= 1'b1;
            freq_din <= 5'd0;
            count_idx <= count_idx + 1'b1;
          end else begin
            // Process data_array[0..15]
            if (count_idx < 9'd271) begin
              cur_data <= data_array[count_idx - 9'd256];
              freq_addr <= data_array[count_idx - 9'd256];
              freq_we <= 1'b1;                  // Write-back incremented count
              freq_din <= cur_count + 1'b1;     // Incremented next cycle
              count_idx <= count_idx + 1'b1;
            end else begin
              // Start scan phase; hold last incremented value in memory
              state <= SCAN;
              scan_idx <= 8'd0;
              max_index <= 8'd0;
              max_count <= 5'd0;
            end
          end
        end

        SCAN: begin
          if (scan_idx < 8'd255) begin
            // Read next frequency and compare
            freq_addr <= scan_idx + 1'b1;
            if (freq_dout > max_count) begin
              next_max_count <= freq_dout;
              max_index <= scan_idx + 1'b1;
            end
            scan_idx <= scan_idx + 1'b1;
          end else begin
            // Final comparison for index 255 (no new read needed)
            if (freq_dout > max_count) begin
              next_max_count <= freq_dout;
              next_result <= 8'd255;
            end else begin
              next_max_count <= max_count;
              next_result <= max_index;
            end
            state <= DONE;
          end
        end

        DONE: begin
          // Hold until start_pulse restarts the process
          if (!start_pulse) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

  // Registered outputs
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 8'd0;
      done <= 1'b0;
    end else begin
      if (state == DONE) begin
        result <= next_result;
        done <= 1'b1;
      end else begin
        result <= 8'd0;
        done <= 1'b0;
      end
    end
  end
endmodule
