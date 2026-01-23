module ks_smooth_min_changes (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [5:0] N,
  input [3:0] K,
  input valid_in,
  output reg ready,
  output reg [7:0] min_changes,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    RECV,
    COMPUTE,
    DONE
  } state_t;

  state_t state;
  reg [5:0] count; // Received element counter
  reg [7:0] data_array [0:63]; // Store input array
  reg [7:0] freq [0:255]; // Frequency counters for mode calculation
  reg [7:0] mode; // Mode value for current group
  reg [7:0] max_freq; // Max frequency for current group
  reg [7:0] group_changes; // Changes for current group
  reg [7:0] total_changes; // Accumulated changes
  reg [2:0] group_idx; // Current group index (0 to K-1)
  reg [7:0] value_idx; // Current value index for mode calculation
  reg [5:0] group_size; // Size of current group

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ready <= 1'b1;
      done <= 1'b0;
      count <= 6'd0;
      min_changes <= 8'd0;
      total_changes <= 8'd0;
      group_idx <= 3'd0;
      value_idx <= 8'd0;
      max_freq <= 8'd0;
      mode <= 8'd0;
      group_changes <= 8'd0;
      group_size <= 6'd0;
    end else begin
      case (state)
        IDLE: begin
          ready <= 1'b1;
          done <= 1'b0;
          if (start) begin
            state <= RECV;
            count <= 6'd0;
            total_changes <= 8'd0;
            group_idx <= 3'd0;
          end
        end
        RECV: begin
          ready <= 1'b1;
          if (valid_in) begin
            data_array[count] <= data_in;
            count <= count + 1'b1;
            if (count == N) begin
              state <= COMPUTE;
              ready <= 1'b0;
              count <= 6'd0;
              group_idx <= 3'd0;
              total_changes <= 8'd0;
            end
          end
        end
        COMPUTE: begin
          ready <= 1'b0;
          done <= 1'b0;
          // Initialize frequency counters for current group
          if (count == 0) begin
            // Reset frequency counters
            for (int i = 0; i < 256; i = i + 1) begin
              freq[i] <= 8'd0;
            end
            max_freq <= 8'd0;
            mode <= 8'd0;
            group_size <= 6'd0;
            // Count elements in current group
            for (int i = 0; i < N; i = i + 1) begin
              if (i % K == group_idx) begin
                freq[data_array[i]] <= freq[data_array[i]] + 1'b1;
                group_size <= group_size + 1'b1;
              end
            end
            count <= 6'd1;
          end else if (count == 1) begin
            // Find mode in frequency counters
            if (value_idx == 0) begin
              max_freq <= freq[0];
              mode <= 8'd0;
              value_idx <= 8'd1;
            end else begin
              if (freq[value_idx] > max_freq) begin
                max_freq <= freq[value_idx];
                mode <= value_idx;
              end
              value_idx <= value_idx + 1'b1;
              if (value_idx == 255) begin
                group_changes <= group_size - max_freq;
                total_changes <= total_changes + group_changes;
                value_idx <= 8'd0;
                count <= 6'd2;
              end
            end
          end else if (count == 2) begin
            // Move to next group
            group_idx <= group_idx + 1'b1;
            if (group_idx == K) begin
              min_changes <= total_changes;
              state <= DONE;
              done <= 1'b1;
            end else begin
              count <= 6'd0;
            end
          end
        end
        DONE: begin
          ready <= 1'b1;
          if (start) begin
            state <= RECV;
            count <= 6'd0;
            done <= 1'b0;
          end
        end
      endcase
    end
  end

endmodule