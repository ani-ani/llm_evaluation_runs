module sum_subarray_prod (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [3:0]  element [7:0],
  input  logic [2:0]  arr_len,
  output logic [31:0] result,
  output logic        done
);

  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    COMPUTE = 2'b01,
    DONE_ST = 2'b10
  } state_t;

  state_t        state, next_state;
  logic [31:0]   ans, res;
  logic [31:0]   incr;
  logic [2:0]    idx;
  logic [2:0]    start_idx;
  logic [2:0]    arr_len_r;

  // Combinational next-state logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start && (arr_len != 3'd0)) begin
          next_state = COMPUTE;
        end
      end
      COMPUTE: begin
        if (idx == 3'd0) begin
          next_state = DONE_ST;
        end
      end
      DONE_ST: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      ans        <= 32'd0;
      res        <= 32'd0;
      result     <= 32'd0;
      done       <= 1'b0;
      idx        <= 3'd0;
      start_idx  <= 3'd0;
      arr_len_r  <= 3'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done      <= 1'b0;
          result    <= 32'd0;
          ans       <= 32'd0;
          res       <= 32'd0;
          if (start && (arr_len != 3'd0)) begin
            arr_len_r <= arr_len;
            start_idx <= arr_len - 3'd1; // last valid index
            idx       <= arr_len - 3'd1;
          end
        end

        COMPUTE: begin
          // incr = element[idx] * (1 + res)
          incr <= element[idx] * (32'd1 + res);
          // Use blocking assignments to ensure sequential dependency within the clocked step
          ans  <= ans + (element[idx] * (32'd1 + res));
          res  <= (element[idx] * (32'd1 + res));

          if (idx != 3'd0) begin
            idx <= idx - 3'd1;
          end
        end

        DONE_ST: begin
          done   <= 1'b1;
          result <= ans;
          // hold values until next start deasserted and FSM returns to IDLE
        end

        default: begin
          // Should not occur; safe defaults
          done   <= 1'b0;
          result <= 32'd0;
        end
      endcase
    end
  end

endmodule