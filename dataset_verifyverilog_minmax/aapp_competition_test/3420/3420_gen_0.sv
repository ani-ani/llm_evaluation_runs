module book_presentations(
  input clk,          // system clock
  input rst_n,        // active-low reset
  input start,        // start computation
  input [15:0] bipartite_graph, // 4 boys x 4 girls (row-major: boy[3:0] x girl[3:0])
  output reg [2:0] max_matching,// matching size (0-4)
  output reg done      // result valid signal
);

  // State machine states
  localparam IDLE = 0;
  localparam BFS = 1;
  localparam DFS1 = 2;
  localparam DFS2 = 3;
  localparam DFS3 = 4;
  localparam DFS4 = 5;
  localparam UPDATE = 6;
  localparam CHECK = 7;
  localparam DONE = 8;

  reg [3:0] state, next_state;
  integer i, j;

  // Matching arrays
  reg [2:0] match_boy[3:0];   // matched girl for each boy (0-3 for girls, 4 for unmatched)
  reg [2:0] match_girl[3:0];  // matched boy for each girl (0-3 for boys, 4 for unmatched)

  // BFS data
  reg [2:0] parent_girl[3:0]; // parent boy for each girl
  reg [2:0] parent_boy[3:0];  // parent girl for each boy
  reg [3:0] free_girls_layer3; // bitmask of free girls in layer3
  reg [3:0] in_layer1;         // bitmask of girls in layer1
  reg [3:0] in_layer3;         // bitmask of girls in layer3

  // DFS temporary data
  reg [2:0] change_boy[3:0];   // temporary matching for the phase
  reg [2:0] change_girl[3:0];
  reg found_any;               // flag if any augmenting path found in this phase

  // State machine sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_matching <= 0;
      for (i = 0; i < 4; i++) begin
        match_boy[i] <= 4;
        match_girl[i] <= 4;
      end
      found_any <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = IDLE;
    case (state)
      IDLE: next_state = start ? BFS : IDLE;
      BFS: next_state = DFS1;
      DFS1: next_state = DFS2;
      DFS2: next_state = DFS3;
      DFS3: next_state = DFS4;
      DFS4: next_state = UPDATE;
      UPDATE: next_state = CHECK;
      CHECK: next_state = found_any ? BFS : DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State machine combinational logic
  always @(*) begin
    case (state)
      IDLE: begin
        done = 0;
      end
      
      BFS: begin
        // Initialize
        for (j = 0; j < 4; j++) begin
          parent_girl[j] = 4;
          parent_boy[j] = 4;
          in_layer1[j] = 0;
          in_layer3[j] = 0;
          free_girls_layer3[j] = 0;
        end
        found_any = 0;
        for (i = 0; i < 4; i++) begin
          change_boy[i] = match_boy[i];
          change_girl[i] = match_girl[i];
        end

        // Step 1: Process free boys (layer 0)
        for (i = 0; i < 4; i++) begin
          if (match_boy[i] == 4) begin // free boy
            for (j = 0; j < 4; j++) begin
              if (bipartite_graph[i*4+j] == 1) begin
                if (parent_girl[j] == 4) begin
                  parent_girl[j] = i;
                  in_layer1[j] = 1;
                end
              end
            end
          end
        end

        // Step 2: Process girls in layer 1 to get boys in layer 2
        for (j = 0; j < 4; j++) begin
          if (in_layer1[j]) begin
            if (match_girl[j] != 4) begin // girl is matched
              i = match_girl[j];
              if (parent_boy[i] == 4) begin
                parent_boy[i] = j;
              end
            end
          end
        end

        // Step 3: Process boys in layer 2 to get girls in layer 3
        for (i = 0; i < 4; i++) begin
          if (parent_boy[i] != 4) begin // boy in layer 2
            for (j = 0; j < 4; j++) begin
              if (bipartite_graph[i*4+j] == 1) begin
                if (parent_girl[j] == 4) begin
                  parent_girl[j] = i;
                  in_layer3[j] = 1;
                end
              end
            end
          end
        end

        // Identify free girls in layer 3
        for (j = 0; j < 4; j++) begin
          if (in_layer3[j] && match_girl[j] == 4) begin
            free_girls_layer3[j] = 1;
          end
        end
      end
      
      DFS1: begin
        // Process boy 0
        if (match_boy[0] == 4) begin // free boy
          for (j = 0; j < 4; j++) begin
            if (free_girls_layer3[j]) begin
              if (parent_girl[j] != 4) begin
                i = parent_girl[j]; // boy in layer 2
                if (parent_boy[i] != 4) begin
                  j = parent_boy[i]; // girl in layer 1
                  if (parent_girl[j] == 0) begin // free boy 0
                    // Update temporary matching
                    change_boy[0] = j;
                    change_girl[j] = 0;
                    change_boy[i] = j;
                    change_girl[j] = i;
                    found_any = 1;
                    j = 4; // break
                  end
                end
              end
            end
          end
        end
      end
      
      DFS2: begin
        // Process boy 1
        if (match_boy[1] == 4) begin // free boy
          for (j = 0; j < 4; j++) begin
            if (free_girls_layer3[j]) begin
              if (parent_girl[j] != 4) begin
                i = parent_girl[j]; // boy in layer 2
                if (parent_boy[i] != 4) begin
                  j = parent_boy[i]; // girl in layer 1
                  if (parent_girl[j] == 1) begin // free boy 1
                    // Update temporary matching
                    change_boy[1] = j;
                    change_girl[j] = 1;
                    change_boy[i] = j;
                    change_girl[j] = i;
                    found_any = 1;
                    j = 4; // break
                  end
                end
              endn            end
          end
        end
      end
      
      DFS3: begin
        // Process boy 2
        if (match_boy[2] == 4) begin // free boy
          for (j = 0; j < 4; j++) begin
            if (free_girls_layer3[j]) begin
              if (parent_girl[j] != 4) begin
                i = parent_girl[j]; // boy in layer 2
                if (parent_boy[i] != 4) begin
                  j = parent_boy[i]; // girl in layer 1
                  if (parent_girl[j] == 2) begin // free boy 2
                    // Update temporary matching
                    change_boy[2] = j;
                    change_girl[j] = 2;
                    change_boy[i] = j;
                    change_girl[j] = i;
                    found_any = 1;
                    j = 4; // break
                  end
                end
              end
            end
          end
        end
      end
      
      DFS4: begin
        // Process boy 3
        if (match_boy[3] == 4) begin // free boy
          for (j = 0; j < 4; j++) begin
            if (free_girls_layer3[j]) begin
              if (parent_girl[j] != 4) begin
                i = parent_girl[j]; // boy in layer 2
                if (parent_boy[i] != 4) begin
                  j = parent_boy[i]; // girl in layer 1
                  if (parent_girl[j] == 3) begin // free boy 3
                    // Update temporary matching
                    change_boy[3] = j;
                    change_girl[j] = 3;
                    change_boy[i] = j;
                    change_girl[j] = i;
                    found_any = 1;
                    j = 4; // break
                  end
                end
              end
            end
          end
        end
      end
      
      UPDATE: begin
        // Apply temporary matching changes
        for (i = 0; i < 4; i++) begin
          match_boy[i] = change_boy[i];
          match_girl[i] = change_girl[i];
        end
        
        // Calculate matching size
        max_matching = 0;
        for (i = 0; i < 4; i++) begin
          if (match_boy[i] != 4) begin
            max_matching = max_matching + 1;
          end
        end
      end
      
      CHECK: begin
        // done will be set in DONE state
      end
      
      DONE: begin
        done = 1;
      end
    endcase
  end
endmodule