module diophantine_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] a,
  input [7:0] b,
  input [7:0] n,
  output reg [7:0] x,
  output reg [7:0] y,
  output reg done,
  output reg no_sol
);
  
  typedef enum logic [1:0] {IDLE, COMPUTING, DONE} state_t;
  reg [7:0] a_reg, b_reg, n_reg;
  state_t state, next_state;
  reg [7:0] i;
  
  wire [15:0] product = i * a_reg;
  wire [15:0] n_16 = {8'b0, n_reg};
  wire [15:0] remainder = n_16 - product;
  wire rem_divisible = (remainder % b_reg) == 0;
  wire [7:0] y_val = remainder / b_reg;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      i <= 0;
      done <= 0;
      no_sol <= 0;
      a_reg <= 0;
      b_reg <= 0;
      n_reg <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            a_reg <= a;
            b_reg <= b;
            n_reg <= n;
            i <= 0;
          end
          done <= 0;
        end
        
        COMPUTING: begin
          if (next_state == COMPUTING) begin
            if ((product <= n_16) && !rem_divisible && (i != 8'hFF)) begin
              i <= i + 1;
            end
          end else if (next_state == DONE) begin
            done <= 1;
            if ((product <= n_16) && rem_divisible) begin
              no_sol <= 0;
              x <= i;
              y <= y_val;
            end else begin
              no_sol <= 1;
            end
          end
        end
        
        DONE: begin
          done <= 0;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: next_state = start ? COMPUTING : IDLE;
      
      COMPUTING: begin
        if (product <= n_16) begin
          if (rem_divisible) begin
            next_state = DONE;
          end else begin
            if (i == 8'hFF) next_state = DONE;
            else next_state = COMPUTING;
          end
        end else begin
          next_state = DONE;
        end
      end
      
      DONE: next_state = IDLE;
      
      default: next_state = IDLE;
    endcase
  end
  
endmodule