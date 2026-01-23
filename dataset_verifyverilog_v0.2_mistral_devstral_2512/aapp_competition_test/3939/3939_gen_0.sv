module slime_k_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] k,
  input [7:0] a_0, a_1, a_2, a_3, a_4, a_5, a_6, a_7,
  output reg result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CHECK_K,
    CHECK_PAIRS,
    DONE
  } state_t;

  state_t state;
  reg exists_k;
  reg [7:0] array [0:7];

  // Assign input array
  always @(*) begin
    array[0] = a_0;
    array[1] = a_1;
    array[2] = a_2;
    array[3] = a_3;
    array[4] = a_4;
    array[5] = a_5;
    array[6] = a_6;
    array[7] = a_7;
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 0;
      done <= 0;
      exists_k <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_K;
            exists_k <= 0;
            result <= 0;
            done <= 0;
          end
        end

        CHECK_K: begin
          // Check if k exists in array
          exists_k <= (array[0] == k) || (array[1] == k) ||
                     (array[2] == k) || (array[3] == k) ||
                     (array[4] == k) || (array[5] == k) ||
                     (array[6] == k) || (array[7] == k);
          state <= CHECK_PAIRS;
        end

        CHECK_PAIRS: begin
          // Check conditions for result
          result <= exists_k && (
            // Single element case (N=1)
            (array[0] == k) ||
            // Adjacent pairs (distance 1)
            (array[0] >= k && array[1] >= k) ||
            (array[1] >= k && array[2] >= k) ||
            (array[2] >= k && array[3] >= k) ||
            (array[3] >= k && array[4] >= k) ||
            (array[4] >= k && array[5] >= k) ||
            (array[5] >= k && array[6] >= k) ||
            (array[6] >= k && array[7] >= k) ||
            // Triplets (distance 2)
            (array[0] >= k && array[2] >= k) ||
            (array[1] >= k && array[3] >= k) ||
            (array[2] >= k && array[4] >= k) ||
            (array[3] >= k && array[5] >= k) ||
            (array[4] >= k && array[6] >= k) ||
            (array[5] >= k && array[7] >= k)
          );
          state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule