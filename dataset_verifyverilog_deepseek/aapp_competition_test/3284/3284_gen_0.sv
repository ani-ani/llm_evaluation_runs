module coprime_pairs_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] a,
  input [3:0] b,
  input [3:0] c,
  input [3:0] d,
  output reg [7:0] count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, COMPUTING, DONE} state_t;
  state_t current_state, next_state;

  reg [3:0] x_counter;
  reg [3:0] y_counter;
  logic [3:0] gcd_out;

  function automatic logic [3:0] gcd(input [3:0] a, input [3:0] b);
    logic [3:0] temp;
    while (b != 0) begin
      temp = b;
      b = a % b;
      a = temp;
    end
    gcd = a;
  endfunction

  assign gcd_out = gcd(x_counter, y_counter);

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE    : if (start) next_state = COMPUTING;
      COMPUTING: if ((x_counter == b) && (y_counter == d)) next_state = DONE;
      DONE    : if (start) next_state = COMPUTING;
      default : next_state = IDLE;
    endcase
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      count <= 0;
      done <= 0;
      x_counter <= 0;
      y_counter <= 0;
    end else begin
      current_state <= next_state;
      case (next_state)
        COMPUTING: begin
          if (current_state != COMPUTING) begin
            x_counter <= a;
            y_counter <= c;
            count <= 0;
            done <= 0;
          end else begin
            if (gcd_out == 4'd1) count <= count + 1;
            if (y_counter < d) begin
              y_counter <= y_counter + 1;
            end else begin
              y_counter <= c;
              if (x_counter < b) x_counter <= x_counter + 1;
            end
          end
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule