module compartment_swaps(
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

  // FSM states
  localparam [2:0]
    IDLE          = 3'd0,
    COUNTING      = 3'd1,
    PROCESS_12    = 3'd2,
    PROCESS_1_REM = 3'd3,
    PROCESS_2_REM = 3'd4,
    FINISH        = 3'd5;

  reg [2:0] state, next_state;

  // comp array and index for counting
  reg [2:0] comp_arr [0:7];
  reg [3:0] idx;

  // counts[1..4]
  reg [3:0] counts1, counts2, counts3, counts4;

  // accumulator for answer
  reg [6:0] ans;

  // sum of students
  reg [6:0] total_students;

  // internal helper registers
  reg [3:0] min12;
  reg [3:0] rem1;
  reg [3:0] rem2;
  reg [3:0] tmp;

  // latch inputs into comp_arr for deterministic use
  always @(*) begin
    comp_arr[0] = comp0;
    comp_arr[1] = comp1;
    comp_arr[2] = comp2;
    comp_arr[3] = comp3;
    comp_arr[4] = comp4;
    comp_arr[5] = comp5;
    comp_arr[6] = comp6;
    comp_arr[7] = comp7;
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = COUNTING;
      end
      COUNTING: begin
        if (idx == 4'd8) next_state = PROCESS_12;
      end
      PROCESS_12: begin
        next_state = PROCESS_1_REM;
      end
      PROCESS_1_REM: begin
        next_state = PROCESS_2_REM;
      end
      PROCESS_2_REM: begin
        next_state = FINISH;
      end
      FINISH: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      idx             <= 4'd0;
      counts1         <= 4'd0;
      counts2         <= 4'd0;
      counts3         <= 4'd0;
      counts4         <= 4'd0;
      ans             <= 7'd0;
      total_students  <= 7'd0;
      result          <= 7'd0;
      done            <= 1'b0;
      min12           <= 4'd0;
      rem1            <= 4'd0;
      rem2            <= 4'd0;
      tmp             <= 4'd0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          done           <= 1'b0;
          result         <= 7'd0;
          ans            <= 7'd0;
          counts1        <= 4'd0;
          counts2        <= 4'd0;
          counts3        <= 4'd0;
          counts4        <= 4'd0;
          total_students <= 7'd0;
          idx            <= 4'd0;
        end

        COUNTING: begin
          if (idx < 4'd8) begin
            // accumulate total students
            total_students <= total_students + comp_arr[idx];
            // categorize compartments by (students mod 3)
            case (comp_arr[idx] % 3)
              3'd1: counts1 <= counts1 + 4'd1;
              3'd2: counts2 <= counts2 + 4'd1;
              3'd0: begin
                if (comp_arr[idx] != 3'd0)
                  counts3 <= counts3 + 4'd1;
              end
              default: ;
            endcase
            idx <= idx + 4'd1;
          end
        end

        PROCESS_12: begin
          // use counts4 as provided in spec (here left at 0 unless extended)
          // step 1: process min(counts1, counts2)
          if (counts1 < counts2)
            min12 <= counts1;
          else
            min12 <= counts2;

          ans     <= ans + ((counts1 < counts2) ? counts1 : counts2);
          counts3 <= counts3 + ((counts1 < counts2) ? counts1 : counts2);

          // subtract min from counts1 and counts2 for next steps
          if (counts1 < counts2) begin
            counts2 <= counts2 - counts1;
            counts1 <= 4'd0;
          end else begin
            counts1 <= counts1 - counts2;
            counts2 <= 4'd0;
          end
        end

        PROCESS_1_REM: begin
          // handle remaining counts1
          // a) ans += 2*(counts1/3), counts3 += counts1/3
          tmp  <= counts1 / 3;
          ans  <= ans + {3'd0, (counts1 / 3)} + {3'd0, (counts1 / 3)}; // 2*tmp
          counts3 <= counts3 + (counts1 / 3);

          // remainder for counts1
          rem1 <= counts1 % 3;

          // b) remainder handling: if counts3 > 0 add rem1 else add 2 if rem1 != 0
          if (rem1 != 4'd0) begin
            if (counts3 > 4'd0)
              ans <= ans + rem1;
            else
              ans <= ans + 7'd2;
          end

          counts1 <= 4'd0;
        end

        PROCESS_2_REM: begin
          // handle remaining counts2
          // a) ans += 2*(counts2/3), counts3 += 2*(counts2/3)
          tmp  <= counts2 / 3;
          ans  <= ans + {3'd0, (counts2 / 3)} + {3'd0, (counts2 / 3)}; // 2*tmp
          counts3 <= counts3 + ((counts2 / 3) << 1); // 2*tmp

          // remainder for counts2
          rem2 <= counts2 % 3;

          // b) remainder handling: if counts4 > 0 add rem2 else add 2 if rem2 != 0
          if (rem2 != 4'd0) begin
            if (counts4 > 4'd0)
              ans <= ans + rem2;
            else
              ans <= ans + 7'd2;
          end

          counts2 <= 4'd0;
        end

        FINISH: begin
          // special case: if total students <3 or ==5 => result = -1 (7'b1111111)
          if ((total_students < 7'd3) || (total_students == 7'd5))
            result <= 7'b1111111;
          else
            result <= ans;
          done <= 1'b1;
        end

        default: ;
      endcase
    end
  end

endmodule