module cube_checker (
  input clk,
  input rst_n,
  input start,
  input signed [15:0] a,
  output reg is_cube,
  output reg done
);

  localparam IDLE   = 2'b00;
  localparam COMPUTE = 2'b01;
  localparam DONE   = 2'b10;

  reg [1:0] state, next_state;
  reg [8:0] n;           // iterates from 0 to 255 (we map to -128..+127)
  reg found;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Control and data updates
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      is_cube <= 1'b0;
      done    <= 1'b0;
      found   <= 1'b0;
      n       <= 9'b0;
    end else begin
      case (next_state)
        IDLE: begin
          done    <= 1'b0;
          is_cube <= 1'b0;
          found   <= 1'b0;
          n       <= 9'b0;
        end
        COMPUTE: begin
          // signed 9-bit n in [-128,127]
          automatic int n_int = $signed({1'b0, n}) - 128;
          automatic int cube  = n_int * n_int * n_int;
          if (cube == $signed(a)) found <= 1'b1;
          n <= n + 1;
        end
        DONE: begin
          is_cube <= found;
          done    <= 1'b1;
        end
        default: begin
          is_cube <= 1'b0;
          done    <= 1'b0;
          found   <= 1'b0;
          n       <= 9'b0;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   next_state = (start ? COMPUTE : IDLE);
      COMPUTE: begin
        if (found) next_state = DONE;
        else if (n == 8'd255) next_state = DONE; // finished scanning [-128..127]
        else next_state = COMPUTE;
      end
      DONE:   next_state = (start ? DONE : IDLE);
      default next_state = IDLE;
    endcase
  end

endmodule
