module max_zebra_length(
  input clk,
  input rst_n,
  input start,
  input [15:0] data_in,
  input [3:0] data_len,
  output reg [4:0] max_streak,
  output reg done
);

  // State encoding
  localparam IDLE             = 2'b00;
  localparam PROCESS_FORWARD  = 2'b01;
  localparam PROCESS_BACKWARD = 2'b10;
  localparam COMPLETE         = 2'b11;

  reg [1:0] state, next_state;

  // Internal registers
  reg [3:0] idx_f;            // forward index
  reg [3:0] idx_b;            // backward index
  reg [4:0] curr_streak;      // current streak in forward pass
  reg [4:0] forward_max;      // max streak in forward pass
  reg [4:0] init_streak;      // initial streak from start
  reg [4:0] end_streak;       // ending streak from end
  reg       prev_bit;         // previous bit for zebra check
  reg       first_bit;        // data[0]
  reg       last_bit;         // data[data_len-1]
  reg       need_backward;    // whether backward pass is needed

  // Synchronous state and registers
  always @(posedge clk) begin
    if (!rst_n) begin
      state        <= IDLE;
      idx_f        <= 4'd0;
      idx_b        <= 4'd0;
      curr_streak  <= 5'd0;
      forward_max  <= 5'd0;
      init_streak  <= 5'd0;
      end_streak   <= 5'd0;
      prev_bit     <= 1'b0;
      first_bit    <= 1'b0;
      last_bit     <= 1'b0;
      need_backward<= 1'b0;
      max_streak   <= 5'd0;
      done         <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Initialize for forward pass
            idx_f        <= 4'd0;
            idx_b        <= 4'd0;
            curr_streak  <= 5'd0;
            forward_max  <= 5'd0;
            init_streak  <= 5'd0;
            end_streak   <= 5'd0;
            need_backward<= 1'b0;
            max_streak   <= 5'd0;
            if (data_len != 4'd0) begin
              first_bit <= data_in[0];
              last_bit  <= data_in[data_len-1];
            end else begin
              first_bit <= 1'b0;
              last_bit  <= 1'b0;
            end
          end
        end

        PROCESS_FORWARD: begin
          if (idx_f < data_len) begin
            if (idx_f == 4'd0) begin
              // First character initializes streaks
              prev_bit     <= data_in[0];
              curr_streak  <= 5'd1;
              forward_max  <= 5'd1;
              init_streak  <= 5'd1;
              idx_f        <= idx_f + 4'd1;
            end else begin
              // Zebra continuation check
              if (data_in[idx_f] != prev_bit) begin
                curr_streak <= curr_streak + 5'd1;
              end else begin
                curr_streak <= 5'd1;
              end

              // Update max streak
              if (curr_streak + ((data_in[idx_f] != prev_bit) ? 5'd1 : -5'sd0) > forward_max)
                forward_max <= curr_streak + ((data_in[idx_f] != prev_bit) ? 5'd1 : -5'sd0);

              // Track initial streak (only while strictly alternating from start)
              if (init_streak == idx_f && data_in[idx_f] != data_in[idx_f-1]) begin
                init_streak <= init_streak + 5'd1;
              end

              prev_bit <= data_in[idx_f];
              idx_f    <= idx_f + 4'd1;
            end
          end
        end

        PROCESS_BACKWARD: begin
          if (need_backward) begin
            if (idx_b == 4'd0) begin
              // Start from last index (data_len-1)
              idx_b      <= data_len - 4'd1;
              end_streak <= 5'd1;
              prev_bit   <= data_in[data_len-1];
            end else if (idx_b > 4'd0) begin
              idx_b <= idx_b - 4'd1;
              if (data_in[idx_b-1] != prev_bit) begin
                end_streak <= end_streak + 5'd1;
              end else begin
                // Stop when zebra breaks; no need to continue
                idx_b <= 4'd0;
              end
              prev_bit <= data_in[idx_b-1];
            end
          end
        end

        COMPLETE: begin
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next-state and combinational result logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start && (data_len != 4'd0))
          next_state = PROCESS_FORWARD;
        else if (start && (data_len == 4'd0))
          next_state = COMPLETE;
      end

      PROCESS_FORWARD: begin
        if (idx_f >= data_len && data_len != 4'd0) begin
          // Decide if backward pass needed
          if (first_bit != last_bit)
            next_state = PROCESS_BACKWARD;
          else
            next_state = COMPLETE;
        end
      end

      PROCESS_BACKWARD: begin
        if (!need_backward)
          next_state = COMPLETE;
      end

      COMPLETE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Control for backward requirement and final max computation
  always @(posedge clk) begin
    if (!rst_n) begin
      need_backward <= 1'b0;
    end else begin
      // Decide need_backward right after forward pass ends
      if (state == PROCESS_FORWARD && next_state == PROCESS_BACKWARD) begin
        need_backward <= 1'b1;
      end else if (state == PROCESS_FORWARD && next_state == COMPLETE) begin
        need_backward <= 1'b0;
      end else if (state == PROCESS_BACKWARD) begin
        // When backward zebra breaks or reaches start, we are done
        if (idx_b == 4'd0)
          need_backward <= 1'b0;
      end
    end
  end

  // Final result computation in COMPLETE state
  always @(posedge clk) begin
    if (!rst_n) begin
      max_streak <= 5'd0;
    end else begin
      if (state == COMPLETE && !done) begin
        // Compute combined wrap streak if applicable
        reg [5:0] wrap_streak;
        wrap_streak = forward_max;
        if (first_bit != last_bit) begin
          wrap_streak = init_streak + end_streak;
          if (wrap_streak < forward_max)
            wrap_streak = forward_max;
        end
        // Cap at data_len
        if (wrap_streak > data_len)
          max_streak <= {1'b0, data_len};
        else
          max_streak <= wrap_streak[4:0];
      end
    end
  end

endmodule