module bell_number (input clk, input rst_n, input start, input [2:0] n, output reg [5:0] bell_out, output reg done);
  localparam IDLE = 2'b00;
  localparam INIT_ROW = 2'b01;
  localparam COMPUTE_COL = 2'b10;
  localparam FINISH = 2'b11;
  
  reg [1:0] state, next_state;
  reg [2:0] i, j;
  reg [2:0] n_reg;
  reg [5:0] bell_array [0:5][0:5];
  integer row, col;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      bell_out <= 6'd0;
      done <= 1'b0;
      for (row = 0; row < 6; row=row+1) begin
        for (col = 0; col < 6; col=col+1) begin
          bell_array[row][col] <= 6'd0;
        end
      end
      i <= 3'd0;
      j <= 3'd0;
      n_reg <= 3'd0;
    end else begin
      state <= next_state;
      done <= (state == FINISH);
      case(state)
        IDLE: begin
          if (start) begin
            bell_array[0][0] <= 6'd1;
            n_reg <= n;
            if (n != 0) i <= 3'd1;
          end
        end
        INIT_ROW: begin
          bell_array[i][0] <= bell_array[i-1][i-1];
          j <= 3'd1;
        end
        COMPUTE_COL: begin
          bell_array[i][j] <= bell_array[i-1][j-1] + bell_array[i][j-1];
          if (j < i) j <= j + 1;
          else i <= i + 1;
        end
        FINISH: bell_out <= bell_array[n_reg][0];
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case(state)
      IDLE: if (start) next_state = (n == 3'd0) ? FINISH : INIT_ROW;
      INIT_ROW: next_state = COMPUTE_COL;
      COMPUTE_COL: if (j == i) next_state = (i < n_reg) ? INIT_ROW : FINISH;
      FINISH: next_state = IDLE;
    endcase
  end
endmodule