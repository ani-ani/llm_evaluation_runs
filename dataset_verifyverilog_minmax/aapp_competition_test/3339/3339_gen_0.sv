module evenland_solution(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [89:0] edges,
  output reg [29:0] way,
  output reg done
);

localparam integer MOD = 1000000009;
localparam integer MAX_N = 8;
localparam integer MAX_M = 15;

localparam [2:0] IDLE   = 3'b000;
localparam [2:0] UNPACK = 3'b001;
localparam [2:0] ELIM   = 3'b010;
localparam [2:0] COMPUTE = 3'b011;
localparam [2:0] DONE   = 3'b100;

reg [2:0] state;
reg [3:0] elim_cycle;
reg [3:0] col;
reg [3:0] row;
reg [3:0] rank;
reg [3:0] exponent;
reg pivot_found;
reg [3:0] pivot_row;
reg [14:0] mat [0:7];
reg [3:0] i;
reg [3:0] j;

reg [29:0] pow2 [0:15];
integer k;
initial begin
  pow2[0] = 30'd1;
  for (k = 1; k < 16; k = k + 1) begin
    pow2[k] = (pow2[k-1] * 2) % MOD;
  end
end

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    way <= 30'd0;
    done <= 1'b0;
    elim_cycle <= 4'd0;
    col <= 4'd0;
    row <= 4'd0;
    rank <= 4'd0;
    exponent <= 4'd0;
    pivot_found <= 1'b0;
    pivot_row <= 4'd0;
    mat[0] <= 15'd0;
    mat[1] <= 15'd0;
    mat[2] <= 15'd0;
    mat[3] <= 15'd0;
    mat[4] <= 15'd0;
    mat[5] <= 15'd0;
    mat[6] <= 15'd0;
    mat[7] <= 15'd0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= UNPACK;
        end
        done <= 1'b0;
      end
      UNPACK: begin
        for (i = 0; i < 8; i = i + 1) begin
          mat[i] <= 15'd0;
        end
        for (i = 0; i < m; i = i + 1) begin
          logic [5:0] edge_bits;
          logic [2:0] node_a, node_b;
          edge_bits = edges[i*6 +: 6];
          node_a = edge_bits[5:3];
          node_b = edge_bits[2:0];
          mat[node_a - 1][i] <= 1'b1;
          mat[node_b - 1][i] <= 1'b1;
        end
        elim_cycle <= 4'd0;
        col <= 4'd0;
        row <= 4'd0;
        rank <= 4'd0;
        state <= ELIM;
      end
      ELIM: begin
        if (col < m) begin
          pivot_found <= 1'b0;
          for (i = row; i < n; i = i + 1) begin
            if (!pivot_found && mat[i][col]) begin
              pivot_found <= 1'b1;
              pivot_row <= i;
            end
          end
          if (pivot_found) begin
            if (pivot_row != row) begin
              mat[pivot_row] <= mat[row];
              mat[row] <= mat[pivot_row];
            end
            for (j = 0; j < n; j = j + 1) begin
              if (j != row && mat[j][col]) begin
                mat[j] <= mat[j] ^ mat[row];
              end
            end
            rank <= rank + 1;
            row <= row + 1;
          end
          col <= col + 1;
        end
        elim_cycle <= elim_cycle + 1;
        if (elim_cycle == 4'd7) begin
          exponent <= m - rank;
          state <= COMPUTE;
        end
      end
      COMPUTE: begin
        way <= pow2[exponent];
        state <= DONE;
      end
      DONE: begin
        done <= 1'b1;
        state <= IDLE;
      end
      default: state <= IDLE;
    endcase
  end
end

endmodule