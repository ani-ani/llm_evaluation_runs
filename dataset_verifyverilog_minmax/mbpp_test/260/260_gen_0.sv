module nsw_prime(
  input clk,
  input rst_n,
  input start,
  input [4:0] n_in,
  output reg [15:0] result,
  output reg done
);
  // internal signals
  reg start_d;
  reg [1:0] state;
  reg [4:0] counter;
  reg [15:0] prev, curr, next;
  
  parameter IDLE = 2'b00;
  parameter INIT = 2'b01;
  parameter RUN  = 2'b10;
  parameter ONE  = 2'b11;
  
  // detect start pulse
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) start_d <= 1'b0;
    else        start_d <= start;
  end
  
  wire start_pulse = start && !start_d;
  
  // main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      result  <= 16'd0;
      done    <= 1'b0;
      prev    <= 16'd0;
      curr    <= 16'd0;
      next    <= 16'd0;
      counter <= 5'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start_pulse) begin
            if ((n_in == 5'd0) || (n_in == 5'd1)) begin
              state <= ONE; // single-cycle result
            end else begin
              // initialize registers for iterative computation
              prev    <= 16'd1; // S_0
              curr    <= 16'd1; // S_1
              counter <= n_in - 1; // number of iterations to perform
              state   <= INIT;
            end
          end
        end
        
        INIT: begin
          // stay in INIT for one clock cycle then go to RUN
          state <= RUN;
        end
        
        RUN: begin
          // compute next NSW value
          next <= (curr << 1) + prev; // 2*curr + prev
          prev <= curr;
          curr <= next;
          if (counter == 5'd0) begin
            // no iteration needed, just output S_1 (should not happen for n>=2)
            result <= curr;
            done   <= 1'b1;
            state  <= IDLE;
          end else begin
            // perform iteration and check if this is the last one
            if (counter == 5'd1) begin
              // this is the final iteration
              result <= curr;
              done   <= 1'b1;
              state  <= IDLE;
            end
            counter <= counter - 1;
          end
        end
        
        ONE: begin
          // single-cycle result for n=0 or 1
          result <= 16'd1;
          done   <= 1'b1;
          state  <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
endmodule
