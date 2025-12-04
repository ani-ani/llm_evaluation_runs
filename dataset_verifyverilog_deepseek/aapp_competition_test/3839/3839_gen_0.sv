module knight_placement_generator(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg valid,
  output reg done
);

  reg [3:0] index;
  reg [1:0] state;
  
  parameter IDLE = 2'b00;
  parameter GEN_VALID = 2'b01;
  parameter GEN_WAIT = 2'b10;
  parameter DONE_ST = 2'b11;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      x <= 0;
      y <= 0;
      valid <= 0;
      done <= 0;
      index <= 0;
      state <= IDLE;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            index <= 0;
            valid <= 0;
            done <= 0;
            state <= GEN_VALID;
          end
        end

        GEN_VALID: begin
          valid <= 1;
          done <= 0;
          
          case (index % 3)
            0: begin
              x <= (index / 3) * 2;
              y <= 0;
            end
