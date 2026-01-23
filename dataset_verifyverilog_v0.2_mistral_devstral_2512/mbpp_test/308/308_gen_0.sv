module large_product (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [2:0] size1,
  input [2:0] size2,
  input [7:0] list1 [0:7],
  input [7:0] list2 [0:7],
  output reg [15:0] result [0:7],
  output reg [3:0] valid_count,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    COMPUTE_PRODUCTS,
    BUBBLE_SORT,
    EXTRACT_RESULTS,
    DONE
  } state_t;
  state_t state, next_state;

  // Product array (max 64 elements)
  reg [15:0] products [0:63];

  // Counters and temporary registers
  reg [5:0] i, j, k, m;
  reg [5:0] total_products;
  reg [5:0] sort_passes, sort_comparisons;
  reg [15:0] temp;
  reg swap_flag;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid_count <= 0;
      for (int idx = 0; idx < 8; idx++) begin
        result[idx] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i <= 0;
      j <= 0;
      k <= 0;
      m <= 0;
      sort_passes <= 0;
      sort_comparisons <= 0;
      swap_flag <= 0;
      temp <= 0;
      total_products <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            next_state = COMPUTE_PRODUCTS;
            i <= 0;
            j <= 0;
            k <= 0;
            total_products <= size1 * size2;
          end else begin
            next_state = IDLE;
          end
        end

        COMPUTE_PRODUCTS: begin
          if (j < size2) begin
            products[k] <= list1[i] * list2[j];
            j <= j + 1;
            k <= k + 1;
          end else begin
            j <= 0;
            i <= i + 1;
            if (i < size1) begin
              next_state = COMPUTE_PRODUCTS;
            end else begin
              next_state = BUBBLE_SORT;
              sort_passes <= 0;
              sort_comparisons <= 0;
            end
          end
        end

        BUBBLE_SORT: begin
          if (sort_comparisons < total_products - sort_passes - 1) begin
            if (products[sort_comparisons] < products[sort_comparisons + 1]) begin
              temp <= products[sort_comparisons];
              products[sort_comparisons] <= products[sort_comparisons + 1];
              products[sort_comparisons + 1] <= temp;
              swap_flag <= 1;
            end
            sort_comparisons <= sort_comparisons + 1;
          end else begin
            if (swap_flag) begin
              swap_flag <= 0;
              sort_comparisons <= 0;
              sort_passes <= sort_passes + 1;
            end else begin
              next_state = EXTRACT_RESULTS;
              m <= 0;
            end
          end
        end

        EXTRACT_RESULTS: begin
          if (m < N && m < total_products) begin
            result[m] <= products[m];
            m <= m + 1;
          end else begin
            valid_count <= (N < total_products) ? N : total_products;
            done <= 1;
            next_state = DONE;
          end
        end

        DONE: begin
          if (!start) begin
            done <= 0;
            next_state = IDLE;
          end else begin
            next_state = DONE;
          end
        end

        default: next_state = IDLE;
      endcase
    end
  end

endmodule