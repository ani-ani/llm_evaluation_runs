module house_envy_solver(
  input              clk,
  input              rst_n,
  input              start,
  input      [2:0]   n,
  input      [31:0]  k,
  input      [31:0]  h0,
  input      [31:0]  h1,
  input      [31:0]  h2,
  input      [31:0]  h3,
  input      [31:0]  h4,
  input      [31:0]  h5,
  input      [31:0]  h6,
  input      [31:0]  h7,
  output reg [31:0]  max_height,
  output reg         done
);

  // Number of houses = n + 1 (1 to 8)
  wire [3:0] house_cnt = {1'b0, n} + 4'd1; // 1..8

  // Internal storage for current heights
  reg [31:0] h_cur [0:7];
  reg [31:0] h_next[0:7];

  // FSM state encoding
  localparam S_IDLE          = 3'd0;
  localparam S_INIT          = 3'd1;
  localparam S_ITER_UPDATE   = 3'd2;
  localparam S_ITER_NEXT     = 3'd3;
  localparam S_FIND_MAX      = 3'd4;
  localparam S_DONE          = 3'd5;

  reg [2:0]  state, next_state;

  // Counters
  reg [6:0]  iter_cnt;        // up to 100
  reg [3:0]  idx;             // index 0..7
  reg [3:0]  max_idx;         // for max scan

  // Combinational signals for update
  reg [31:0] left_val;
  reg [31:0] right_val;
  reg [32:0] sum33;           // 33-bit sum
  reg [31:0] avg_plus_k;      // Q16.16 after (left+right)/2 + k
  reg [31:0] max_sel;

  // Left and right neighbor selection
  always @* begin
    // default
    left_val  = 32'd0;
    right_val = 32'd0;

    // left neighbor
    if (idx == 4'd0) begin
      left_val = 32'd0;
    end else if (idx < house_cnt) begin
      left_val = h_cur[idx-1];
    end else begin
      left_val = 32'd0;
    end

    // right neighbor
    if (idx + 1 == house_cnt) begin
      // last active house: right neighbor is 0
      right_val = 32'd0;
    end else if (idx + 1 < house_cnt) begin
      right_val = h_cur[idx+1];
    end else begin
      right_val = 32'd0;
    end

    // 33-bit sum
    sum33 = {1'b0, left_val} + {1'b0, right_val};

    // (left+right)/2: right shift by 1 (still Q16.16), then add k
    avg_plus_k = (sum33[32:1]) + k;

    // new_h_i = max(current_h_i, avg_plus_k)
    if (h_cur[idx] >= avg_plus_k)
      max_sel = h_cur[idx];
    else
      max_sel = avg_plus_k;
  end

  // FSM next-state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        next_state = S_ITER_UPDATE;
      end

      S_ITER_UPDATE: begin
        // when we've updated last active house (idx == house_cnt-1)
        if (idx == house_cnt - 1)
          next_state = S_ITER_NEXT;
      end

      S_ITER_NEXT: begin
        if (iter_cnt == 7'd100)
          next_state = S_FIND_MAX;
        else
          next_state = S_ITER_UPDATE;
      end

      S_FIND_MAX: begin
        // after scanning all houses
        if (max_idx == house_cnt - 1)
          next_state = S_DONE;
      end

      S_DONE: begin
        // stay until next start or reset; done stays asserted
        if (start)
          next_state = S_INIT;
      end

      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      iter_cnt   <= 7'd0;
      idx        <= 4'd0;
      max_idx    <= 4'd0;
      max_height <= 32'd0;
      done       <= 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        h_cur[i]  <= 32'd0;
        h_next[i] <= 32'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done       <= 1'b0;
          iter_cnt   <= 7'd0;
          idx        <= 4'd0;
          max_idx    <= 4'd0;
          // no change to h_cur until start
          if (start) begin
            // load initial heights into h_cur
            h_cur[0] <= h0;
            h_cur[1] <= h1;
            h_cur[2] <= h2;
            h_cur[3] <= h3;
            h_cur[4] <= h4;
            h_cur[5] <= h5;
            h_cur[6] <= h6;
            h_cur[7] <= h7;
          end
        end

        S_INIT: begin
          // ensure next iteration starts from idx 0
          idx      <= 4'd0;
          iter_cnt <= 7'd0;
          max_idx  <= 4'd0;
          done     <= 1'b0;
          // initial heights already loaded in previous state when start asserted
        end

        S_ITER_UPDATE: begin
          // compute and store next height for current idx
          if (idx < house_cnt) begin
            h_next[idx] <= max_sel;
          end

          // advance idx within this iteration
          if (idx == house_cnt - 1) begin
            // last active house processed in this iteration
            idx <= 4'd0; // prepare for next state
          end else begin
            idx <= idx + 4'd1;
          end
        end

        S_ITER_NEXT: begin
          // commit h_next to h_cur for all houses in use
          for (i = 0; i < 8; i = i + 1) begin
            if (i < house_cnt)
              h_cur[i] <= h_next[i];
            else
              h_cur[i] <= 32'd0;
          end

          // increment iteration counter
          if (iter_cnt < 7'd100)
            iter_cnt <= iter_cnt + 7'd1;

          // idx already set to 0 in previous state (ITER_UPDATE when done)
        end

        S_FIND_MAX: begin
          // sequential max scan over active houses
          if (max_idx == 4'd0) begin
            max_height <= h_cur[0];
            max_idx    <= (house_cnt > 1) ? 4'd1 : (house_cnt - 1);
          end else if (max_idx < house_cnt) begin
            if (h_cur[max_idx] > max_height)
              max_height <= h_cur[max_idx];
            if (max_idx == house_cnt - 1)
              max_idx <= max_idx; // stay for transition to DONE
            else
              max_idx <= max_idx + 4'd1;
          end
        end

        S_DONE: begin
          done <= 1'b1;
          // hold max_height until next start/reset
          if (start) begin
            // reinitialize for new run
            done       <= 1'b0;
            iter_cnt   <= 7'd0;
            idx        <= 4'd0;
            max_idx    <= 4'd0;
            // reload initial heights
            h_cur[0] <= h0;
            h_cur[1] <= h1;
            h_cur[2] <= h2;
            h_cur[3] <= h3;
            h_cur[4] <= h4;
            h_cur[5] <= h5;
            h_cur[6] <= h6;
            h_cur[7] <= h7;
          end
        end

        default: begin
          // should not occur; safe defaults
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule