module strange_rectangle_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] point_x [0:7],
  input [7:0] point_y [0:7],
  input [2:0] num_points,
  output reg [15:0] count,
  output reg done
);

  // Internal registers
  reg [7:0] x_reg [0:7];
  reg [7:0] y_reg [0:7];

  reg [3:0] i_idx;
  reg [3:0] j_idx;

  reg [7:0] tmp_x;
  reg [7:0] tmp_y;

  reg [2:0] sort_pass;
  reg sorting;

  reg [2:0] proc_idx;
  reg processing;

  reg [7:0] active_mask; // tracks active X-coordinates (one-hot per point index)

  reg [15:0] new_sets;

  reg [7:0] last_y;
  reg       first_group;

  reg [7:0] cycle_cnt;

  typedef enum logic [2:0] {
    IDLE  = 3'd0,
    LOAD  = 3'd1,
    SORT  = 3'd2,
    PROC_INIT = 3'd3,
    PROC = 3'd4,
    DONE = 3'd5
  } state_t;

  state_t state, next_state;

  // Combinational next state / control
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = LOAD;
      end
      LOAD: begin
        if (num_points == 0)
          next_state = DONE;
        else
          next_state = SORT;
      end
      SORT: begin
        // bubble sort completion when sort_pass == num_points-1 and j_idx reached end
        if (!sorting)
          next_state = PROC_INIT;
      end
      PROC_INIT: begin
        next_state = PROC;
      end
      PROC: begin
        if (!processing || cycle_cnt >= 8'd200)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      count       <= 16'd0;
      done        <= 1'b0;
      sorting     <= 1'b0;
      processing  <= 1'b0;
      sort_pass   <= 3'd0;
      i_idx       <= 4'd0;
      j_idx       <= 4'd0;
      proc_idx    <= 3'd0;
      active_mask <= 8'd0;
      new_sets    <= 16'd0;
      last_y      <= 8'd0;
      first_group <= 1'b1;
      cycle_cnt   <= 8'd0;
      for (k = 0; k < 8; k = k + 1) begin
        x_reg[k] <= 8'd0;
        y_reg[k] <= 8'd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done        <= 1'b0;
          count       <= 16'd0;
          sorting     <= 1'b0;
          processing  <= 1'b0;
          sort_pass   <= 3'd0;
          i_idx       <= 4'd0;
          j_idx       <= 4'd0;
          proc_idx    <= 3'd0;
          active_mask <= 8'd0;
          new_sets    <= 16'd0;
          last_y      <= 8'd0;
          first_group <= 1'b1;
          cycle_cnt   <= 8'd0;
        end

        LOAD: begin
          // Latch inputs
          for (k = 0; k < 8; k = k + 1) begin
            x_reg[k] <= point_x[k];
            y_reg[k] <= point_y[k];
          end
          count       <= 16'd0;
          done        <= 1'b0;
          sorting     <= 1'b1;
          processing  <= 1'b0;
          sort_pass   <= 3'd0;
          i_idx       <= 4'd0;
          j_idx       <= 4'd0;
          proc_idx    <= 3'd0;
          active_mask <= 8'd0;
          new_sets    <= 16'd0;
          last_y      <= 8'd0;
          first_group <= 1'b1;
          cycle_cnt   <= 8'd0;
        end

        SORT: begin
          done <= 1'b0;
          // Bubble sort by y_reg descending
          if (sorting) begin
            if (sort_pass < num_points) begin
              if (j_idx < (num_points - 1 - sort_pass)) begin
                if (y_reg[j_idx] < y_reg[j_idx+1]) begin
                  tmp_y           <= y_reg[j_idx];
                  y_reg[j_idx]    <= y_reg[j_idx+1];
                  y_reg[j_idx+1]  <= tmp_y;

                  tmp_x           <= x_reg[j_idx];
                  x_reg[j_idx]    <= x_reg[j_idx+1];
                  x_reg[j_idx+1]  <= tmp_x;
                end
                j_idx <= j_idx + 1'b1;
              end else begin
                j_idx     <= 4'd0;
                sort_pass <= sort_pass + 1'b1;
              end
            end else begin
              sorting <= 1'b0;
            end
          end
          cycle_cnt <= cycle_cnt + 1'b1;
        end

        PROC_INIT: begin
          // Initialize processing state
          processing  <= 1'b1;
          proc_idx    <= 3'd0;
          active_mask <= 8'd0;
          new_sets    <= 16'd0;
          last_y      <= y_reg[0];
          first_group <= 1'b1;
          cycle_cnt   <= cycle_cnt + 1'b1;
        end

        PROC: begin
          if (processing && (proc_idx < num_points) && (cycle_cnt < 8'd200)) begin
            // Detect group boundary by Y value
            if (!first_group && (y_reg[proc_idx] != last_y)) begin
              // For each new Y band start, we count one new set plus those
              // produced by newly activated points in this row.
              count    <= count + new_sets + 16'd1;
              new_sets <= 16'd0;
            end

            // Activate current point's X (index-based mask);
            // each newly activated X introduces new distinct sets
            if (!active_mask[proc_idx]) begin
              active_mask[proc_idx] <= 1'b1;
              new_sets              <= new_sets + 16'd1;
            end

            last_y      <= y_reg[proc_idx];
            first_group <= 1'b0;

            proc_idx   <= proc_idx + 1'b1;
            cycle_cnt  <= cycle_cnt + 1'b1;

            if (proc_idx == (num_points - 1)) begin
              // Finalize for last group when reaching last point
              count      <= count + new_sets + 16'd1;
              processing <= 1'b0;
            end
          end else begin
            processing <= 1'b0;
            cycle_cnt  <= cycle_cnt + 1'b1;
          end
        end

        DONE: begin
          done <= 1'b1;
          // Hold count; wait for start to deassert then go IDLE (via next_state)
          cycle_cnt <= cycle_cnt; // no change
        end

        default: begin
          // Should not happen; go safe
          state <= IDLE;
        end
      endcase
    end
  end

endmodule