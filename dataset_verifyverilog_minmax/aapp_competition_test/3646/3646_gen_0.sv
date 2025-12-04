module frog_jump_max_distance(
  input clk, // system clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [3:0] N, // number of pebbles (1-16)
  input [15:0] spots [0:15], // spot counts for up to 16 pebbles
  output reg [3:0] max_distance, // 0-based index of farthest reachable pebble
  output reg done // high when computation complete
);

  // State machine states
  localparam IDLE = 2'b00;
  localparam RUN = 2'b01;
  localparam DONE = 2'b10;

  // State registers
  reg [1:0] state;
  
  // BFS state
  reg [15:0] visited;
  reg [15:0] current_level;
  reg [15:0] next_level;
  reg [3:0] next_max;

  // Combinational logic to compute next_level and next_max
  always_comb begin
    next_level = 16'h0;
    next_max = 4'h0;
    
    // Compute children of current level
    for (int j = 0; j < 16; j++) begin
      if (j < N) begin
        if (!visited[j]) begin
          for (int i = 0; i < j; i++) begin
            if (current_level[i] && (spots[i] + spots[j] == (j - i))) begin
              next_level[j] = 1'b1;
            end
          end
        end
      end
    end
    
    // Find maximum index in next_level
    for (int j = 0; j < 16; j++) begin
      if (next_level[j]) begin
        next_max = j;
      end
    end
  end

  // State machine and BFS logic
  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      visited <= 16'h0;
      current_level <= 16'h0;
      max_distance <= 4'h0;
      done <= 1'b0;
    end
    else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RUN;
            visited <= 16'h1;      // Mark pebble 0 as visited
            current_level <= 16'h1; // Start BFS with pebble 0
            max_distance <= 4'h0;
            done <= 1'b0;
          end
        end
        
        RUN: begin
          if (next_level == 16'h0) begin
            state <= DONE;
            done <= 1'b1;
          end
          else begin
            visited <= visited | next_level;
            current_level <= next_level;
            
            // Update max_distance if new pebbles are discovered
            if (next_max > max_distance) begin
              max_distance <= next_max;
            end
          end
        end
        
        DONE: begin
          if (start) begin
            state <= RUN;
            visited <= 16'h1;
            current_level <= 16'h1;
            max_distance <= 4'h0;
            done <= 1'b0;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule