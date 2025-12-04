module hash_word_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [24:0] K,
  input [4:0] M,
  output reg [46:0] count,
  output reg done
);

  typedef enum logic [1:0] {IDLE, INIT, PROCESSING, DONE} state_t;
  state_t state, next_state;

  reg [3:0] step;
  wire [24:0] mod_mask = (1 << M) - 1;
  reg [46:0] current_dp [0:1<<25];
  reg [46:0] next_dp [0:1<<25];

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      count <= 0;
      done <= 0;
      step <= 0;
      for (int i=0; i<=(1<<25); i=i+1) current_dp[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            next_state <= INIT;
            state <= next_state;
          end
        end
        
        INIT: begin
          for (int i=0; i<=(1<<25); i=i+1) current_dp[i] <= 0;
          current_dp[0] <= 1;
          step <= 0;
          next_state <= PROCESSING;
          state <= next_state;
        end
        
        PROCESSING: begin
          if (step < N) begin
            for (int i=0; i<=(1<<25); i=i+1) next_dp[i] <= 0;
            for (int j=0; j<=(1<<25); j=j+1) begin
              if (j <= mod_mask && current_dp[j] !=0) begin
                for (int c=1; c<=26; c=c+1) begin
                  automatic logic [31:0] product = j * 33;
                  automatic logic [24:0] new_hash = (product ^ c) & mod_mask;
                  next_dp[new_hash] <= next_dp[new_hash] + current_dp[j];
                end
              end
            end
            current_dp <= next_dp;
            step <= step + 1;
          end else begin
            count <= current_dp[K & mod_mask];
            next_state <= DONE;
            state <= next_state;
          end
        end
        
        DONE: begin
          done <= 1;
          next_state <= IDLE;
          state <= next_state;
        end
      endcase
    end
  end

endmodule