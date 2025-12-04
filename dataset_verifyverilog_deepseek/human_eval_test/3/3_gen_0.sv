module balance_checker (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] ops [0:7],
  input [2:0] op_count,
  output reg below_zero_flag,
  output reg done
);

  typedef enum {IDLE, PROCESSING} state_t;
  state_t state;

  reg start_prev;
  reg [2:0] counter;
  reg signed [11:0] current_balance;
  
  wire signed [11:0] signed_op = {{4{ops[counter][7]}}, ops[counter]};
  wire signed [11:0] next_balance = current_balance + signed_op;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 3'b0;
      current_balance <= 12'sd0;
      below_zero_flag <= 1'b0;
      done <= 1'b0;
      start_prev <= 1'b0;
    end else begin
      start_prev <= start;
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start && !start_prev) begin
            state <= PROCESSING;
            counter <= 3'b0;
            current_balance <= 12'sd0;
            below_zero_flag <= 1'b0;
          end
        end
        
        PROCESSING: begin
          if (counter < op_count) begin
            current_balance <= next_balance;
            below_zero_flag <= below_zero_flag || (next_balance < 0);
            counter <= counter + 1;
          end
          
          if (counter >= op_count) begin
            done <= 1'b1;
            state <= IDLE;
          end
        end
      endcase
    end
  end
endmodule