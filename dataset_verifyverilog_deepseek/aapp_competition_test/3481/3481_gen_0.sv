module maximum_gig_earnings(
  input clk,
  input rst_n,
  input start,
  input [7:0] road_a,
  input [7:0] road_b,
  input [63:0] road_t,
  input [7:0] gig_v,
  input [63:0] gig_s,
  input [63:0] gig_e,
  input [63:0] gig_m,
  output reg [15:0] max_earnings,
  output reg done
);

  // Permutation definitions (24 valid orders)
  localparam [7:0] PERMUTATIONS [24] = '{
    8'b00011011, 8'b00011110, 8'b00100111, 8'b00101101,
    8'b00101110, 8'b00110011, 8'b00110110, 8'b00111001,
    8'b00111010, 8'b01001011, 8'b01001101, 8'b01001110,
    8'b01010011, 8'b01010110, 8'b01011001, 8'b01011010,
    8'b01100011, 8'b01100101, 8'b01100110, 8'b01101001,
    8'b01101010, 8'b01110001, 8'b01110010, 8'b01110100
  };

  reg [15:0] dist [0:3][0:3];    // Distance matrix
  reg [1:0] gig_v_reg [0:3];     // Gig venue registers
  reg [15:0] gig_s_reg [0:3];    // Gig start time registers
  reg [15:0] gig_e_reg [0:3];    // Gig end time registers
  reg [15:0] gig_m_reg [0:3];    // Gig earnings registers
  reg [4:0] cycle_cnt;
  reg [15:0] candidate_max;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      max_earnings <= 16'b0;
      cycle_cnt <= 5'd0;
      candidate_max <= 16'b0;
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          dist[i][j] <= 16'hFFFF;
        end
      end
    end
    else begin
      if (cycle_cnt == 0) begin
        done <= 1'b0;
        max_earnings <= 16'b0;
        candidate_max <= 16'b0;
        
        if (start) begin
          // Capture inputs
          for (int i=0; i<4; i++) begin
            gig_v_reg[i] <= gig_v[i*2 +: 2];
            gig_s_reg[i] <= gig_s[i*16 +: 16];
            gig_e_reg[i] <= gig_e[i*16 +: 16];
            gig_m_reg[i] <= gig_m[i*16 +: 16];
          end
          
          // Reset distance matrix
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              dist[i][j] <= 16'hFFFF;
            end
          end
          cycle_cnt <= cycle_cnt + 1;
        end
      end
      else if (cycle_cnt < 22) begin
        if (cycle_cnt == 1) begin  // Road loading
          for (int i=0; i<4; i++) begin
            automatic int a = road_a[i*2 +: 2];
            automatic int b = road_b[i*2 +: 2];
            automatic int rt = road_t[i*16 +: 16];
            dist[a][b] <= (rt < dist[a][b]) ? rt : dist[a][b];
            dist[b][a] <= dist[a][b];
          end
          cycle_cnt <= cycle_cnt + 1;
        end
        else if (cycle_cnt >=2 && cycle_cnt <=5) begin  // Floyd-Warshall stages
          automatic int k = cycle_cnt - 2;
          for (int i=0; i<4; i++) begin
            for (int j=0; j<4; j++) begin
              automatic int sum = dist[i][k] + dist[k][j];
              if (sum < dist[i][j]) dist[i][j] <= sum;
              else dist[i][j] <= dist[i][j];
            end
          end
          cycle_cnt <= cycle_cnt + 1;
        end
        else if (cycle_cnt >=6 && cycle_cnt <=11) begin  // Permutation batches (6 batches)
          automatic int batch = cycle_cnt - 6;
          for (int p=0; p<4; p++) begin  // 4 parallel evaluations
            automatic int perm_idx = batch*4 + p;
            automatic int [7:0] perm = PERMUTATIONS[perm_idx];
            automatic int [1:0] order [4] = '{perm[7:6], perm[5:4], perm[3:2], perm[1:0]};
            automatic logic valid = 1;
            automatic int [15:0] earnings = 0;
            automatic int last_idx = -1;
            automatic int last_venue = 4'h0;
            automatic int last_end = 0;
                          for (int g=0; g<4; g++) begin
              automatic int idx = order[g];
              if (gig_v_reg[idx] != 0) begin
                if (last_idx == -1) begin
                  earnings = gig_m_reg[idx];
                  last_end = gig_e_reg[idx];
                  last_venue = gig_v_reg[idx];
                  last_idx = idx;
                end
                else begin
                  automatic int travel = dist[last_venue][gig_v_reg[idx]];
                  if ((last_end + travel) > gig_s_reg[idx]) valid = 0;
                  earnings = earnings + gig_m_reg[idx];
                  last_end = gig_e_reg[idx];
                  last_venue = gig_v_reg[idx];
                end
              end
            }
                        if (valid && (earnings > candidate_max)) candidate_max <= earnings;
          }
          cycle_cnt <= cycle_cnt + 1;
          if (cycle_cnt == 11) max_earnings <= candidate_max;
        end
        else cycle_cnt <= cycle_cnt + 1;
      end
      else begin // cycle_cnt == 22
        done <= 1'b1;
        cycle_cnt <= 0;
      end
    end
  end
endmodule