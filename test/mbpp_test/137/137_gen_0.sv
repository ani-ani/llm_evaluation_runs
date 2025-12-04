module zero_ratio(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  array [0:7],
  output logic [15:0] ratio,
  output logic        done,
  output logic        error
);

  // State machine
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    COUNT = 2'b01,
    DIV   = 2'b10,
    HOLD  = 2'b11
  } state_t;

  state_t state, next_state;

  // Counters and index
  logic [3:0] idx;               // 0..7
  logic [3:0] zeros_cnt;
  logic [3:0] nonzeros_cnt;

  // Internal registers for outputs
  logic [15:0] ratio_r;
  logic        done_r;
  logic        error_r;

  // Output assignments
  assign ratio = ratio_r;
  assign done  = done_r;
  assign error = error_r;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= IDLE;
      idx          <= 4'd0;
      zeros_cnt    <= 4'd0;
      nonzeros_cnt <= 4'd0;
      ratio_r      <= 16'd0;
      done_r       <= 1'b0;
      error_r      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          // Wait for start; clear when new start observed
          if (start) begin
            idx          <= 4'd0;
            zeros_cnt    <= 4'd0;
            nonzeros_cnt <= 4'd0;
            done_r       <= 1'b0;
            error_r      <= 1'b0;
            ratio_r      <= 16'd0;
          end
        end

        COUNT: begin
          // Process current element
          if (array[idx] == 8'sd0)
            zeros_cnt <= zeros_cnt + 4'd1;
          else
            nonzeros_cnt <= nonzeros_cnt + 4'd1;

          // Increment index
          idx <= idx + 4'd1;
        end

        DIV: begin
          // Perform division in a single cycle
          if (nonzeros_cnt == 4'd0) begin
            error_r <= 1'b1;
            ratio_r <= 16'd0;
          end else begin
            error_r <= 1'b0;
            ratio_r <= (zeros_cnt << 8) / nonzeros_cnt;
          end
          done_r <= 1'b1;
        end

        HOLD: begin
          // Hold outputs stable until next start
          if (start) begin
            idx          <= 4'd0;
            zeros_cnt    <= 4'd0;
            nonzeros_cnt <= 4'd0;
            done_r       <= 1'b0;
            error_r      <= 1'b0;
            ratio_r      <= 16'd0;
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
          next_state = COUNT;
      end

      COUNT: begin
        // After processing 8 elements (idx 0..7), move to DIV
        if (idx == 4'd8)
          next_state = DIV;
      end

      DIV: begin
        // Division completes in one cycle, then go to HOLD
        next_state = HOLD;
      end

      HOLD: begin
        // Wait for next start to restart calculation
        if (start)
          next_state = COUNT;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule