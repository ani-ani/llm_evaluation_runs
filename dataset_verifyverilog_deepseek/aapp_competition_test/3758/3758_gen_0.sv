module packman_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] game_field,
  output reg [5:0] min_time,
  output reg done
);

  // Position arrays and counts
  reg [3:0] pac_pos[0:15];
  reg [3:0] ast_pos[0:15];
  reg [4:0] pac_count;
  reg [4:0] ast_count;
  
  // Binary search variables
  reg [5:0] l;
  reg [5:0] r;
  reg [5:0] m;
  reg [2:0] counter;
  
  always_comb begin : parse_positions
    if (start) begin
      automatic int pac_idx = 0;
      automatic int ast_idx = 0;
      
      pac_count = 0;
      ast_count = 0;
      for (int i = 0; i < 16; i = i + 1) begin
        case (game_field[2*i +: 2])
          2'b01: begin // Asterisk
            ast_pos[ast_idx] = i;
            ast_idx = ast_idx + 1;
          end
          2'b10: begin // Packman
            pac_pos[pac_idx] = i;
            pac_idx = pac_idx + 1;
          end
        endcase
      end
      pac_count = pac_idx;
      ast_count = ast_idx;
    end
  end
  
  // Compute Manhattan distance between two cells on 4x4 grid
  function automatic [3:0] compute_distance(input [3:0] posA, input [3:0] posB);
    reg [1:0] xA, yA, xB, yB;
    begin
      xA = posA[3:2];
      yA = posA[1:0];
      xB = posB[3:2];
      yB = posB[1:0];
      compute_distance = (xA > xB ? xA - xB : xB - xA) + 
                         (yA > yB ? yA - yB : yB - yA);
    end
  endfunction
  
  function automatic is_feasible(input [5:0] time_limit);
    reg [3:0] min_dist;
    reg feasible;
    reg [3:0] dist;
    begin
      if (ast_count == 0) begin // No asterisks
        is_feasible = 1;
      end else if (pac_count == 0) begin // No Packmen
        is_feasible = 0;
      end else begin
        feasible = 1;
        for (int i = 0; i < ast_count; i = i + 1) begin
          min_dist = 6'hFF; // Initialize to max
          for (int j = 0; j < pac_count; j = j + 1) begin
            dist = compute_distance(ast_pos[i], pac_pos[j]);
            if (dist < min_dist) min_dist = dist;
          end
          if (min_dist > time_limit) feasible = 0;
        end
        is_feasible = feasible;
      end
    end
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin : main_logic
    if (!rst_n) begin
      min_time <= 0;
      done <= 0;
      counter <= 0;
      l <= 0;
      r <= 32;
    end else begin
      done <= 0;
      
      if (start) begin
        case (counter)
          0: begin // Initial step
            l <= 0;
            r <= 32;
            counter <= counter + 1;
          end
          1, 2, 3, 4, 5: begin // Binary search steps
            m <= (l + r) >> 1;
            if (is_feasible((l + r) >> 1)) begin
              r <= (l + r) >> 1;
            end else begin
              l <= (l + r) >> 1;
            end
            counter <= counter + 1;
          end
          6: begin // Finalize
            min_time <= r;
            done <= 1;
            counter <= 0;
          end
        endcase
      end else begin
        counter <= 0;
        done <= 0;
      end
    end
  end
endmodule