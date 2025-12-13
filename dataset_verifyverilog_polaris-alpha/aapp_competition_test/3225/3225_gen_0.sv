module candidate_queue_processor(
  input clk,
  input rst_n,
  input start,
  input [7:0] initial_values [0:7],
  output reg done,
  output reg [3:0] round_count,
  output reg [7:0] final_queue [0:7],
  output reg [3:0] queue_size
);

  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    ROUND = 2'b10,
    DONE  = 2'b11
  } state_t;

  state_t state, next_state;

  reg [7:0] work_q [0:7];
  reg [3:0] work_size;

  reg [7:0] next_work_q [0:7];
  reg [3:0] next_work_size;
  reg [3:0] next_round_count;
  reg next_done;
  reg [7:0] next_final_queue [0:7];
  reg [3:0] next_queue_size;

  integer i;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      round_count <= 4'd0;
      queue_size  <= 4'd0;
      work_size   <= 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        work_q[i]       <= 8'd0;
        final_queue[i]  <= 8'd0;
      end
    end else begin
      state       <= next_state;
      done        <= next_done;
      round_count <= next_round_count;
      queue_size  <= next_queue_size;
      work_size   <= next_work_size;
      for (i = 0; i < 8; i = i + 1) begin
        work_q[i]      <= next_work_q[i];
        final_queue[i] <= next_final_queue[i];
      end
    end
  end

  // Combinational next-state/next-data logic
  always @* begin
    // Default assignments: hold values
    next_state       = state;
    next_done        = done;
    next_round_count = round_count;
    next_queue_size  = queue_size;
    next_work_size   = work_size;

    for (i = 0; i < 8; i = i + 1) begin
      next_work_q[i]      = work_q[i];
      next_final_queue[i] = final_queue[i];
    end

    case (state)
      IDLE: begin
        next_done = 1'b0;
        if (start) begin
          next_state       = LOAD;
          next_round_count = 4'd0;
        end
      end

      LOAD: begin
        // Load initial values into working queue
        for (i = 0; i < 8; i = i + 1) begin
          next_work_q[i] = initial_values[i];
        end
        next_work_size  = 4'd8;
        next_round_count = 4'd0;
        next_done        = 1'b0;
        next_state       = ROUND;
      end

      ROUND: begin
        // Perform one elimination round
        reg [7:0] tmp_q [0:7];
        reg [3:0] tmp_size;
        reg eliminated_any;
        reg eliminate [0:7];
        integer j;
        integer k;

        // Initialize
        for (j = 0; j < 8; j = j + 1) begin
          eliminate[j] = 1'b0;
        end
        eliminated_any = 1'b0;

        // Determine elimination marks based on neighbors
        if (work_size > 0) begin
          for (j = 0; j < work_size; j = j + 1) begin
            if (j == 0) begin
              if (work_size > 1 && work_q[1] > work_q[0]) begin
                eliminate[0] = 1'b1;
              end
            end else if (j == work_size - 1) begin
              if (work_size > 1 && work_q[work_size-2] > work_q[work_size-1]) begin
                eliminate[work_size-1] = 1'b1;
              end
            end else begin
              if ((work_q[j-1] > work_q[j]) || (work_q[j+1] > work_q[j])) begin
                eliminate[j] = 1'b1;
              end
            end
          end
        end

        // Build next queue after elimination
        tmp_size = 4'd0;
        for (j = 0; j < work_size; j = j + 1) begin
          if (eliminate[j]) begin
            eliminated_any = 1'b1;
          end else begin
            tmp_q[tmp_size] = work_q[j];
            tmp_size = tmp_size + 1'b1;
          end
        end

        // If no eliminations, we're done
        if (!eliminated_any) begin
          // Final results
          for (k = 0; k < 8; k = k + 1) begin
            if (k < work_size)
              next_final_queue[k] = work_q[k];
            else
              next_final_queue[k] = 8'd0;
          end
          next_queue_size  = work_size;
          next_done        = 1'b1;
          next_state       = DONE;
        end else begin
          // Update working queue and continue
          for (k = 0; k < 8; k = k + 1) begin
            if (k < tmp_size)
              next_work_q[k] = tmp_q[k];
            else
              next_work_q[k] = 8'd0;
          end
          next_work_size   = tmp_size;
          next_round_count = round_count + 1'b1;
          next_state       = ROUND;
        end
      end

      DONE: begin
        // Hold results until next start
        if (start) begin
          // Allow restart from DONE
          next_state       = LOAD;
          next_done        = 1'b0;
          next_round_count = 4'd0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule