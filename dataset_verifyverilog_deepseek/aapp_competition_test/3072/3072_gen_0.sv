module max_table_perimeter(
  input clk,
  input rst_n,
  input start,
  input [63:0] grid_flat,
  output reg [5:0] max_perimeter,
  output reg done
);

typedef enum logic [1:0] { IDLE, CALCULATING, DONE } state_t;
state_t state, next_state;

reg [11:0] cycle;
wire [2:0] i = cycle[11:9];
wire [2:0] j = cycle[8:6];
wire [2:0] k = cycle[5:3];
wire [2:0] l = cycle[2:0];

wire rectangle_valid = (i <= k) && (j <= l);

wire [63:0] cell_in_rect;
wire any_blocked_in_rect;
generate
  genvar row, col;
  for (row = 0; row < 8; row = row + 1) begin : gen_rows
    for (col = 0; col < 8; col = col + 1) begin : gen_cols
      assign cell_in_rect[row*8 + col] = (row >= i) && (row <= k) && (col >= j) && (col <= l);
    end
  end
endgenerate

assign any_blocked_in_rect = |(grid_flat & cell_in_rect);
wire valid_rect = rectangle_valid && !any_blocked_in_rect;

wire [3:0] width = l - j + 1;
wire [3:0] height = k - i + 1;
wire [5:0] perimeter_temp = ((width + height) << 1) - 1;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    max_perimeter <= 0;
    done <= 0;
    cycle <= 0;
  end else begin
    done <= 0;
    case (state)
      IDLE: begin
        if (start) begin
          state <= CALCULATING;
          cycle <= 0;
          max_perimeter <= 0;
        end
      end
      CALCULATING: begin
        if (cycle == 12'd4095) begin
          state <= DONE;
        end else begin
          cycle <= cycle + 12'd1;
        end

        if (valid_rect && (perimeter_temp > max_perimeter)) begin
          max_perimeter <= perimeter_temp;
        end
      end
      DONE: begin
        done <= 1;
        state <= IDLE;
      end
    endcase
  end
end

endmodule