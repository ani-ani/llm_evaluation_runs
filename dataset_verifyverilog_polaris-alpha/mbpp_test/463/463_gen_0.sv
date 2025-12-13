module max_product_subarray(
  input              clk,
  input              rst_n,
  input              start,
  input      [7:0][7:0] arr,
  output reg [15:0]  max_product,
  output reg         done
);

  // Internal signed views of inputs
  wire signed [7:0] arr_s [7:0];
  genvar gi;
  generate
    for (gi = 0; gi < 8; gi = gi + 1) begin : CAST_ARR
      assign arr_s[gi] = arr[gi];
    end
  endgenerate

  // FSM states
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    INIT  = 2'b01,
    CALC  = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  // Index and iteration counter
  reg [3:0] idx;          // 0..7

  // Core tracking registers (signed)
  reg  signed [15:0] max_end;
  reg  signed [15:0] min_end;
  reg  signed [15:0] max_so_far;

  // Temporary products for current element
  reg  signed [15:0] cur_val;
  reg  signed [15:0] prod_max;
  reg  signed [15:0] prod_min;
  reg  signed [15:0] new_max_end;
  reg  signed [15:0] new_min_end;

  // Start edge detection
  reg start_d;
  wire start_pulse = start & ~start_d;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      idx         <= 4'd0;
      max_end     <= 16'sd0;
      min_end     <= 16'sd0;
      max_so_far  <= 16'sd0;
      max_product <= 16'sd0;
      done        <= 1'b0;
      start_d     <= 1'b0;
      cur_val     <= 16'sd0;
      prod_max    <= 16'sd0;
      prod_min    <= 16'sd0;
      new_max_end <= 16'sd0;
      new_min_end <= 16'sd0;
    end else begin
      start_d <= start;
      state   <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            // Prepare for initialization in INIT state
            idx <= 4'd0;
          end
        end

        INIT: begin
          // Initialize using first element
          cur_val    <= {{8{arr_s[0][7]}}, arr_s[0]};
          max_end    <= {{8{arr_s[0][7]}}, arr_s[0]};
          min_end    <= {{8{arr_s[0][7]}}, arr_s[0]};
          max_so_far <= {{8{arr_s[0][7]}}, arr_s[0]};
          idx        <= 4'd1; // next index to process
        end

        CALC: begin
          // Use arr_s[idx] as current element
          cur_val  <= {{8{arr_s[idx][7]}}, arr_s[idx]};

          if (arr_s[idx] == 8'sd0) begin
            // Reset on zero, zero is candidate itself
            new_max_end <= 16'sd1; // as per spec: reset to 1 after zero
            new_min_end <= 16'sd1;
            if (16'sd0 > max_so_far)
              max_so_far <= 16'sd0;
          end else begin
            // Compute products
            prod_max = max_end * cur_val;
            prod_min = min_end * cur_val;

            // new_max_end = max(cur_val, prod_max, prod_min)
            new_max_end = cur_val;
            if (prod_max > new_max_end)
              new_max_end = prod_max;
            if (prod_min > new_max_end)
              new_max_end = prod_min;

            // new_min_end = min(cur_val, prod_max, prod_min)
            new_min_end = cur_val;
            if (prod_max < new_min_end)
              new_min_end = prod_max;
            if (prod_min < new_min_end)
              new_min_end = prod_min;

            // Update global max_so_far
            if (new_max_end > max_so_far)
              max_so_far <= new_max_end;
          end

          // Commit max_end and min_end for next iteration
          max_end <= (arr_s[idx] == 8'sd0) ? 16'sd1 : new_max_end;
          min_end <= (arr_s[idx] == 8'sd0) ? 16'sd1 : new_min_end;

          // Advance index
          if (idx < 4'd7)
            idx <= idx + 4'd1;
        end

        DONE: begin
          // Latch final result, raise done
          max_product <= max_so_far;
          done        <= 1'b1;
        end

        default: begin
          // Should not occur; safe defaults
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic (combinational)
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start_pulse)
          next_state = INIT;
      end

      INIT: begin
        // Move to CALC to start processing remaining elements
        next_state = CALC;
      end

      CALC: begin
        // After processing index 7, go to DONE
        if (idx == 4'd7)
          next_state = DONE;
        else
          next_state = CALC;
      end

      DONE: begin
        // Stay DONE until a new start pulse, then restart
        if (start_pulse)
          next_state = INIT;
        else
          next_state = DONE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule