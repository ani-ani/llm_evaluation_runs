module debate_selector(
  input clk,
  input rst_n,
  input start,
  input [1:0] view_in,
  input [12:0] influence_in,
  input valid_in,
  output reg [12:0] max_influence,
  output reg done
);

  // Storage for up to 8 entries
  reg [1:0]  view_mem [0:7];
  reg [12:0] infl_mem [0:7];
  reg [3:0]  cnt;           // number of collected spectators (0-8)

  // FSM states
  localparam S_IDLE     = 3'd0;
  localparam S_COLLECT  = 3'd1;
  localparam S_PREP     = 3'd2;
  localparam S_ENUM     = 3'd3;
  localparam S_DONE     = 3'd4;

  reg [2:0] state, next_state;

  // internal registers
  reg [5:0] cycle_cnt;       // to guarantee done within 50 cycles
  reg [7:0] subset_mask;     // current subset during enumeration
  reg [12:0] best_infl;

  // classification counts for initial strategy (not strictly required for exhaustive search,
  // but kept for clarity/possible optimization)
  integer i;

  // synchronous state and storage updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      cnt          <= 4'd0;
      cycle_cnt    <= 6'd0;
      done         <= 1'b0;
      max_influence<= 13'd0;
      best_infl    <= 13'd0;
      subset_mask  <= 8'd0;
    end else begin
      state     <= next_state;

      // cycle counter: counts in non-IDLE/non-DONE while processing
      if (state == S_IDLE && next_state == S_COLLECT) begin
        cycle_cnt <= 6'd0;
      end else if (state != S_IDLE && state != S_DONE) begin
        cycle_cnt <= cycle_cnt + 6'd1;
      end else if (state == S_DONE && next_state == S_IDLE) begin
        cycle_cnt <= 6'd0;
      end

      done <= 1'b0; // default, will be pulsed in S_DONE

      case (state)
        S_IDLE: begin
          cnt          <= 4'd0;
          best_infl    <= 13'd0;
          max_influence<= 13'd0;
          subset_mask  <= 8'd0;
          if (valid_in && cnt < 4'd8) begin
            // allow capture if someone drives valid before start, while idle
            view_mem[cnt] <= view_in;
            infl_mem[cnt] <= influence_in;
            cnt <= cnt + 4'd1;
          end
        end

        S_COLLECT: begin
          // Collect up to 8 spectators while start not asserted
          if (valid_in && cnt < 4'd8) begin
            view_mem[cnt] <= view_in;
            infl_mem[cnt] <= influence_in;
            cnt <= cnt + 4'd1;
          end
        end

        S_PREP: begin
          // Initialize enumeration
          best_infl   <= 13'd0;
          subset_mask <= 8'd0;
        end

        S_ENUM: begin
          // Enumerate all subsets of collected spectators
          // For N spectators, we only consider masks up to (1<<N)-1
          if (cnt == 0) begin
            // no spectators, best_infl remains 0
            subset_mask <= 8'hFF; // force completion
          end else begin
            // Evaluate current subset_mask if within range
            if (subset_mask < (8'd1 << cnt)) begin
              // compute total influence and support counts
              reg [4:0] total;
              reg [4:0] supA;
              reg [4:0] supB;
              reg [12:0] sum_infl;
              integer j;
              total    = 5'd0;
              supA     = 5'd0;
              supB     = 5'd0;
              sum_infl = 13'd0;

              for (j = 0; j < 8; j = j + 1) begin
                if (j < cnt) begin
                  if (subset_mask[j]) begin
                    total    = total + 5'd1;
                    sum_infl = sum_infl + infl_mem[j];
                    // view: [1] -> Alice supporter, [0] -> Bob supporter
                    if (view_mem[j][1]) supA = supA + 5'd1;
                    if (view_mem[j][0]) supB = supB + 5'd1;
                  end
                end
              end

              // Check constraints: 2*supA >= total && 2*supB >= total
              if ((total != 0) && ((supA << 1) >= total) && ((supB << 1) >= total)) begin
                if (sum_infl > best_infl)
                  best_infl <= sum_infl;
              end

              subset_mask <= subset_mask + 8'd1;
            end else begin
              // reached beyond max subset, keep mask saturated to exit
              subset_mask <= subset_mask;
            end
          end
        end

        S_DONE: begin
          // Latch best_infl to output and pulse done
          max_influence <= best_infl; // if no valid subset, best_infl will be 0
          done          <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          // start with whatever has been collected so far
          next_state = S_PREP;
        end else if (valid_in) begin
          next_state = S_COLLECT;
        end else begin
          next_state = S_IDLE;
        end
      end

      S_COLLECT: begin
        if (start) begin
          next_state = S_PREP;
        end else begin
          next_state = S_COLLECT;
        end
      end

      S_PREP: begin
        next_state = S_ENUM;
      end

      S_ENUM: begin
        if (cnt == 0) begin
          // no spectators, finish immediately
          next_state = S_DONE;
        end else if (subset_mask >= (8'd1 << cnt)) begin
          // finished enumeration
          next_state = S_DONE;
        end else if (cycle_cnt >= 6'd49) begin
          // timeout safeguard: force finish by 50 cycles
          next_state = S_DONE;
        end else begin
          next_state = S_ENUM;
        end
      end

      S_DONE: begin
        // One cycle pulse of done, then go back to idle
        if (start) begin
          // if a new start comes immediately, remain ready: clear and wait for data
          next_state = S_PREP;
        end else begin
          next_state = S_IDLE;
        end
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

endmodule