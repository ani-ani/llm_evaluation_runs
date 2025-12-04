module soda_pouring (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [6:0] a [0:7],
  input [6:0] b [0:7],
  output reg [3:0] k,
  output reg [9:0] t,
  output reg done
);

  // State declaration
  typedef enum {IDLE, COMPUTE, DONE} state_t;
  state_t state, next_state;
  
  // Internal signals
  reg [2:0] cycle_count;
  reg [3:0] dp_k [0:800];
  reg [9:0] dp_t [0:800];
  reg [9:0] sum_a;
  
  // Bottle loop counter
  reg [2:0] bottle_idx;
  
  // Combinational sum calculation
  always_comb begin
    sum_a = 0;
    for (int i=0; i<8; i++) begin
      if (i < n) sum_a = sum_a + a[i];
    end
  end
  
  // State transition
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      k <= 0;
      t <= 0;
      cycle_count <= 0;
      bottle_idx <= 0;
      // Initialize DP with max values (invalid)
      for (int i=0; i<=800; i++) begin
        dp_k[i] <= 4'hF;
        dp_t[i] <= 10'h3FF;
      end
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTE;
            cycle_count <= 0;
            bottle_idx <= 0;
            
            // Initialize DP table
            for (int i=1; i<=800; i++) begin
              dp_k[i] <= 4'hF;
              dp_t[i] <= 10'h3FF;
            end
            dp_k[0] <= 0;
            dp_t[0] <= 0;
          end
          done <= 0;
        end
      
        COMPUTE: begin
          if (cycle_count < 3'd9) cycle_count <= cycle_count + 1;
          
          // Process each bottle in sequence
          if (bottle_idx < n) begin
            // Dynamic programming update
            for (int j=800; j>=0; j--) begin
              if (dp_k[j] != 4'hF) begin
                int new_j = j + a[bottle_idx];
                if (new_j <= 800) begin
                  int new_t = dp_t[j] + (b[bottle_idx] - a[bottle_idx]);
                  if ((dp_k[new_j] > dp_k[j] + 1) || 
                      (dp_k[new_j] == dp_k[j] + 1 && dp_t[new_j] > new_t)) begin
                    dp_k[new_j] <= dp_k[j] + 1;
                    dp_t[new_j] <= new_t;
                  end
                end
              end
            end
            bottle_idx <= bottle_idx + 1;
          end
          
          if (cycle_count >= 3'd9) begin
            k <= dp_k[sum_a];
            t <= dp_t[sum_a];
            state <= DONE;
          end
        end
      
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule