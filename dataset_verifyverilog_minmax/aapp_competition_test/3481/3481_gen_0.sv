module maximum_gig_earnings(
  input clk,               // system clock
  input rst_n,              // active-low reset
  input start,              // start computation
  input [7:0] road_a,       // 4 road sources (2-bits each: [7:6]=road3)
  input [7:0] road_b,       // 4 road destinations
  input [63:0] road_t,      // 4 road times (16-bits each: [63:48]=road3)
  input [7:0] gig_v,        // 4 gig venues (2-bits each: [7:6]=gig3)
  input [63:0] gig_s,       // 4 gig start times (16-bits each)
  input [63:0] gig_e,       // 4 gig end times
  input [63:0] gig_m,       // 4 gig earnings
  output reg [15:0] max_earnings,  // maximum cryptocents
  output reg done           // high when computation completes
);

  // Distance matrix for Floyd-Warshall
  reg [15:0] dist[0:3][0:3];
  
  // Cycle counter
  reg [5:0] cycle_counter;
  
  // ROM for 24 permutations of gigs [0,1,2,3]
  reg [7:0] perm_mem [0:23];
  
  integer i, j, k, l, idx;
  
  // Generate permutation ROM
  initial begin
    idx = 0;
    for (i = 0; i < 4; i++) begin
      for (j = 0; j < 4; j++) begin
        if (j == i) continue;
        for (k = 0; k < 4; k++) begin
          if (k == i || k == j) continue;
          for (l = 0; l < 4; l++) begin
            if (l == i || l == j || l == k) continue;
            perm_mem[idx] = {i[1:0], j[1:0], k[1:0], l[1:0]};
            idx = idx + 1;
          end
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_counter <= 0;
      max_earnings <= 0;
      done <= 0;
    end else if (start) begin
      cycle_counter <= 1;
    end else if (cycle_counter > 0) begin
      if (cycle_counter < 22) begin
        cycle_counter <= cycle_counter + 1;
      end
    end
  end

  always @(posedge clk) begin
    if (start) begin
      if (cycle_counter == 1) begin
        // Initialize distance matrix to max value (65535)
        for (i = 0; i < 4; i++) begin
          for (j = 0; j < 4; j++) begin
            dist[i][j] <= 16'hFFFF;
          end
        end
      end
      else if (cycle_counter >= 2 && cycle_counter <= 5) begin
        // Load roads: set distance[A][B] and [B][A] = min(current_value, road_T)
        int road_idx = cycle_counter - 2; // 0,1,2,3
        bit [1:0] a = road_a[2*road_idx+1 : 2*road_idx];
        bit [1:0] b = road_b[2*road_idx+1 : 2*road_idx];
        bit [15:0] t = road_t[16*road_idx+15 : 16*road_idx];
        
        if (dist[a][b] > t) dist[a][b] <= t;
        if (dist[b][a] > t) dist[b][a] <= t;
      end
      else if (cycle_counter >= 6 && cycle_counter <= 9) begin
        // Floyd-Warshall stages (k=0,1,2,3)
        int k = cycle_counter - 6; // 0,1,2,3
        for (int i = 0; i < 4; i++) begin
          for (int j = 0; j < 4; j++) begin
            if (dist[i][j] > dist[i][k] + dist[k][j]) begin
              dist[i][j] <= dist[i][k] + dist[k][j];
            end
          end
        end
      end
      else if (cycle_counter >= 10 && cycle_counter <= 15) begin
        // Permutation evaluation: 4 permutations per cycle for 6 cycles
        int batch = cycle_counter - 10; // 0 to 5
        int base = batch * 4;
        
        // Extract 4 permutations from ROM
        reg [7:0] perm0 = perm_mem[base];
        reg [7:0] perm1 = perm_mem[base+1];
        reg [7:0] perm2 = perm_mem[base+2];
        reg [7:0] perm3 = perm_mem[base+3];
        
        // Evaluate all 4 permutations in parallel
        bit [1:0] gig_idx [0:3][0:3];
        
        // Permutation 0
        gig_idx[0][0] = perm0[7:6];
        gig_idx[0][1] = perm0[5:4];
        gig_idx[0][2] = perm0[3:2];
        gig_idx[0][3] = perm0[1:0];
        
        // Permutation 1
        gig_idx[1][0] = perm1[7:6];
        gig_idx[1][1] = perm1[5:4];
        gig_idx[1][2] = perm1[3:2];
        gig_idx[1][3] = perm1[1:0];
        
        // Permutation 2
        gig_idx[2][0] = perm2[7:6];
        gig_idx[2][1] = perm2[5:4];
        gig_idx[2][2] = perm2[3:2];
        gig_idx[2][3] = perm2[1:0];
        
        // Permutation 3
        gig_idx[3][0] = perm3[7:6];
        gig_idx[3][1] = perm3[5:4];
        gig_idx[3][2] = perm3[3:2];
        gig_idx[3][3] = perm3[1:0];
        
        // Check feasibility and calculate earnings for each permutation
        reg [15:0] earnings [0:3];
        
        for (int p = 0; p < 4; p++) begin
          bit [1:0] v0, v1, v2, v3;
          bit [15:0] s0, s1, s2, s3;
          bit [15:0] e0, e1, e2, e3;
          bit [15:0] m0, m1, m2, m3;
          
          v0 = gig_v[gig_idx[p][0]*2+1 : gig_idx[p][0]*2];
          v1 = gig_v[gig_idx[p][1]*2+1 : gig_idx[p][1]*2];
          v2 = gig_v[gig_idx[p][2]*2+1 : gig_idx[p][2]*2];
          v3 = gig_v[gig_idx[p][3]*2+1 : gig_idx[p][3]*2];
          
          s0 = gig_s[gig_idx[p][0]*16+15 : gig_idx[p][0]*16];
          s1 = gig_s[gig_idx[p][1]*16+15 : gig_idx[p][1]*16];
          s2 = gig_s[gig_idx[p][2]*16+15 : gig_idx[p][2]*16];
          s3 = gig_s[gig_idx[p][3]*16+15 : gig_idx[p][3]*16];
          
          e0 = gig_e[gig_idx[p][0]*16+15 : gig_idx[p][0]*16];
          e1 = gig_e[gig_idx[p][1]*16+15 : gig_idx[p][1]*16];
          e2 = gig_e[gig_idx[p][2]*16+15 : gig_idx[p][2]*16];
          e3 = gig_e[gig_idx[p][3]*16+15 : gig_idx[p][3]*16];
          
          m0 = gig_m[gig_idx[p][0]*16+15 : gig_idx[p][0]*16];
          m1 = gig_m[gig_idx[p][1]*16+15 : gig_idx[p][1]*16];
          m2 = gig_m[gig_idx[p][2]*16+15 : gig_idx[p][2]*16];
          m3 = gig_m[gig_idx[p][3]*16+15 : gig_idx[p][3]*16];
          
          // Check time feasibility
          bit feasible;
          feasible = 1;
          
          if ((e0 + dist[v0][v1]) > s1) feasible = 0;
          if ((e1 + dist[v1][v2]) > s2) feasible = 0;
          if ((e2 + dist[v2][v3]) > s3) feasible = 0;
          
          if (feasible) begin
            earnings[p] <= m0 + m1 + m2 + m3;
          end else begin
            earnings[p] <= 0;
          end
        end
        
        // Update max_earnings with the best of the 4 permutations
        reg [15:0] best = max_earnings;
        for (int p = 0; p < 4; p++) begin
          if (earnings[p] > best) best = earnings[p];
        end
        max_earnings <= best;
      end
    end

    if (cycle_counter == 22) begin
      done <= 1;
    end
  end
endmodule