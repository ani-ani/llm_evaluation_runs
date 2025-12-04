module lucky_number_supply(
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [3:0] n,
  output reg [15:0] supply_count,
  output reg done
);

  // Internal signals
  logic [2:0] state;
  logic [2:0] next_state;
  logic [3:0] d1, d2, d3;
  logic [3:0] d1_next, d2_next, d3_next;
  logic [15:0] supply_count_next;
  logic done_next;
  logic start_prev, start_prev_next;
  logic busy, busy_next;
  logic start_latch, start_latch_next;
  logic n_is_3, n_is_3_next;

  // State encoding
  parameter IDLE   = 3'b000;
  parameter GEN_D1 = 3'b001;
  parameter GEN_D2 = 3'b010;
  parameter GEN_D3 = 3'b011;
  parameter DONE   = 3'b100;

  // Edge detection for start
  always_comb begin
    start_prev_next = start;
  end

  // Combinational logic for next state and registers
  always_comb begin
    next_state = state;
    // default next values
    d1_next = d1;
    d2_next = d2;
    d3_next = d3;
    supply_count_next = supply_count;
    done_next = done;
    busy_next = busy;
    start_latch_next = start_latch;
    n_is_3_next = n_is_3;

    case (state)
      IDLE: begin
        if (start & ~start_prev) begin
          if (n == 2) begin
            // n=2: combinatorial result
            start_latch_next = 1'b1;
            next_state = DONE;
          end else if (n == 3) begin
            // n=3: start counting
            busy_next = 1'b1;
            n_is_3_next = 1'b1;
            d1_next = 4'd1;
            d2_next = 4'd0;
            d3_next = 4'd0;
            supply_count_next = 16'h0;
            done_next = 1'b0;
            next_state = GEN_D1;
          end
        end
      end
      DONE: begin
        if (start_latch) begin
          // n=2 path
          supply_count_next = 16'd45;
          done_next = 1'b1;
          start_latch_next = 1'b0;
          busy_next = 1'b0;
          n_is_3_next = 1'b0;
          next_state = IDLE;
        end else begin
          // n=3 path
          if (n_is_3) begin
            done_next = 1'b1;
            busy_next = 1'b0;
            n_is_3_next = 1'b0;
            next_state = IDLE;
          end else begin
            next_state = IDLE;
          end
        end
      end
      GEN_D1: begin
        // Reset inner counters for new d1
        d2_next = 4'd0;
        d3_next = 4'd0;
        next_state = GEN_D2;
      end
      GEN_D2: begin
        // Check (d1*10 + d2) % 2 == 0
        if (((d1 * 10) + d2) % 2 == 0) begin
          // Condition true, go to GEN_D3
          next_state = GEN_D3;
        end else begin
          // Condition false, try next d2
          if (d2 < 4'd9) begin
            d2_next = d2 + 1;
            next_state = GEN_D2;
          end else begin
            // d2 exhausted, go to next d1
            if (d1 < 4'd9) begin
              d1_next = d1 + 1;
              next_state = GEN_D1;
            end else begin
              // all done
              next_state = DONE;
            end
          end
        end
      end
      GEN_D3: begin
        // Check (d1*100 + d2*10 + d3) % 3 == 0
        if (((d1 * 100) + (d2 * 10) + d3) % 3 == 0) begin
          supply_count_next = supply_count + 1;
        end
        // Increment d3
        if (d3 < 4'd9) begin
          d3_next = d3 + 1;
          next_state = GEN_D3;
        end else begin
          d3_next = 4'd0;
          // d3 exhausted, go to next d2
          if (d2 < 4'd9) begin
            d2_next = d2 + 1;
            next_state = GEN_D2;
          end else begin
            d2_next = 4'd0;
            // d2 exhausted, go to next d1
            if (d1 < 4'd9) begin
              d1_next = d1 + 1;
              next_state = GEN_D1;
            end else begin
              // all done
              next_state = DONE;
            end
          end
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      d1 <= 4'h0;
      d2 <= 4'h0;
      d3 <= 4'h0;
      supply_count <= 16'h0;
      done <= 1'b0;
      busy <= 1'b0;
      start_latch <= 1'b0;
      n_is_3 <= 1'b0;
      start_prev <= 1'b0;
    end else begin
      state <= next_state;
      d1 <= d1_next;
      d2 <= d2_next;
      d3 <= d3_next;
      supply_count <= supply_count_next;
      done <= done_next;
      busy <= busy_next;
      start_latch <= start_latch_next;
      n_is_3 <= n_is_3_next;
      start_prev <= start_prev_next;
    end
  end

endmodule
