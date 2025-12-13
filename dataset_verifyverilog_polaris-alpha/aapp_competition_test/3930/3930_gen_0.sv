module love_potion_counter(
  input  clk,
  input  rst_n,
  input  start,
  input  signed [7:0] a [0:7],
  input  signed [7:0] k,
  output reg [15:0] count,
  output reg done
);

  // State encoding
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    PREP_POWERS = 3'd1,
    CALC_PREFIX = 3'd2,
    CHECK_SUMS  = 3'd3,
    WAIT_LAT    = 3'd4,
    DONE_ST     = 3'd5
  } state_t;

  state_t state, next_state;

  // Latency counter (200 cycles from start)
  reg [7:0]  wait_cnt;       // counts up to 200
  reg        started;        // latched start detection

  // Power (k^p) ROM: up to 16 entries, 16-bit signed
  reg signed [15:0] pow_rom [0:15];
  reg [4:0]         pow_count;  // number of valid powers (0..16)
  reg [3:0]         p_idx;      // iterator for powers

  // Prefix sums s[0..8] (since 8 elements, plus s[0]=0)
  reg signed [15:0] prefix [0:8];
  reg [3:0]         pref_idx;   // 0..8

  // Dictionary (16-entry) for previous prefix sums
  reg signed [15:0] dict_sum   [0:15];
  reg [7:0]         dict_count [0:15];
  reg [4:0]         dict_used;        // number of used entries (0..16)

  // Internal signals
  integer i;

  // Start edge / latch control
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      started <= 1'b0;
    end else begin
      if (state == IDLE) begin
        // Latch a pulse of start to trigger sequence
        if (start)
          started <= 1'b1;
        else if (!start)
          started <= 1'b0;
      end else begin
        // Once left IDLE, clear
        started <= 1'b0;
      end
    end
  end

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= IDLE;
    else
      state <= next_state;
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PREP_POWERS;
      end

      PREP_POWERS: begin
        // powers computed in one shot combinational, move on next cycle
        next_state = CALC_PREFIX;
      end

      CALC_PREFIX: begin
        // prefix sums computed in one shot combinational, then move
        next_state = CHECK_SUMS;
      end

      CHECK_SUMS: begin
        // one-shot combinational over fixed small sets
        next_state = WAIT_LAT;
      end

      WAIT_LAT: begin
        if (wait_cnt == 8'd199)
          next_state = DONE_ST;
      end

      DONE_ST: begin
        // hold done until start de-asserted and new start
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic for counters, memories, outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count     <= 16'd0;
      done      <= 1'b0;
      wait_cnt  <= 8'd0;
      pow_count <= 5'd0;
      p_idx     <= 4'd0;
      pref_idx  <= 4'd0;
      dict_used <= 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        pow_rom[i]    <= 16'sd0;
        dict_sum[i]   <= 16'sd0;
        dict_count[i] <= 8'd0;
      end
      for (i = 0; i < 9; i = i + 1) begin
        prefix[i] <= 16'sd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done     <= 1'b0;
          wait_cnt <= 8'd0;
          count    <= 16'd0;
          // Clear supporting structures when new start arrives
          if (start) begin
            pow_count <= 5'd0;
            p_idx     <= 4'd0;
            pref_idx  <= 4'd0;
            dict_used <= 5'd0;
            for (i = 0; i < 16; i = i + 1) begin
              pow_rom[i]    <= 16'sd0;
              dict_sum[i]   <= 16'sd0;
              dict_count[i] <= 8'd0;
            end
            for (i = 0; i < 9; i = i + 1) begin
              prefix[i] <= 16'sd0;
            end
          end
        end

        PREP_POWERS: begin
          // Compute powers of k (k^0..k^15) limited by 16-bit signed range
          // k^0 = 1
          pow_rom[0] <= 16'sd1;

          // Iterative power generation (combinational-style in this cycle)
          // track overflow and count.
          // Use a temp variable through blocking assignments via for-loop
          begin : gen_powers
            reg signed [15:0] cur;
            reg overflow;
            integer j;
            cur      = 16'sd1;
            overflow = 1'b0;
            pow_count = 5'd1; // at least k^0
            for (j = 1; j < 16; j = j + 1) begin
              if (!overflow) begin
                // Multiply and check 16-bit signed overflow
                // Use 32-bit temp
                reg signed [31:0] tmp;
                tmp = cur * k;
                if (tmp > 32'sd32767 || tmp < -32'sd32768) begin
                  overflow = 1'b1;
                end else begin
                  cur = tmp[15:0];
                  pow_rom[j] = cur;
                  pow_count = pow_count + 5'd1;
                end
              end
            end
          end
        end

        CALC_PREFIX: begin
          // Compute prefix sums s[0..8], s[0] = 0
          prefix[0] <= 16'sd0;
          begin : gen_prefix
            integer j;
            reg signed [15:0] acc;
            acc = 16'sd0;
            for (j = 0; j < 8; j = j + 1) begin
              acc = acc + {{8{a[j][7]}}, a[j]};
              prefix[j+1] = acc;
            end
          end
        end

        CHECK_SUMS: begin
          // Dictionary-based counting of segments with sum == k^p
          // Initialize dictionary empty and count zero
          count     <= 16'd0;
          dict_used <= 5'd0;
          for (i = 0; i < 16; i = i + 1) begin
            dict_sum[i]   <= 16'sd0;
            dict_count[i] <= 8'd0;
          end

          // Process prefix sums sequentially over i = 0..8 in this cycle
          begin : process_prefix
            integer i_idx, j_idx, d_idx;
            reg signed [15:0] cur_s;
            reg signed [15:0] target;
            reg found;
            reg [15:0] local_count;

            local_count = 16'd0;

            for (i_idx = 0; i_idx <= 8; i_idx = i_idx + 1) begin
              cur_s = prefix[i_idx];

              // For each power x_j, check if (cur_s - x_j) exists in dict
              for (j_idx = 0; j_idx < pow_count; j_idx = j_idx + 1) begin
                target = cur_s - pow_rom[j_idx];
                // search dictionary
                found = 1'b0;
                for (d_idx = 0; d_idx < dict_used; d_idx = d_idx + 1) begin
                  if (!found && dict_sum[d_idx] == target) begin
                    local_count = local_count + dict_count[d_idx];
                    found = 1'b1;
                  end
                end
              end

              // Insert current prefix sum into dictionary
              // If existing, increment its count; else add new entry
              found = 1'b0;
              for (d_idx = 0; d_idx < dict_used; d_idx = d_idx + 1) begin
                if (!found && dict_sum[d_idx] == cur_s) begin
                  dict_count[d_idx] <= dict_count[d_idx] + 8'd1;
                  found = 1'b1;
                end
              end
              if (!found && dict_used < 16) begin
                dict_sum[dict_used]   <= cur_s;
                dict_count[dict_used] <= 8'd1;
                dict_used             <= dict_used + 5'd1;
              end
            end

            count <= local_count;
          end

          wait_cnt <= 8'd0;
        end

        WAIT_LAT: begin
          // Hold count; increment wait counter until 199
          if (wait_cnt < 8'd199)
            wait_cnt <= wait_cnt + 8'd1;
        end

        DONE_ST: begin
          done <= 1'b1;
          // Hold count stable; wait for new start to return to IDLE via next_state
        end

        default: begin
          // Should not happen; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule