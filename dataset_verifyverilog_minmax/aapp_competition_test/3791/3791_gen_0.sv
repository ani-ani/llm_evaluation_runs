module permutation_shift_deviation(
  input clk,              // clock
  input rst_n,            // active-low reset
  input start,            // start calculation
  input [3:0] n,          // permutation size (2 ≤ n ≤ 16)
  input [15:0][3:0] p,    // permutation elements (p[0] to p[15])
  output reg [7:0] min_dev,   // minimum deviation (max 16*15=240)
  output reg [3:0] shift_id,  // optimal shift id (0 to n-1)
  output reg done          // high when calculation complete
);

  // State machine
  typedef enum logic [1:0] {IDLE = 2'b00, INIT_CALC = 2'b01, ITERATE = 2'b10, DONE = 2'b11} state_t;
  state_t state, next_state;

  // Counters and control signals
  reg [3:0] shift_cnt;      // current shift being evaluated (0..n-1)
  reg [3:0] next_shift_cnt; // next shift value
  reg [3:0] elem_cnt;       // element index for deviation accumulation (0..n-1)
  reg [3:0] next_elem_cnt;  // next element index
  reg [7:0] dev_cur;        // deviation for current shift
  reg [7:0] next_dev_cur;   // next deviation
  reg [7:0] min_dev_next;   // next min deviation
  reg [3:0] shift_id_next;  // next optimal shift id

  // Control flags
  reg start_reg;
  wire start_pulse;

  // Index computation: idx = (elem + shift) % n
  function [3:0] get_index;
    input [3:0] elem;
    input [3:0] shift;
    input [3:0] n;
    reg [4:0] sum;
  begin
    sum = {1'b0, elem} + {1'b0, shift};
    get_index = sum - n; // at most sum-1; if sum >= n, subtract n once
  end
  endfunction

  // Compute absolute difference
  function [3:0] abs_diff;
    input [3:0] a;
    input [3:0] b;
  begin
    abs_diff = (a >= b) ? (a - b) : (b - a);
  end
  endfunction

  // Capture start edge for one-shot
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_reg <= 1'b0;
    else        start_reg <= start;
  end
  assign start_pulse = start && !start_reg;

  // Sequential state update with async reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      shift_cnt <= 4'd0;
      elem_cnt  <= 4'd0;
      dev_cur   <= 8'd0;
      min_dev   <= 8'd0;
      shift_id  <= 4'd0;
      done      <= 1'b0;
    end else begin
      state     <= next_state;
      shift_cnt <= next_shift_cnt;
      elem_cnt  <= next_elem_cnt;
      dev_cur   <= next_dev_cur;
      min_dev   <= min_dev_next;
      shift_id  <= shift_id_next;
      done      <= (next_state == DONE);
    end
  end

  // Combinational next-state logic
  always_comb begin
    // Defaults (avoid latches)
    next_state     = state;
    next_shift_cnt = shift_cnt;
    next_elem_cnt  = elem_cnt;
    next_dev_cur   = dev_cur;
    min_dev_next   = min_dev;
    shift_id_next  = shift_id;

    case (state)
      IDLE: begin
        if (start_pulse) begin
          // Initialize calculation for shift 0
          next_state      = INIT_CALC;
          next_shift_cnt  = 4'd0;      // shift_id = 0
          next_elem_cnt   = 4'd0;      // start accumulating from element 0
          next_dev_cur    = 8'd0;
          min_dev_next    = 8'd255;    // start with large value
          shift_id_next   = 4'd0;
        end
      end

      INIT_CALC: begin
        // Compute deviation for current shift (shift_cnt) across all n elements
        if (elem_cnt < n) begin
          // Accumulate deviation across permutation elements
          // element index with cyclic shift
          next_elem_cnt = elem_cnt + 1'b1;
          next_dev_cur  = dev_cur + abs_diff(p[get_index(elem_cnt, shift_cnt, n)], (elem_cnt + 1));
        end else begin
          // Finished accumulating for this shift
          // On first shift (shift_cnt==0), initialize min_dev and shift_id
          if (shift_cnt == 4'd0) begin
            min_dev_next   = dev_cur;
            shift_id_next  = 4'd0;
          end else begin
            // Update min deviation and shift id if better
            if (dev_cur < min_dev) begin
              min_dev_next   = dev_cur;
              shift_id_next  = shift_cnt;
            end
          end

          if (shift_cnt < (n - 1)) begin
            // Move to next shift (one shift per cycle after init)
            next_state      = ITERATE;
            next_shift_cnt  = shift_cnt + 1'b1;
            next_elem_cnt   = 4'd0;
            next_dev_cur    = 8'd0;
          end else begin
            // All shifts processed
            next_state      = DONE;
          end
        end
      end

      ITERATE: begin
        // Compute deviation for remaining shifts (1 to n-1)
        if (elem_cnt < n) begin
          next_elem_cnt = elem_cnt + 1'b1;
          next_dev_cur  = dev_cur + abs_diff(p[get_index(elem_cnt, shift_cnt, n)], (elem_cnt + 1));
        end else begin
          // Completed current shift; update min if necessary
          if (dev_cur < min_dev) begin
            min_dev_next   = dev_cur;
            shift_id_next  = shift_cnt;
          end

          if (shift_cnt < (n - 1)) begin
            // Continue to next shift
            next_shift_cnt = shift_cnt + 1'b1;
            next_elem_cnt  = 4'd0;
            next_dev_cur   = 8'd0;
            // Remain in ITERATE
          end else begin
            // Finished all shifts
            next_state = DONE;
          end
        end
      end

      DONE: begin
        // Hold done=1 for one cycle; return to IDLE when start is deasserted
        if (!start_pulse) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule
