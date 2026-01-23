module array_rotator (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] arr [0:7],
  output reg [7:0] result [0:7],
  output reg done
);

  typedef enum logic [0:0] {
    IDLE,
    PROCESSING
  } state_t;

  state_t current_state, next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  always @(*) begin
    next_state = current_state;
    done = 1'b0;

    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end

      PROCESSING: begin
        next_state = IDLE;
        done = 1'b1;
      end
    endcase
  end

  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : rotate_logic
      always @(*) begin
        if (current_state == PROCESSING) begin
          result[i] = arr[(i + n) % 8];
        end else begin
          result[i] = 8'b0;
        end
      end
    end
  endgenerate

endmodule