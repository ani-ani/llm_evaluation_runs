module sum_non_repeated (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  data [0:15],
  input  logic [3:0]  length,
  output logic [15:0] sum,
  output logic        done
);

  // 256-entry frequency table, 8-bit counters
  logic [7:0] freq [0:255];

  // State machine encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CLEAR = 2'b01,
    COUNT = 2'b10,
    WAITD = 2'b11
  } state_t;

  state_t state, next_state;

  // Counters and registers
  logic [7:0]  clear_idx;      // 0..255 for clearing freq
  logic [3:0]  data_idx;       // 0..15 for data indexing
  logic [7:0]  wait_counter;   // to generate fixed 20-cycle latency
  logic [15:0] sum_reg;
  logic [3:0]  length_latched;

  // Output assigns
  assign sum  = sum_reg;
  assign done = (state == WAITD) && (wait_counter == 8'd19);

  // Next-state and control logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CLEAR;
      end

      CLEAR: begin
        if (clear_idx == 8'd255)
          next_state = COUNT;
      end

      COUNT: begin
        // When all elements processed (or length==0), go to WAITD
        if (data_idx == length_latched)
          next_state = WAITD;
      end

      WAITD: begin
        // Fixed 20-cycle latency in this state
        if (wait_counter == 8'd19)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      clear_idx       <= 8'd0;
      data_idx        <= 4'd0;
      wait_counter    <= 8'd0;
      sum_reg         <= 16'd0;
      length_latched  <= 4'd0;
      // Clear frequency table on reset
      for (int i = 0; i < 256; i++) begin
        freq[i] <= 8'd0;
      end
    end
    else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Wait for start, prepare for new computation
          if (start) begin
            clear_idx      <= 8'd0;
            data_idx       <= 4'd0;
            sum_reg        <= 16'd0;
            wait_counter   <= 8'd0;
            length_latched <= length; // latch length at start
          end
        end

        CLEAR: begin
          // Clear one frequency entry per cycle
          freq[clear_idx] <= 8'd0;
          if (clear_idx != 8'd255)
            clear_idx <= clear_idx + 8'd1;
        end

        COUNT: begin
          // Count frequencies and accumulate sum of elements that appear exactly once
          if (data_idx < length_latched) begin
            logic [7:0] val;
            logic [7:0] prev_cnt;
            val      = data[data_idx];
            prev_cnt = freq[val];

            // Update frequency
            freq[val] <= prev_cnt + 8'd1;

            // Sum update rules:
            //  - If prev_cnt == 0: first occurrence, add value
            //  - If prev_cnt == 1: second occurrence, subtract value (no longer unique)
            //  - Otherwise: no change
            if (prev_cnt == 8'd0) begin
              sum_reg <= sum_reg + val;
            end
            else if (prev_cnt == 8'd1) begin
              sum_reg <= sum_reg - val;
            end

            data_idx <= data_idx + 4'd1;
          end
        end

        WAITD: begin
          // Hold sum_reg stable, count to fixed latency, done is combinational
          if (wait_counter != 8'd19) begin
            wait_counter <= wait_counter + 8'd1;
          end
        end

        default: ;
      endcase
    end
  end

endmodule
