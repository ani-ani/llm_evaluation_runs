module rectangle_intersect(
  input clk,
  input rst_n,
  input load,
  input start,
  input [15:0] x1,
  input [15:0] y1,
  input [15:0] x2,
  input [15:0] y2,
  output reg result,
  output reg done
);

  typedef struct packed {
    logic [15:0] x1;
    logic [15:0] y1;
    logic [15:0] x2;
    logic [15:0] y2;
  } rect_t;

  rect_t [7:0] rects;
  logic [3:0] num_rect;
  typedef enum logic [0:0] {IDLE, COMPARE} state_t;
  state_t state;
  logic [2:0] i_reg, j_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      num_rect <= 4'd0;
      rects <= '{default:0};
      result <= 1'b0;
      done <= 1'b0;
      i_reg <= 3'd0;
      j_reg <= 3'd0;
    end else begin
      case(state)
        IDLE: begin
          done <= 1'b0;
          if (load) begin
            if (num_rect < 4'd8) begin
              rects[num_rect[2:0]] <= {x1, y1, x2, y2};
              num_rect <= num_rect + 4'd1;
            end
          end else if (start) begin
            if (num_rect < 4'd2) begin
              done <= 1'b1;
              result <= 1'b0;
            end else begin
              state <= COMPARE;
              i_reg <= 3'd0;
              j_reg <= 3'd1;
            end
          end
        end

        COMPARE: begin
          rect_t a = rects[i_reg];
          rect_t b = rects[j_reg];
          logic no_overlap = (a.x2 <= b.x1) || (b.x2 <= a.x1) || (a.y2 <= b.y1) || (b.y2 <= a.y1);
          if (!no_overlap) begin
            done <= 1'b1;
            result <= 1'b1;
            state <= IDLE;
          end else begin
            if (j_reg < (num_rect - 4'd1)) begin
              j_reg <= j_reg + 3'd1;
            end else begin
              if (i_reg < (num_rect - 4'd2)) begin
                i_reg <= i_reg + 3'd1;
                j_reg <= i_reg + 3'd2;
              end else begin
                done <= 1'b1;
                result <= 1'b0;
                state <= IDLE;
              end
            end
          end
        end
      endcase
    end
  end

endmodule