module min_subsegment_removal (
  input clk,
  input rst_n,
  input start,
  input [2:0] n_in,
  input [7:0] arr_in,
  output reg [3:0] result,
  output reg done
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD,
    INIT_DISTINCT,
    LOOP_L,
    CHECK_R,
    UPDATE_RESULT,
    DONE
  } state_t;

  state_t state = IDLE;
  reg [2:0] n = 0;
  reg [7:0] arr [0:7];
  reg [2:0] l = 0;
  reg [2:0] r = 0;
  reg [2:0] min_len = 8;
  reg [7:0] freq [0:255];
  reg [2:0] i = 0;
  reg [2:0] j = 0;
  reg [2:0] k = 0;
  reg [2:0] count = 0;
  reg [2:0] load_idx = 0;
  reg has_duplicate = 0;

  // Initialize frequency array
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n <= 0;
      load_idx <= 0;
      result <= 0;
      done <= 0;
      for (i = 0; i < 256; i = i + 1) begin
        freq[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= LOAD;
            n <= n_in;
            load_idx <= 0;
          end
        end
        LOAD: begin
          if (load_idx < n) begin
            arr[load_idx] <= arr_in;
            load_idx <= load_idx + 1;
          end else begin
            state <= INIT_DISTINCT;
            l <= n - 1;
            r <= n - 1;
            min_len <= 8;
          end
        end
        INIT_DISTINCT: begin
          // Initialize frequency array
          for (i = 0; i < 256; i = i + 1) begin
            freq[i] <= 0;
          end
          state <= LOOP_L;
        end
        LOOP_L: begin
          if (l >= 0) begin
            state <= CHECK_R;
            r <= n - 1;
          end else begin
            state <= DONE;
          end
        end
        CHECK_R: begin
          if (r >= l) begin
            // Check if remaining elements are distinct
            has_duplicate <= 0;
            // Reset frequency array
            for (i = 0; i < 256; i = i + 1) begin
              freq[i] <= 0;
            end
            // Check elements before l
            for (i = 0; i < l; i = i + 1) begin
              if (freq[arr[i]] > 0) begin
                has_duplicate <= 1;
              end else begin
                freq[arr[i]] <= freq[arr[i]] + 1;
              end
            end
            // Check elements after r
            for (i = r + 1; i < n; i = i + 1) begin
              if (freq[arr[i]] > 0) begin
                has_duplicate <= 1;
              end else begin
                freq[arr[i]] <= freq[arr[i]] + 1;
              end
            end
            if (!has_duplicate) begin
              state <= UPDATE_RESULT;
            end else begin
              r <= r - 1;
            end
          end else begin
            l <= l - 1;
            state <= LOOP_L;
          end
        end
        UPDATE_RESULT: begin
          if ((r - l + 1) < min_len) begin
            min_len <= r - l + 1;
          end
          r <= r - 1;
          state <= CHECK_R;
        end
        DONE: begin
          result <= min_len;
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule