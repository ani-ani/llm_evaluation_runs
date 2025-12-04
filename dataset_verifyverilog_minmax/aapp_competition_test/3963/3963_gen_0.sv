module coin_change (
  input clk,            // system clock
  input rst_n,          // active-low reset
  input start,          // start computation
  input [2:0] num_coins, // number of coin types (1-8)
  input [7:0] a [0:6],  // denomination ratios (a1-a7) for n>=2
  input [7:0] b [0:7],  // coin counts (b1-b8)
  input [7:0] m,        // target amount (0-255)
  output reg [29:0] result, // result % 1e9+7
  output reg done       // high when complete
);
  
  // State machine states
  typedef enum {IDLE, PROCESSING, DONE} state_t;
  state_t state, next_state;
  
  // Current coin index
  reg [2:0] current_coin;
  reg [2:0] next_current_coin;
  
  // DP arrays
  reg [29:0] d [0:255];        // current DP state
  reg [29:0] d_next [0:255];   // next DP state
  reg [29:0] d_compressed [0:255]; // compressed array for denomination ratios
  
  // Internal state variables
  reg [7:0] max_index;         // maximum index for current processing
  reg [7:0] current_size;      // current size of DP array
  
  // FSM next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) 
          next_state = PROCESSING;
        else
          next_state = IDLE;
        next_current_coin = 0;
      end
      PROCESSING: begin
        if (current_coin == num_coins) 
          next_state = DONE;
        else
          next_state = PROCESSING;
        next_current_coin = current_coin;
      end
      DONE: next_state = DONE;
      default: next_state = IDLE;
    endcase
  end
  
  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      for (int i=0; i<=255; i++) begin
        d[i] = 0;
      end
      d[0] = 1;  // Initialize DP array
      result <= 0;
      done <= 0;
      current_coin <= 0;
    end else begin
      state <= next_state;
      current_coin <= next_current_coin;
      
      if (state == IDLE) begin
        for (int i=0; i<=255; i++) begin
          d[i] = 0;
        end
        d[0] = 1;
      end
      
      if (state == PROCESSING) begin
        if (current_coin < num_coins) begin
          // Clear next state array
          for (int k=0; k<=255; k++) begin
            d_next[k] = 0;
          end
          
          // Determine current size and max index
          if (current_coin == 0) begin
            current_size = m + 1;
            max_index = m;
          end else if (a[current_coin-1] != 1) begin
            current_size = (m / a[current_coin-1]) + 1;
            max_index = m / a[current_coin-1];
          end else begin
            current_size = m + 1;
            max_index = m;
          end
          
          if (current_coin == 0) begin
            // First coin: no compression needed
            for (int k=0; k<=max_index; k++) begin
              d_next[k] = 0;
              for (int t=0; t<=b[0] && t<=k; t++) begin
                d_next[k] = (d_next[k] + d[k-t]) % 30'h3B9ACA00;
              end
            end
          end else begin
            if (a[current_coin-1] != 1) begin
              // Compression step
              for (int j=0; j<=max_index; j++) begin
                d_compressed[j] = d[j * a[current_coin-1]];
              end
              
              // Convolution on compressed array
              for (int k=0; k<=max_index; k++) begin
                d_next[k] = 0;
                for (int t=0; t<=b[current_coin] && t<=k; t++) begin
                  d_next[k] = (d_next[k] + d_compressed[k-t]) % 30'h3B9ACA00;
                end
              end
            end else begin
              // No compression
              for (int k=0; k<=max_index; k++) begin
                d_next[k] = 0;
                for (int t=0; t<=b[current_coin] && t<=k; t++) begin
                  d_next[k] = (d_next[k] + d[k-t]) % 30'h3B9ACA00;
                end
              end
            end
          end
          
          // Update DP array
          for (int i=0; i<=255; i++) begin
            d[i] = d_next[i];
          end
          
          next_current_coin = current_coin + 1;
        end
      end
      
      if (state == DONE) begin
        done <= 1;
        if (m <= 255) 
          result <= d[m];
        else
          result <= 0;
      end
    end
  end
  
endmodule