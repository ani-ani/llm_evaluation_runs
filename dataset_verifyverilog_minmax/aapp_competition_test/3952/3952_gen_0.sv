module strange_rectangle_counter(
  input clk, // Clock signal
  input rst_n, // Active-low reset
  input start, // Start computation
  input [7:0] point_x [0:7], // X-coordinates (8 points, 8-bit each)
  input [7:0] point_y [0:7], // Y-coordinates (8 points, 8-bit each)
  input [2:0] num_points, // Actual number of points (1-8)
  output reg [15:0] count, // Result count of distinct sets
  output reg done // High when computation complete
);

  // Constants
  localparam N = 8;
  localparam S_IDLE = 2'b00;
  localparam S_SORT = 2'b01;
  localparam S_PROC = 2'b10;
  localparam S_DONE = 2'b11;

  // Sorting storage
  reg [7:0] sort_x [0:N-1];
  reg [7:0] sort_y [0:N-1];
  reg sort_done;
  reg [2:0] i_sort, j_sort;
  reg [7:0] temp_x;
  reg [7:0] temp_y;

  // Active X set (unique X coordinates seen so far)
  reg [7:0] active_x [0:N-1];
  reg [3:0] xs_added;
  reg [2:0] i_active;

  // State
  reg [1:0] state;
  reg [2:0] i_proc;
  reg [7:0] x_curr;
  reg [7:0] y_curr;
  reg [2:0] n_pts;

  // Helper task: add x to active set (no duplicates)
  task add_x;
    input [7:0] x;
    begin
      i_active = 0;
      while (i_active < xs_added) begin
        if (active_x[i_active] == x) begin
          // Already active, do not increment xs_added
          i_active = xs_added; // force exit
        end else begin
          i_active = i_active + 1;
        end
      end
      if (i_active == xs_added && xs_added < N) begin
        // Not found, add it
        active_x[xs_added] = x;
        xs_added = xs_added + 1;
      end
    end
  endtask

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset outputs
      count <= 16'd0;
      done <= 1'b0;
      // Reset state
      state <= S_IDLE;
      // Reset sorting
      sort_done <= 1'b0;
      i_sort <= 3'd0;
      j_sort <= 3'd0;
      for (i_active = 0; i_active < N; i_active = i_active + 1) begin
        sort_x[i_active] <= 8'd0;
        sort_y[i_active] <= 8'd0;
        active_x[i_active] <= 8'd0;
      end
      temp_x <= 8'd0;
      temp_y <= 8'd0;
      // Reset active set and counters
      xs_added <= 4'd0;
      i_proc <= 3'd0;
      x_curr <= 8'd0;
      y_curr <= 8'd0;
      n_pts <= 3'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Load data
            n_pts <= (num_points == 3'd0) ? 3'd1 : (num_points > 3'd8 ? 3'd8 : num_points);
            for (i_active = 0; i_active < N; i_active = i_active + 1) begin
              sort_x[i_active] <= point_x[i_active];
              sort_y[i_active] <= point_y[i_active];
            end
            // Reset active set and counters
            for (i_active = 0; i_active < N; i_active = i_active + 1) begin
              active_x[i_active] <= 8'd0;
            end
            xs_added <= 4'd0;
            i_proc <= 3'd0;
            count <= 16'd0;

            // Init sort pointers
            i_sort <= 3'd0;
            j_sort <= 3'd0;
            sort_done <= 1'b0;
            state <= S_SORT;
          end
        end

        S_SORT: begin
          if (sort_done) begin
            state <= S_PROC;
            i_proc <= 3'd0;
            x_curr <= sort_x[0];
            y_curr <= sort_y[0];
          end else begin
            if (i_sort < n_pts - 1) begin
              if (j_sort < (n_pts - 1 - i_sort)) begin
                // Compare and swap sort_y in descending order
                if (sort_y[j_sort] < sort_y[j_sort + 1]) begin
                  // Swap X and Y to keep pairing
                  temp_x <= sort_x[j_sort];
                  temp_y <= sort_y[j_sort];
                  sort_x[j_sort] <= sort_x[j_sort + 1];
                  sort_y[j_sort] <= sort_y[j_sort + 1];
                  sort_x[j_sort + 1] <= temp_x;
                  sort_y[j_sort + 1] <= temp_y;
                end
                j_sort <= j_sort + 1;
              end else begin
                j_sort <= 3'd0;
                i_sort <= i_sort + 1;
              end
            end else begin
              sort_done <= 1'b1;
            end
          end
        end

        S_PROC: begin
          if (i_proc < n_pts) begin
            // Add current X to active set (uniqueness enforced by task)
            add_x(x_curr);
            // Update count using number of unique X-coordinates seen so far (combinations of 2)
            // count = xs_added choose 2
            if (xs_added >= 2) count <= (xs_added * (xs_added - 1)) >> 1;
            // Prepare for next point (if any)
            if (i_proc < n_pts - 1) begin
              x_curr <= sort_x[i_proc + 1];
              y_curr <= sort_y[i_proc + 1];
            end
            i_proc <= i_proc + 1;
          end else begin
            state <= S_DONE;
            done <= 1'b1;
          end
        end

        S_DONE: begin
          // Hold final results; deassert done when start is deasserted
          if (!start) begin
            state <= S_IDLE;
            done <= 1'b0;
          end
        end

        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
