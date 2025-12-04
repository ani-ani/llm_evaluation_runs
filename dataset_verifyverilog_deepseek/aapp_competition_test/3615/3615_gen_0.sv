module max_connected_towers (
  input clk,
  input rst_n,
  input start,
  input [15:0] tower_x[0:7],
  input [15:0] tower_y[0:7],
  input [3:0] num_towers,
  output reg [3:0] max_count,
  output reg done
);
  
  // States
  enum reg [2:0] {
    IDLE,
    COMPARE,
    COMPONENTS,
    CANDIDATE_INIT,
    CHECK_CANDIDATE,
    UPDATE_MAX,
    FINISH
  } state, next_state;
  
  // Internal storage
  reg [15:0] cand_x, cand_y;
  reg [7:0] connections [0:7]; // Connection matrix
  reg [2:0] parent [0:7];      // Union-Find parent
  reg [3:0] comp_size [0:7];   // Component sizes
  reg [3:0] current_max;
  reg [2:0] i, j, k, cand_idx, iter_count;
  reg [7:0] valid_mask;
  reg [31:0] dx_sq, dy_sq, dist_sq;
  
  // Latency counter
  reg [4:0] cycle_count;
  
  // Threshold: 4.0 in Q10.6 fixed-point (2^12 * 4.0)
  localparam [31:0] THRESHOLD = 32'h4000;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_count <= 4'b0;
      cycle_count <= 5'b0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) cycle_count <= 5'b1;
          else cycle_count <= 5'b0;
        end
        
        COMPARE: begin
          cycle_count <= cycle_count + 1;
        end
        
        COMPONENTS: begin
          cycle_count <= cycle_count + 1;
        end
        
        CANDIDATE_INIT: begin
          cycle_count <= cycle_count + 1;
          cand_idx <= 0;
          current_max <= 4'b0;
        end
        
        CHECK_CANDIDATE: begin
          cycle_count <= cycle_count + 1;
          if (k == num_towers - 1) next_state <= UPDATE_MAX;
        end
        
        UPDATE_MAX: begin
          cycle_count <= cycle_count + 1;
          cand_idx <= cand_idx + 1;
        end
        
        FINISH: begin
          done <= 1'b1;
          max_count <= current_max > 0 ? current_max + 1 : 1;
          cycle_count <= 5'b0;
        end
      endcase
    end
  end
  
  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = COMPARE;
      
      COMPARE: if (cycle_count == 6) next_state = COMPONENTS;
      
      COMPONENTS: if (cycle_count == 6 + num_towers) next_state = CANDIDATE_INIT;
      
      CANDIDATE_INIT: next_state = CHECK_CANDIDATE;
      
      CHECK_CANDIDATE: 
        if (k == num_towers - 1) next_state = UPDATE_MAX;
      
      UPDATE_MAX: 
        if (cand_idx == num_towers) next_state = FINISH;
        else next_state = CANDIDATE_INIT;
      
      FINISH: next_state = IDLE;
    endcase
  end
  
  // Connection matrix generation
  always_ff @(posedge clk) begin
    if (state == COMPARE) begin
      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (i < num_towers && j < num_towers && i != j) begin
            dx_sq = (tower_x[i] - tower_x[j]) ** 2;
            dy_sq = (tower_y[i] - tower_y[j]) ** 2;
            dist_sq = dx_sq + dy_sq;
            connections[i][j] <= (dist_sq <= THRESHOLD);
          end else begin
            connections[i][j] <= 1'b0;
          end
        end
      end
    end
  end
  
  // Union-Find algorithm processing
  always_ff @(posedge clk) begin
    if (state == COMPONENTS) begin
      // Initialize parent and size arrays
      for (i = 0; i < 8; i = i + 1) begin
        parent[i] <= i < num_towers ? i[2:0] : 3'b0;
        comp_size[i] <= (i < num_towers) ? 4'b1 : 4'b0;
      end
      
      // Union connected nodes
      for (k = 0; k < 8; k = k + 1) begin
        for (i = 0; i < 8; i = i + 1) begin
          if (i < num_towers) begin
            for (j = 0; j < 8; j = j + 1) begin
              if (connections[i][j] && j < num_towers && parent[i] != parent[j]) begin
                // Path compression
                if (parent[j] == j) parent[j] <= parent[i];
                else parent[i] <= parent[j];
                // Size update
                comp_size[parent[j]] <= comp_size[parent[j]] + comp_size[parent[i]];
                comp_size[parent[i]] <= 4'b0;
              end
            end
          end
        end
      end
    end
  end
  
  // Candidate evaluation logic
  always_ff @(posedge clk) begin
    reg [3:0] merged_size;
    if (state == CANDIDATE_INIT) begin
      cand_x <= tower_x[cand_idx];
      cand_y <= tower_y[cand_idx];
      k <= 0;
      merged_size <= 0;
    end else if (state == CHECK_CANDIDATE) begin
      if (k < num_towers) begin
        dx_sq = (cand_x - tower_x[k]) ** 2;
        dy_sq = (cand_y - tower_y[k]) ** 2;
        dist_sq = dx_sq + dy_sq;
        
        if (dist_sq <= THRESHOLD) begin
          if (merged_size == 0) 
            merged_size <= comp_size[parent[k]];
          else if (parent[k] != parent[j]) // Compare with previous component
            merged_size <= merged_size + comp_size[parent[k]];
        end
        k <= k + 1;
      end
    end else if (state == UPDATE_MAX) begin
      if (merged_size > current_max) current_max <= merged_size;
    end
  end
  
endmodule