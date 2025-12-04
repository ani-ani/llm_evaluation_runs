module sorted_arrays_median (
  input clk,
  input rst_n,
  input start,
  input [7:0] arr1 [0:7],
  input [7:0] arr2 [0:7],
  input [2:0] n,
  output reg [8:0] med_sum,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] i, j;
  reg [3:0] count;
  reg [7:0] m1, m2;

  always_comb begin
    case (current_state)
      IDLE: next_state = (start) ? PROCESSING : IDLE;
      PROCESSING: next_state = (count == n + 3'b1) ? DONE : PROCESSING;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      med_sum <= 9'b0;
      done <= 1'b0;
      i <= 3'b0;
      j <= 3'b0;
      count <= 4'b0;
      m1 <= 8'b0;
      m2 <= 8'b0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            i <= 3'b0;
            j <= 3'b0;
            count <= 4'b0;
            m1 <= 8'b0;
            m2 <= 8'b0;
          end
        end

        PROCESSING: begin
          if (count < n + 3'b1) begin
            if ((i < n) && ((j >= n) || (arr1[i] <= arr2[j]))) begin
              m2 <= m1;
              m1 <= arr1[i];
              i <= i + 3'b1;
            end else if (j < n) begin
              m2 <= m1;
              m1 <= arr2[j];
              j <= j + 3'b1;
            end
            count <= count + 4'b1;
          end
        end

        DONE: begin
          med_sum <= m1 + m2;
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule