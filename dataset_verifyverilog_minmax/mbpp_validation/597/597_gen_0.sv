module sorted_array_kth_element(
  input clk,
  input rst_n,
  input start,
  input [2:0] arr1_len,
  input [2:0] arr2_len,
  input [9:0] arr1 [0:7],
  input [9:0] arr2 [0:7],
  input [3:0] k_in,
  output reg [9:0] kth_element,
  output reg done,
  output reg error
);

  // State encoding
  localparam IDLE      = 3'b000;
  localparam COMPARE   = 3'b001;
  localparam CHECK_ARR1= 3'b010;
  localparam CHECK_ARR2= 3'b011;
  localparam DONE      = 3'b100;

  reg [2:0] state;
  reg [2:0] i;        // pointer for arr1
  reg [2:0] j;        // pointer for arr2
  reg [4:0] count;    // count of selected elements
  reg [4:0] n1, n2;   // registered array lengths (0-7)
  reg [3:0] k_val;    // registered k (1-16)
  reg error_reg;      // registered error

  wire [9:0] v1 = (i < n1) ? arr1[i] : 10'h3FF; // treat out-of-bounds as +inf
  wire [9:0] v2 = (j < n2) ? arr2[j] : 10'h3FF;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 3'b0;
      j <= 3'b0;
      count <= 5'b0;
      n1 <= 5'b0;
      n2 <= 5'b0;
      k_val <= 4'b0;
      error_reg <= 1'b0;
      done <= 1'b0;
      kth_element <= 10'b0;
    end else begin
      // defaults (one-hot SM ensures no latches)
      done <= 1'b0;
      error_reg <= error_reg; // hold error until cleared by next start
      i <= i;
      j <= j;
      count <= count;
      n1 <= n1;
      n2 <= n2;
      k_val <= k_val;
      kth_element <= kth_element;

      case (state)
        IDLE: begin
          i <= 3'b0;
          j <= 3'b0;
          count <= 5'b0;
          kth_element <= 10'b0;
          if (start) begin
            n1 <= {2'b0, arr1_len}; // zero-extend to 5 bits
            n2 <= {2'b0, arr2_len};
            k_val <= k_in;
            error_reg <= (k_in > (arr1_len + arr2_len));
            if (k_in > (arr1_len + arr2_len)) begin
              state <= DONE;
              done <= 1'b1;
            end else if (k_in == 5'b0) begin
              // undefined; treat as immediate error
              state <= DONE;
              done <= 1'b1;
            end else begin
              state <= COMPARE;
            end
          end else begin
            state <= IDLE;
          end
        end

        COMPARE: begin
          // one step per cycle; pick smaller valid element
          if (v1 < v2) begin
            // take from arr1
            count <= count + 1;
            i <= i + 1;
            if (count + 1 == k_val) begin
              kth_element <= v1;
              state <= DONE;
              done <= 1'b1;
            end else if (i + 1 >= n1 && j >= n2) begin
              // arr1 exhausted and arr2 exhausted (unlikely here) -> done
              state <= DONE;
              done <= 1'b1;
            end else begin
              state <= COMPARE;
            end
          end else begin
            // take from arr2 (v2 <= v1)
            count <= count + 1;
            j <= j + 1;
            if (count + 1 == k_val) begin
              kth_element <= v2;
              state <= DONE;
              done <= 1'b1;
            end else if (j + 1 >= n2 && i >= n1) begin
              // arr2 exhausted and arr1 exhausted (unlikely here) -> done
              state <= DONE;
              done <= 1'b1;
            end else begin
              state <= COMPARE;
            end
          end
        end

        CHECK_ARR1: begin
          // only used if finalize logic expanded; keep as pass-through for now
          if (i >= n1) begin
            state <= CHECK_ARR2;
          end else if (count + 1 == k_val) begin
            kth_element <= arr1[i];
            i <= i + 1;
            count <= count + 1;
            state <= DONE;
            done <= 1'b1;
          end else begin
            i <= i + 1;
            count <= count + 1;
            state <= COMPARE;
          end
        end

        CHECK_ARR2: begin
          // only used if finalize logic expanded; keep as pass-through for now
          if (j >= n2) begin
            state <= DONE;
            done <= 1'b1;
          end else if (count + 1 == k_val) begin
            kth_element <= arr2[j];
            j <= j + 1;
            count <= count + 1;
            state <= DONE;
            done <= 1'b1;
          end else begin
            j <= j + 1;
            count <= count + 1;
            state <= COMPARE;
          end
        end

        DONE: begin
          // hold outputs; clear error on next start
          if (start) begin
            done <= 1'b0;      // will be set by IDLE transition if needed
            error_reg <= 1'b0; // clear error for new operation
          end else begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase

      // combinatorial finish check to cover boundary cases after COMPARE
      if (state == COMPARE) begin
        if (v1 < v2) begin
          if (count + 1 == k_val) begin
            kth_element <= v1;
            state <= DONE;
            done <= 1'b1;
          end else if (i + 1 >= n1 && j >= n2) begin
            state <= DONE;
            done <= 1'b1;
          end
        end else begin
          if (count + 1 == k_val) begin
            kth_element <= v2;
            state <= DONE;
            done <= 1'b1;
          end else if (j + 1 >= n2 && i >= n1) begin
            state <= DONE;
            done <= 1'b1;
          end
        end
      end
    end
  end

  // output error (registered)
  always @(*) begin
    error = error_reg;
  end

endmodule
