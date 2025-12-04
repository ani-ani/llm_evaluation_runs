module shortest_subarray_finder(
  input clk,
  input rst_n,
  input start,
  input [2:0] query_type,  // 0=update, 1=query
  input [2:0] position,    // 0-7
  input [1:0] value,       // 1-4
  output reg [3:0] result, // subarray length (0-8, 15=-1)
  output reg done
);

  // Parameters
  localparam N = 8;
  localparam K = 4;

  // Internal storage
  reg [1:0] arr [0:N-1];

  // FSM states
  typedef enum logic [2:0] {
    S_IDLE        = 3'd0,
    S_UPDATE      = 3'd1,
    S_QUERY_INIT  = 3'd2,
    S_QUERY_PROC  = 3'd3,
    S_LATENCY     = 3'd4,
    S_DONE        = 3'd5
  } state_t;

  state_t state, next_state;

  // Registers
  reg [2:0] query_type_latched;
  reg [2:0] position_latched;
  reg [1:0] value_latched;

  reg [3:0] latency_cnt;           // count to 9, so result valid 10 cycles after start

  // Sliding window counters
  reg [2:0] left, right;          // indices 0..7
  reg [3:0] cnt1, cnt2, cnt3, cnt4; // counts of values 1..4 within window
  reg [3:0] best_len;             // minimal length found

  // Helper wires
  wire window_valid;
  assign window_valid = (cnt1 > 0) && (cnt2 > 0) && (cnt3 > 0) && (cnt4 > 0);

  // Synchronous state and registers
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      query_type_latched <= 3'd0;
      position_latched   <= 3'd0;
      value_latched      <= 2'd0;
      latency_cnt        <= 4'd0;
      left               <= 3'd0;
      right              <= 3'd0;
      cnt1               <= 4'd0;
      cnt2               <= 4'd0;
      cnt3               <= 4'd0;
      cnt4               <= 4'd0;
      best_len           <= 4'hF; // 15 indicates no valid subarray
      result             <= 4'h0;
      done               <= 1'b0;
      // Initialize array to all 1s
      for (i = 0; i < N; i = i + 1) begin
        arr[i] <= 2'd1;
      end
    end else begin
      state <= next_state;

      // Default outputs each cycle
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs on start
            query_type_latched <= query_type;
            position_latched   <= position;
            value_latched      <= value;
          end
        end

        S_UPDATE: begin
          // Perform update in 1 cycle after start
          // position assumed valid 0..7
          arr[position_latched] <= value_latched;
        end

        S_QUERY_INIT: begin
          // Initialize sliding window search
          left     <= 3'd0;
          right    <= 3'd0;
          cnt1     <= 4'd0;
          cnt2     <= 4'd0;
          cnt3     <= 4'd0;
          cnt4     <= 4'd0;
          best_len <= 4'hF; // no subarray yet
        end

        S_QUERY_PROC: begin
          // Sliding window over at most N cycles (N=8)
          // Step order:
          // 1) Expand right if possible
          // 2) Try shrink from left if window valid

          if (right < N) begin
            // Include arr[right]
            case (arr[right])
              2'd1: cnt1 <= cnt1 + 1'b1;
              2'd2: cnt2 <= cnt2 + 1'b1;
              2'd3: cnt3 <= cnt3 + 1'b1;
              2'd4: cnt4 <= cnt4 + 1'b1;
              default: ;
            endcase
            right <= right + 1'b1;
          end else begin
            // Right is at N; only shrink if window valid, else search is done
            if (window_valid) begin
              // Try to shrink from left
              if ((right - left) < best_len)
                best_len <= (right - left);

              case (arr[left])
                2'd1: if (cnt1 != 0) cnt1 <= cnt1 - 1'b1;
                2'd2: if (cnt2 != 0) cnt2 <= cnt2 - 1'b1;
                2'd3: if (cnt3 != 0) cnt3 <= cnt3 - 1'b1;
                2'd4: if (cnt4 != 0) cnt4 <= cnt4 - 1'b1;
                default: ;
              endcase
              left <= left + 1'b1;
            end
          end

          // Additional shrink step within same cycle after potential expand
          if (window_valid) begin
            // Shrink while still valid
            // Note: one-step shrink per cycle for simplicity
            if ((right - left) < best_len)
              best_len <= (right - left);

            case (arr[left])
              2'd1: if (cnt1 != 0) cnt1 <= cnt1 - 1'b1;
              2'd2: if (cnt2 != 0) cnt2 <= cnt2 - 1'b1;
              2'd3: if (cnt3 != 0) cnt3 <= cnt3 - 1'b1;
              2'd4: if (cnt4 != 0) cnt4 <= cnt4 - 1'b1;
              default: ;
            endcase
            left <= left + 1'b1;
          end
        end

        S_LATENCY: begin
          // Wait until 10 cycles after start before asserting done
          latency_cnt <= latency_cnt + 1'b1;
        end

        S_DONE: begin
          done <= 1'b1; // single-cycle done pulse
        end

        default: ;
      endcase
    end
  end

  // Next-state logic and result update
  always @(*) begin
    next_state = state;

    case (state)
      S_IDLE: begin
        if (start) begin
          if (query_type == 3'd0) begin
            next_state = S_UPDATE;
          end else begin
            next_state = S_QUERY_INIT;
          end
        end
      end

      S_UPDATE: begin
        // For update: 1 cycle operation, then latency to meet 10-cycle requirement
        next_state = S_LATENCY;
      end

      S_QUERY_INIT: begin
        next_state = S_QUERY_PROC;
      end

      S_QUERY_PROC: begin
        // Finish query once right reached N and no more valid shrink
        if ( (right == N) && (!window_valid) ) begin
          next_state = S_LATENCY;
        end
      end

      S_LATENCY: begin
        // When latency_cnt reaches 9, we've had 10 cycles since start
        if (latency_cnt == 4'd9) begin
          next_state = S_DONE;
        end
      end

      S_DONE: begin
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Result register update (sequential, tied to transitions)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result      <= 4'h0;
      latency_cnt <= 4'd0;
    end else begin
      case (state)
        S_IDLE: begin
          latency_cnt <= 4'd0;
        end
        S_UPDATE: begin
          // Result not meaningful for update; can set to 0
          result      <= 4'h0;
          latency_cnt <= 4'd0;
        end
        S_QUERY_PROC: begin
          // result not finalized here
        end
        S_LATENCY: begin
          // On entering LATENCY from QUERY_PROC, finalize result once
          if (latency_cnt == 4'd0) begin
            // Determine final best_len for query
            if (best_len == 4'hF) begin
              // no valid subarray
              result <= 4'hF;
            end else begin
              result <= best_len;
            end
          end
        end
        S_DONE: begin
          // Hold result as already set
        end
        default: ;
      endcase
    end
  end

endmodule
