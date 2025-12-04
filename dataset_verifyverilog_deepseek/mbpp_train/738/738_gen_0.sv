module geometric_sum (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [31:0] sum_q16,
  output reg done
);

typedef enum logic {IDLE, COMPUTE} state_t;

reg state_t state, next_state;
reg [3:0] k, next_k;
reg [31:0] sum, next_sum;
reg next_done;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    k <= '0;
    sum <= '0;
    done <= '0;
  end else begin
    state <= next_state;
    k <= next_k;
    sum <= next_sum;
    done <= next_done;
  end
end

always_comb begin
  next_state = state;
  next_k = k;
  next_sum = sum;
  next_done = '0;

  unique case (state)
    IDLE: begin
      if (start) begin
        next_state = COMPUTE;
        next_k = '0;
        next_sum = '0;
      end else begin
        next_done = '1;
      end
    end
    
    COMPUTE: begin
      if (k <= n) begin
        next_sum = sum + (32'h00010000 >> k);
        next_k = k + 1;
        
        if (next_k > n) begin
          next_state = IDLE;
          next_done = '1;
        end
      end else begin
        next_state = IDLE;
        next_done = '1;
      end
    end
  endcase
end

assign sum_q16 = sum;

endmodule