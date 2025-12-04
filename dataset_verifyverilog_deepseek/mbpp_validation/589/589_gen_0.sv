module perfect_squares (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  output reg [7:0] square_out,
  output reg valid,
  output reg done
);

typedef enum logic [1:0] {IDLE, PROCESSING, DONE} state_t;
state_t current_state;

reg [7:0] a_reg, b_reg;
reg [7:0] j;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    a_reg <= 0;
    b_reg <= 0;
    j <= 0;
    square_out <= 0;
    valid <= 0;
    done <= 0;
  end else begin
    valid <= 0;
    done <= 0;

    case (current_state)
      IDLE: begin
        if (start) begin
          a_reg <= a;
          b_reg <= b;
          j <= 8'd1;
          current_state <= PROCESSING;
        end
      end

      PROCESSING: begin
        reg [15:0] current_j_square = j * j;
        if ((current_j_square >= a_reg) && (current_j_square <= b_reg)) begin
          square_out <= current_j_square[7:0];
          valid <= 1;
        end

        j <= j + 1;
        reg [15:0] next_j_square = (j + 1) * (j + 1);

        if (next_j_square > b_reg) current_state <= DONE;
        else current_state <= PROCESSING;
      end

      DONE: begin
        done <= 1;
        current_state <= IDLE;
      end

      default: current_state <= IDLE;
    endcase
  end
end

endmodule