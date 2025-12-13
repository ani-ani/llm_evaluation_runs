module factorial_or_sum_list (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  n,
  output logic [7:0][15:0] result_array,
  output logic        done
);

  typedef enum logic [2:0] {
    IDLE          = 3'd0,
    INIT          = 3'd1,
    COMPUTE_EVEN  = 3'd2,
    COMPUTE_ODD   = 3'd3,
    STORE         = 3'd4,
    DONE          = 3'd5
  } state_t;

  state_t state, next_state;

  logic [3:0]  i;           // current index: 1..n
  logic [15:0] temp;        // accumulator for factorial or sum
  logic [7:0]  k;           // loop counter for factorial (2..i)

  logic        start_d;
  logic        start_pulse;

  // Edge detect for start (treat as pulse; compute only on rising edge)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Sequential state and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      i            <= 4'd0;
      temp         <= 16'd0;
      k            <= 8'd0;
      done         <= 1'b0;
      result_array <= '{default:16'd0};
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse && (n != 4'd0)) begin
            // Clear results at the start of a new operation
            result_array <= '{default:16'd0};
            i     <= 4'd1;
            temp  <= 16'd0;
            k     <= 8'd0;
          end
        end

        INIT: begin
          // Initialize for current i based on parity
          if (i[0] == 1'b0) begin
            // EVEN: prepare factorial(i)
            temp <= 16'd1;
            k    <= 8'd2;
          end else begin
            // ODD: prepare sum(1..i) = i*(i+1)/2
            // Computed in COMPUTE_ODD state
            temp <= 16'd0;
            k    <= 8'd0;
          end
        end

        COMPUTE_EVEN: begin
          // Sequential factorial computation: multiply by k each cycle
          if (k <= i[7:0]) begin
            temp <= temp * k;
            k    <= k + 8'd1;
          end
        end

        COMPUTE_ODD: begin
          // Single-cycle compute: i*(i+1)/2
          // Safe within 16 bits for given constraints
          temp <= (i * (i + 4'd1)) >> 1;
        end

        STORE: begin
          // Store result for index i at position i-1
          if (i != 4'd0) begin
            result_array[i-1] <= temp;
          end
          // Prepare for next i in next_state logic
        end

        DONE: begin
          done <= 1'b1;
          // Remain here until next start_pulse takes us back to IDLE
        end

        default: begin
          // Should not occur; safe defaults
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start_pulse && (n != 4'd0)) begin
          next_state = INIT;
        end else begin
          next_state = IDLE;
        end
      end

      INIT: begin
        // Decide next based on parity of i
        if (i[0] == 1'b0) begin
          // EVEN -> factorial
          next_state = COMPUTE_EVEN;
        end else begin
          // ODD -> sum
          next_state = COMPUTE_ODD;
        end
      end

      COMPUTE_EVEN: begin
        // Stay until factorial for i is complete
        if (k > i[7:0]) begin
          next_state = STORE;
        end else begin
          next_state = COMPUTE_EVEN;
        end
      end

      COMPUTE_ODD: begin
        // Single-cycle compute
        next_state = STORE;
      end

      STORE: begin
        if (i >= n) begin
          next_state = DONE;
        end else begin
          next_state = INIT;
        end
      end

      DONE: begin
        // Wait for a new start pulse to begin again
        if (start_pulse && (n != 4'd0)) begin
          next_state = INIT;
        end else begin
          next_state = DONE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Update index i after STORE state
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 4'd0;
    end else begin
      if (state == STORE) begin
        if (i < n) begin
          i <= i + 4'd1;
        end
      end else if (state == DONE) begin
        // Reset i when done; next start_pulse will re-init
        i <= 4'd0;
      end
    end
  end

endmodule
