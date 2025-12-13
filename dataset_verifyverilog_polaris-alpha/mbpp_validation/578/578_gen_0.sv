module list_interleaver(
  input              clk,
  input              rst_n,
  input              start,
  input       [2:0]  list_len,
  input       [7:0][15:0] list1,
  input       [7:0][15:0] list2,
  input       [7:0][15:0] list3,
  output reg [15:0]  data_out,
  output reg         valid,
  output reg         done
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    OUT_L1 = 2'b01,
    OUT_L2 = 2'b10,
    OUT_L3 = 2'b11
  } state_t;

  state_t state, next_state;
  reg [2:0] index, next_index;
  reg [2:0] len_reg, next_len_reg;
  reg       start_d;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      index    <= 3'd0;
      len_reg  <= 3'd0;
      data_out <= 16'd0;
      valid    <= 1'b0;
      done     <= 1'b0;
      start_d  <= 1'b0;
    end else begin
      state   <= next_state;
      index   <= next_index;
      len_reg <= next_len_reg;
      start_d <= start;

      // Outputs registered based on next_state/next_index decisions
      case (next_state)
        IDLE: begin
          valid    <= 1'b0;
          done     <= (state != IDLE) ? 1'b1 : 1'b0; // one-cycle done when returning to IDLE
          data_out <= data_out; // hold
        end

        OUT_L1: begin
          valid    <= 1'b1;
          done     <= 1'b0;
          data_out <= list1[next_index];
        end

        OUT_L2: begin
          valid    <= 1'b1;
          done     <= 1'b0;
          data_out <= list2[next_index];
        end

        OUT_L3: begin
          valid    <= 1'b1;
          done     <= 1'b0;
          data_out <= list3[next_index];
        end

        default: begin
          valid    <= 1'b0;
          done     <= 1'b0;
          data_out <= data_out;
        end
      endcase
    end
  end

  // Next-state and next-index logic
  always @(*) begin
    next_state   = state;
    next_index   = index;
    next_len_reg = len_reg;

    case (state)
      IDLE: begin
        // Capture new length and start processing on start pulse
        if (start && !start_d) begin
          next_len_reg = list_len;
          if (list_len == 3'd0) begin
            // Immediate done: one cycle in IDLE with done asserted via sequential logic
            next_state = IDLE;
            next_index = 3'd0;
          end else begin
            next_index = 3'd0;
            next_state = OUT_L1;
          end
        end
      end

      OUT_L1: begin
        // After L1 of current index, go to L2
        next_state = OUT_L2;
      end

      OUT_L2: begin
        // After L2 of current index, go to L3
        next_state = OUT_L3;
      end

      OUT_L3: begin
        // After L3, advance index; if last index, go back to IDLE (done asserted for one cycle)
        if (index == (len_reg - 1)) begin
          next_state = IDLE;
          next_index = 3'd0;
        end else begin
          next_index = index + 3'd1;
          next_state = OUT_L1;
        end
      end

      default: begin
        next_state = IDLE;
        next_index = 3'd0;
      end
    endcase
  end

endmodule