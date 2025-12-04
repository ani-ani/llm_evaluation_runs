module max_uppercase_run(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [127:0] str,
  output logic [3:0]  max_run,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    BUSY  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t       state, next_state;
  logic [3:0]   idx;
  logic [3:0]   curr_run;
  logic [3:0]   max_run_r;
  logic [7:0]   ch;
  logic         is_upper;

  // Character extraction
  always_comb begin
    ch = str[(idx*8) +: 8];
  end

  // Uppercase check: ASCII 65 ('A') to 90 ('Z')
  always_comb begin
    is_upper = (ch >= 8'd65) && (ch <= 8'd90);
  end

  // State register and counters
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      idx       <= 4'd0;
      curr_run  <= 4'd0;
      max_run_r <= 4'd0;
      done      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            idx       <= 4'd0;
            curr_run  <= 4'd0;
            max_run_r <= 4'd0;
          end
        end

        BUSY: begin
          // Process one character per cycle
          if (is_upper) begin
            curr_run <= curr_run + 4'd1;
          end else begin
            curr_run <= 4'd0;
          end

          // Update max run
          if (is_upper && (curr_run + 4'd1 > max_run_r)) begin
            max_run_r <= curr_run + 4'd1;
          end

          // Increment index
          idx <= idx + 4'd1;
        end

        DONE: begin
          done <= 1'b1;
          // Hold results until next start
          if (start) begin
            idx       <= 4'd0;
            curr_run  <= 4'd0;
            max_run_r <= 4'd0;
            done      <= 1'b0;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = BUSY;
      end

      BUSY: begin
        // After processing 16 characters (idx from 0 to 15), move to DONE.
        if (idx == 4'd15)
          next_state = DONE;
      end

      DONE: begin
        if (start)
          next_state = BUSY;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output assignment
  assign max_run = max_run_r;

endmodule