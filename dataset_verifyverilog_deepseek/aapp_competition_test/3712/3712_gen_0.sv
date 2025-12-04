module compartment_swaps (
  input clk,
  input rst_n,
  input start,
  input [2:0] comp0,
  input [2:0] comp1,
  input [2:0] comp2,
  input [2:0] comp3,
  input [2:0] comp4,
  input [2:0] comp5,
  input [2:0] comp6,
  input [2:0] comp7,
  output reg [6:0] result,
  output reg done
);

typedef enum logic [2:0] {
  IDLE,
  COUNTING,
  PROCESS_12,
  PROCESS_1_REMAIN,
  PROCESS_2_REMAIN,
  FINISH
} state_t;

reg [2:0] state;
reg [3:0] counts[1:4];
reg [6:0] ans;
reg [6:0] total_students;
reg [3:0] min_val;
reg [3:0] quotient_1, quotient_2;
reg [1:0] remainder_1, remainder_2;
reg [6:0] new_ans;
reg [3:0] new_counts3;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    ans <= 0;
    counts[1] <= 0;
    counts[2] <= 0;
    counts[3] <= 0;
    counts[4] <= 0;
    result <= 0;
    total_students <= 0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        ans <= 0;
        counts[1] <= 0;
        counts[2] <= 0;
        counts[3] <= 0;
        counts[4] <= 0;
        if (start) begin
          state <= COUNTING;
        end
      end

      COUNTING: begin
        total_students <= comp0 + comp1 + comp2 + comp3 + comp4 + comp5 + comp6 + comp7;
        counts[1] <= (comp0 == 3'd1) + (comp1 == 3'd1) + (comp2 == 3'd1) + (comp3 == 3'd1) +
                     (comp4 == 3'd1) + (comp5 == 3'd1) + (comp6 == 3'd1) + (comp7 == 3'd1);
        counts[2] <= (comp0 == 3'd2) + (comp1 == 3'd2) + (comp2 == 3'd2) + (comp3 == 3'd2) +
                     (comp4 == 3'd2) + (comp5 == 3'd2) + (comp6 == 3'd2) + (comp7 == 3'd2);
        counts[3] <= (comp0 == 3'd3) + (comp1 == 3'd3) + (comp2 == 3'd3) + (comp3 == 3'd3) +
                     (comp4 == 3'd3) + (comp5 == 3'd3) + (comp6 == 3'd3) + (comp7 == 3'd3);
        counts[4] <= (comp0 == 3'd4) + (comp1 == 3'd4) + (comp2 == 3'd4) + (comp3 == 3'd4) +
                     (comp4 == 3'd4) + (comp5 == 3'd4) + (comp6 == 3'd4) + (comp7 == 3'd4);
        if (total_students < 3 || total_students == 5) begin
          ans <= 7'b1111111;
          state <= FINISH;
        end else begin
          state <= PROCESS_12;
        end
      end

      PROCESS_12: begin
        min_val = (counts[1] < counts[2]) ? counts[1] : counts[2];
        ans <= ans + min_val;
        counts[3] <= counts[3] + min_val;
        counts[1] <= counts[1] - min_val;
        counts[2] <= counts[2] - min_val;
        state <= PROCESS_1_REMAIN;
      end

      PROCESS_1_REMAIN: begin
        quotient_1 = counts[1] / 3;
        remainder_1 = counts[1] % 3;
        new_counts3 = counts[3] + quotient_1;
        new_ans = ans + (quotient_1 << 1);
        if (remainder_1 != 0) begin
          if (new_counts3 > 0) begin
            new_ans = new_ans + remainder_1;
          end else begin
            new_ans = new_ans + 2;
          end
        end
        ans <= new_ans;
        counts[3] <= new_counts3;
        counts[1] <= 0;
        state <= PROCESS_2_REMAIN;
      end

      PROCESS_2_REMAIN: begin
        quotient_2 = counts[2] / 3;
        remainder_2 = counts[2] % 3;
        new_counts3 = counts[3] + (quotient_2 << 1);
        new_ans = ans + (quotient_2 << 1);
        if (remainder_2 != 0) begin
          if (counts[4] > 0) begin
            new_ans = new_ans + remainder_2;
          end else begin
            new_ans = new_ans + 2;
          end
        end
        ans <= new_ans;
        counts[3] <= new_counts3;
        counts[2] <= 0;
        state <= FINISH;
      end

      FINISH: begin
        result <= ans;
        done <= 1;
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule