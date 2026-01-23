module max_swap_subarray (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
  input [2:0] k_in,
  output reg signed [15:0] result,
  output reg done
);

  // Internal registers for array elements
  reg signed [7:0] a [0:7];
  reg signed [15:0] best_result;
  reg [2:0] l, r;
  reg [2:0] k;
  reg [2:0] swap_count;
  reg signed [15:0] current_sum;
  reg [2:0] state;
  reg [5:0] cycle_count;

  // State definitions
  localparam IDLE = 0;
  localparam INIT = 1;
  localparam ITER_L = 2;
  localparam ITER_R = 3;
  localparam SORT_INNER = 4;
  localparam SORT_OUTER = 5;
  localparam SWAP_LOOP = 6;
  localparam UPDATE_BEST = 7;
  localparam DONE = 8;

  // Bubble sort variables
  reg [2:0] sort_i, sort_j;
  reg sort_done;
  reg [2:0] inner_start, inner_end;
  reg [2:0] outer_start, outer_end;

  // Initialize array on reset
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a[0] <= 0; a[1] <= 0; a[2] <= 0; a[3] <= 0;
      a[4] <= 0; a[5] <= 0; a[6] <= 0; a[7] <= 0;
      best_result <= 0;
      l <= 0; r <= 0;
      k <= 0; swap_count <= 0;
      current_sum <= 0;
      state <= IDLE;
      cycle_count <= 0;
      sort_i <= 0; sort_j <= 0;
      sort_done <= 1;
      inner_start <= 0; inner_end <= 0;
      outer_start <= 0; outer_end <= 0;
      done <= 0;
      result <= 0;
    end else begin
      // Update input array
      a[0] <= a_0; a[1] <= a_1; a[2] <= a_2; a[3] <= a_3;
      a[4] <= a_4; a[5] <= a_5; a[6] <= a_6; a[7] <= a_7;
      k <= k_in;
    end
  end

  // Main state machine
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled above
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            cycle_count <= 0;
          end
        end

        INIT: begin
          best_result <= a[0];
          l <= 0;
          state <= ITER_L;
          cycle_count <= cycle_count + 1;
        end

        ITER_L: begin
          if (cycle_count < 50) begin
            if (l == 7) begin
              state <= DONE;
            end else begin
              r <= l;
              state <= ITER_R;
            end
          end else begin
            cycle_count <= cycle_count + 1;
          end
        end

        ITER_R: begin
          if (r == 7) begin
            l <= l + 1;
            state <= ITER_L;
          end else begin
            // Initialize sorting parameters
            inner_start <= l;
            inner_end <= r;
            outer_start <= 0;
            outer_end <= 7;
            sort_i <= 0;
            sort_j <= 0;
            sort_done <= 0;
            state <= SORT_INNER;
          end
        end

        SORT_INNER: begin
          if (!sort_done) begin
            // Bubble sort inner array (ascending)
            if (sort_i < inner_end - inner_start) begin
              if (sort_j < inner_end - inner_start - sort_i) begin
                if (a[inner_start + sort_j] > a[inner_start + sort_j + 1]) begin
                  // Swap
                  reg signed [7:0] temp;
                  temp = a[inner_start + sort_j];
                  a[inner_start + sort_j] = a[inner_start + sort_j + 1];
                  a[inner_start + sort_j + 1] = temp;
                end
                sort_j <= sort_j + 1;
              end else begin
                sort_j <= 0;
                sort_i <= sort_i + 1;
              end
            end else begin
              sort_done <= 1;
              sort_i <= 0;
              sort_j <= 0;
              state <= SORT_OUTER;
            end
          end
        end

        SORT_OUTER: begin
          if (!sort_done) begin
            // Bubble sort outer array (descending)
            // Outer array consists of elements not in [l,r]
            // We need to sort the concatenation of [0..l-1] and [r+1..7]
            reg [2:0] outer_size;
            outer_size = (l > 0) ? l : 0;
            outer_size = outer_size + ((7 - r) > 0) ? (7 - r) : 0;

            if (sort_i < outer_size - 1) begin
              if (sort_j < outer_size - 1 - sort_i) begin
                reg signed [7:0] elem1, elem2;
                // Get elements from outer array
                if (sort_j < l) begin
                  elem1 = a[sort_j];
                end else begin
                  elem1 = a[sort_j + (7 - r) + 1];
                end

                if (sort_j + 1 < l) begin
                  elem2 = a[sort_j + 1];
                end else begin
                  elem2 = a[sort_j + 1 + (7 - r) + 1];
                end

                if (elem1 < elem2) begin
                  // Swap
                  reg signed [7:0] temp;
                  temp = elem1;
                  if (sort_j < l) begin
                    a[sort_j] = elem2;
                  end else begin
                    a[sort_j + (7 - r) + 1] = elem2;
                  end

                  if (sort_j + 1 < l) begin
                    a[sort_j + 1] = temp;
                  end else begin
                    a[sort_j + 1 + (7 - r) + 1] = temp;
                  end
                end
                sort_j <= sort_j + 1;
              end else begin
                sort_j <= 0;
                sort_i <= sort_i + 1;
              end
            end else begin
              sort_done <= 1;
              sort_i <= 0;
              sort_j <= 0;
              swap_count <= 0;
              // Calculate initial sum
              reg signed [15:0] sum = 0;
              for (integer i = l; i <= r; i = i + 1) begin
                sum = sum + a[i];
              end
              current_sum <= sum;
              state <= SWAP_LOOP;
            end
          end
        end

        SWAP_LOOP: begin
          if (swap_count < k && swap_count < 3) begin
            // Find smallest in inner and largest in outer
            reg signed [7:0] min_inner = a[l];
            reg [2:0] min_idx = l;
            for (integer i = l + 1; i <= r; i = i + 1) begin
              if (a[i] < min_inner) begin
                min_inner = a[i];
                min_idx = i;
              end
            end

            reg signed [7:0] max_outer = a[0];
            reg [2:0] max_idx = 0;
            for (integer i = 1; i < l; i = i + 1) begin
              if (a[i] > max_outer) begin
                max_outer = a[i];
                max_idx = i;
              end
            end
            for (integer i = r + 1; i <= 7; i = i + 1) begin
              if (a[i] > max_outer) begin
                max_outer = a[i];
                max_idx = i;
              end
            end

            if (max_outer > min_inner) begin
              // Perform swap
              reg signed [7:0] temp = a[min_idx];
              a[min_idx] = a[max_idx];
              a[max_idx] = temp;
              current_sum <= current_sum + (max_outer - min_inner);
            end
            swap_count <= swap_count + 1;
          end else begin
            state <= UPDATE_BEST;
          end
        end

        UPDATE_BEST: begin
          if (current_sum > best_result) begin
            best_result <= current_sum;
          end
          r <= r + 1;
          state <= ITER_R;
        end

        DONE: begin
          done <= 1;
          result <= best_result;
          if (!start) begin
            done <= 0;
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule