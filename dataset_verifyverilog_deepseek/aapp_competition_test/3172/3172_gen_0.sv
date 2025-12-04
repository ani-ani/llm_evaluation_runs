module max_fruits_sliced(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] x [0:7],
  input [31:0] y [0:7],
  output reg [3:0] max_count,
  output reg done
);

typedef enum logic [1:0] {IDLE, PROCESS_PAIRS, CHECK_LINES, FINISH} state_t;
reg [1:0] state, next_state;

reg [2:0] i, j;
reg [2:0] k;
reg [31:0] xi, yi;
reg signed [31:0] dx, dy;
reg [63:0] d_sq;
reg [3:0] count_line1, count_line2;

wire all_pairs_done = (i == 3'b110) & (j == 3'b111);

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    max_count <= 4'b0;
    done <= 1'b0;
    i <= 3'b0;
    j <= 3'b001;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= PROCESS_PAIRS;
          max_count <= 4'b0;
          done <= 1'b0;
          i <= 3'b0;
          j <= 3'b001;
        end
      end
      
      PROCESS_PAIRS: begin
        xi <= x[i];
        yi <= y[i];
        dx <= $signed(x[j] - x[i]);
        dy <= $signed(y[j] - y[i]);
        d_sq <= (dx*dx) + (dy*dy);
        k <= 3'b0;
        count_line1 <= 4'b0;
        count_line1 <= 4'b0;
        state <= CHECK_LINES;
      end
      
      CHECK_LINES: begin
        if (k == 3'b111) begin
          if (d_sq < (x[k]*x[k] + y[k]*y[k])) begin
            max_count <= count_line1;
          end
          if (all_pairs_done) begin
            state <= FINISH;
          end else begin
            state <= PROCESS_PAIRS;
          end
        end else begin
          state <= CHECK_LINES;
        end
      end
      
      FINISH: begin
        done <= 1'b1;
      end
    endcase
  end
end
endmodule