module room_equivalence_detector (
  input clk,
  input rst_n,
  input start,
  input [2:0] room_count,
  input [7:0][2:0] rooms [0:3],
  output reg [2:0] set_count,
  output reg [7:0][2:0] equivalent_sets,
  output reg done
);

  // Pipelinestage registers
  reg [2:0] stage1_room_count;
  reg [7:0][2:0] stage1_rooms [0:3];
  reg [14:0] signatures [0:7];
  reg [2:0] grp_id [0:7];
  reg [4:0] cycle;
  reg processing;

  // Combinational logic helpers
  function automatic [3:0] calc_degree(input [2:0] room_idx);
    calc_degree = 0;
    for (int d = 0; d < 4; d++) begin
      if (stage1_rooms[d][room_idx][2] && (stage1_rooms[d][room_idx][2:0] < stage1_room_count)) begin
        calc_degree++;
      end
    end
  endfunction

  function automatic [3:0] calc_neighbor_degree(input [2:0] room_idx);
    calc_neighbor_degree = 0;
    for (int d = 0; d < 4; d++) begin
      if (stage1_rooms[d][room_idx][2] && (stage1_rooms[d][room_idx][2:0] < stage1_room_count)) begin
        calc_neighbor_degree++;
      end
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      processing <= 0;
      equivalent_sets <= '0;
      set_count <= 0;
      cycle <= 0;
    end else begin
      if (processing) begin
        cycle <= cycle + 1;

        // Stage 2: Compute signatures (cycles 1-8)
        if (cycle >= 1 && cycle <= 8) begin
          if (cycle[2:0] < stage1_room_count) begin
            automatic logic [2:0] r_idx = cycle[2:0];
            automatic logic [3:0] deg = calc_degree(r_idx);
            automatic logic [2:0] n_deg [0:3];

            for (int d = 0; d < 4; d++) begin
              automatic logic [2:0] exit_val = stage1_rooms[d][r_idx];
              if (exit_val[2] && (exit_val[2:0] < stage1_room_count)) begin
                n_deg[d] = calc_neighbor_degree(exit_val[2:0]);
              end else begin
                n_deg[d] = 0;
              end
            end
            signatures[r_idx] = {deg[2:0], n_deg[3], n_deg[2], n_deg[1], n_deg[0]};
          end else begin
            signatures[cycle[2:0]] = '0;
          end
        end

        // Stage 3: Compare signatures (cycles 9-16)
        if (cycle >= 9 && cycle <= 16) begin
          automatic logic [2:0] r_idx = cycle[2:0] - 3'd9; // Adjust to 0-7
          if (r_idx < stage1_room_count) begin
            automatic logic [2:0] match_id = r_idx;
            for (int i=0; i < r_idx; i++) begin
              if ((signatures[i] == signatures[r_idx]) && (i < match_id)) match_id = grp_id[i];
            end
            grp_id[r_idx] = match_id;
          end else begin
            grp_id[r_idx] = r_idx;
          end
        end

        // Finalize (cycle 17)
        if (cycle == 17) begin
          automatic logic [7:0] used_grps;
          automatic logic [2:0] sets_found = 0;
          automatic logic [7:0][2:0] temp_sets;
          automatic int idx = 0;

          used_grps = '0;
          equivalent_sets <= '0;
          // Find non-singleton groups
          for (int g=0; g<stage1_room_count; g++) begin
            automatic int cnt = 0;
            for (int r=0; r<stage1_room_count; r++) begin
              if (grp_id[r] == g) cnt++;
            end
            if (cnt >= 2 && !(used_grps[g])) begin
              used_grps[g] = 1;
              temp_sets[sets_found*3 +: 3] = g;
              for (int r=0; r<stage1_room_count && idx<8; r++) begin
                if (grp_id[r] == g) begin
                  equivalent_sets[idx] = r;
                  idx++;
                end
              end
              sets_found++;
            end
          end
          set_count <= sets_found;
          done <= 1;
          processing <= 0;
        end
      end else if (start) begin
        stage1_room_count <= room_count;
        stage1_rooms <= rooms;
        cycle <= 0;
        processing <= 1;
        done <= 0;
        set_count <= 0;
        equivalent_sets <= '0;
      end
    end
  end

endmodule