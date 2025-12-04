module wire_routing(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] m,
  input [5:0] a1,
  input [5:0] a2,
  input [5:0] b1,
  input [5:0] b2,
  output reg [5:0] result,
  output reg done
);

  // Coordinate extraction
  wire [2:0] x1 = a1[5:3];
  wire [2:0] y1 = a1[2:0];
  wire [2:0] x2 = a2[5:3];
  wire [2:0] y2 = a2[2:0];
  wire [2:0] x3 = b1[5:3];
  wire [2:0] y3 = b1[2:0];
  wire [2:0] x4 = b2[5:3];
  wire [2:0] y4 = b2[2:0];

  // Delta calculations
  reg signed [3:0] dxA, dyA, dxB, dyB;
  reg [3:0] abs_dxA, abs_dyA, abs_dxB, abs_dyB;
  reg [3:0] lenA, lenB;

  // Movement directions
  reg dirA_x, dirA_y, dirB_x, dirB_y;

  // Path storage (max 14 steps)
  reg [5:0] pathA1 [0:13];
  reg [5:0] pathA2 [0:13];
  reg [5:0] pathB1 [0:13];
  reg [5:0] pathB2 [0:13];

  // Visited grid for overlapping checks
  reg [63:0] visited;

  // FSM states
  enum {
    IDLE,
    PREPARE,
    GEN_A1,
    GEN_A2,
    GEN_B1,
    GEN_B2,
    CHECK1,
    CHECK2,
    CHECK3,
    CHECK4,
    FINISH
  } state;

  reg [1:0] combo_idx;
  reg [3:0] step_cnt;
  reg [3:0] check_step;
  reg valid_found;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 6'b100000;
      step_cnt <= 0;
      check_step <= 0;
      visited <= 64'h0;
      valid_found <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= PREPARE;
            valid_found <= 0;
          end
        end

        PREPARE: begin
          // Calculate deltas and path lengths
          dxA = {x2[2],x2} - {x1[2],x1};
          dyA = {y2[2],y2} - {y1[2],y1};
          dxB = {x4[2],x4} - {x3[2],x3};
          dyB = {y4[2],y4} - {y3[2],y3};
          abs_dxA = dxA[3] ? (~dxA[2:0] + 1) : dxA[2:0];
          abs_dyA = dyA[3] ? (~dyA[2:0] + 1) : dyA[2:0];
          abs_dxB = dxB[3] ? (~dxB[2:0] + 1) : dxB[2:0];
          abs_dyB = dyB[3] ? (~dyB[2:0] + 1) : dyB[2:0];
          lenA = abs_dxA + abs_dyA;
          lenB = abs_dxB + abs_dyB;
          dirA_x = ~dyA[3];
          dirA_y = ~dyA[3];
          dirB_x = ~dxB[3];
          dirB_y = ~dyB[3];
          state <= GEN_A1;
          step_cnt <= 0;
        end

        GEN_A1: begin
          if (step_cnt <= lenA) begin
            if (step_cnt == 0) begin
              pathA1[0] <= {x1, y1};
              step_cnt <= step_cnt + 1;
            end else if (step_cnt <= abs_dxA) begin
              pathA1[step_cnt] <= {x1 + (dirA_x ? step_cnt : -step_cnt), y1};
              step_cnt <= step_cnt + 1;
            end else begin
              pathA1[step_cnt] <= {x2, y1 + (dirA_y ? (step_cnt - abs_dxA) : -(step_cnt - abs_dxA))};
              step_cnt <= step_cnt + 1;
            end
          end else begin
            state <= GEN_A2;
            step_cnt <= 0;
          end
        end

        GEN_A2: begin
          if (step_cnt <= lenA) begin
            if (step_cnt == 0) begin
              pathA2[0] <= {x1, y1};
              step_cnt <= step_cnt + 1;
            end else if (step_cnt <= abs_dyA) begin
              pathA2[step_cnt] <= {x1, y1 + (dirA_y ? step_cnt : -step_cnt)};
              step_cnt <= step_cnt + 1;
            end else begin
              pathA2[step_cnt] <= {x1 + (dirA_x ? (step_cnt - abs_dyA) : -(step_cnt - abs_dyA)), y2};
              step_cnt <= step_cnt + 1;
            end
          end else begin
            state <= GEN_B1;
            step_cnt <= 0;
          end
        end

        GEN_B1: begin
          if (step_cnt <= lenB) begin
            if (step_cnt == 0) begin
              pathB1[0] <= {x3, y3};
              step_cnt <= step_cnt + 1;
            end else if (step_cnt <= abs_dxB) begin
              pathB1[step_cnt] <= {x3 + (dirB_x ? step_cnt : -step_cnt), y3};
              step_cnt <= step_cnt + 1;
            end else begin
              pathB1[step_cnt] <= {x4, y3 + (dirB_y ? (step_cnt - abs_dxB) : -(step_cnt - abs_dxB))};
              step_cnt <= step_cnt + 1;
            end
          end else begin
            state <= GEN_B2;
            step_cnt <= 0;
          end
        end

        GEN_B2: begin
          if (step_cnt <= lenB) begin
            if (step_cnt == 0) begin
              pathB2[0] <= {x3, y3};
              step_cnt <= step_cnt + 1;
            end else if (step_cnt <= abs_dyB) begin
              pathB2[step_cnt] <= {x3, y3 + (dirB_y ? step_cnt : -step_cnt)};
              step_cnt <= step_cnt + 1;
            end else begin
              pathB2[step_cnt] <= {x3 + (dirB_x ? (step_cnt - abs_dyB) : -(step_cnt - abs_dyB)), y4};
              step_cnt <= step_cnt + 1;
            end
          end else begin
            state <= CHECK1;
            step_cnt <= 0;
            check_step <= 0;
            combo_idx <= 0;
            visited <= 64'h0;
          end
        end

        CHECK1, CHECK2, CHECK3, CHECK4: begin
          if (check_step < lenA) begin
            // Load A path points into visited
            reg [2:0] p_x, p_y;
            reg [5:0] point;
            case (state)
              CHECK1: point = pathA1[check_step];
              CHECK2: point = pathA1[check_step];
              CHECK3: point = pathA2[check_step];
              CHECK4: point = pathA2[check_step];
            endcase
            p_x = point[5:3];
            p_y = point[2:0];
            visited[{p_y, p_x}] <= 1'b1;
            check_step <= check_step + 1;
          end else if (check_step < (lenA + lenB)) begin
            // Check B path against visited
            reg [2:0] p_x, p_y;
            reg [5:0] point;
            reg [5:0] idx = check_step - lenA;
            case (state)
              CHECK1: point = pathB1[idx];
              CHECK2: point = pathB2[idx];
              CHECK3: point = pathB1[idx];
              CHECK4: point = pathB2[idx];
            endcase
            p_x = point[5:3];
            p_y = point[2:0];
            if (visited[{p_y, p_x}]) begin
              // Early termination on conflict
              check_step <= lenA + lenB;
            end else begin
              check_step <= check_step + 1;
            end
          end else begin
            // Combination check complete
            if (check_step == (lenA + lenB)) begin
              valid_found <= 1'b1;
            end
            visited <= 64'h0;
            check_step <= 0;
            combo_idx <= combo_idx + 1;
            case (state)
              CHECK1: state <= CHECK2;
              CHECK2: state <= CHECK3;
              CHECK3: state <= CHECK4;
              CHECK4: state <= FINISH;
            endcase
          end
        end

        FINISH: begin
          if (valid_found) begin
            result <= {1'b0, lenA + lenB};
          end else begin
            result <= 6'b100000;
          end
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule