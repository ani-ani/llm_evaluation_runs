module int_base_converter (
  input clk,
  input rst_n,
  input start,
  input [7:0] x,
  input [3:0] base,
  output reg [31:0] digits,
  output reg valid
);

typedef enum logic [1:0] { IDLE, DIVIDE, REVERSE } State;
State current_state;

reg [3:0] count;
reg [7:0] quotient;
reg [3:0] digit_array [0:7];

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    digits <= 32'b0;
    valid <= 1'b0;
    count <= 4'b0;
    quotient <= 8'b0;
    for (int i=0; i<8; i++) digit_array[i] <= 4'b0;
  end else begin
    valid <= 1'b0;
    case (current_state)
      IDLE: begin
        if (start) begin
          quotient <= x;
          count <= 0;
          current_state <= DIVIDE;
        end
      end

      DIVIDE: begin
        digit_array[count] <= quotient % base;
        quotient <= quotient / base;
        if (count == 3'b111) begin
          count <= 0;
          current_state <= REVERSE;
        end else begin
          count <= count + 1;
        end
      end

      REVERSE: begin
        digits[ (count * 4) +:4 ] <= digit_array[7 - count];
        if (count == 3'b111) begin
          valid <= 1'b1;
          current_state <= IDLE;
        end else begin
          count <= count + 1;
        end
      end

      default: current_state <= IDLE;
    endcase
  end
end

endmodule