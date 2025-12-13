module minimum_climbing_energy(
  input clk,
  input rst_n,
  input start,
  input [3:0] R,
  input [3:0] C,
  input  signed [4:0] grid [0:15][0:15],
  input [15:0] E_mask,
  input [15:0] S_mask,
  output reg [7:0] min_energy,
  output reg done
);

  // Internal registers
  reg [7:0] energy [0:15];
  reg [7:0] next_energy [0:15];

  reg [5:0] iter_cnt;
  reg [5:0] iter_limit;
  reg running;

  // index helpers
  integer i;
  reg [3:0] r_lim, c_lim;

  // start pulse detect
  reg start_d;
  wire start_pulse = start & ~start_d;

  // Clamp R,C to max 4 and min 2
  always @(*) begin
    r_lim = (R < 2) ? 2 : ((R > 4) ? 4 : R);
    c_lim = (C < 2) ? 2 : ((C > 4) ? 4 : C);
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d   <= 1'b0;
      running   <= 1'b0;
      iter_cnt  <= 6'd0;
      iter_limit<= 6'd0;
      done      <= 1'b0;
      min_energy<= 8'd0;
      for (i = 0; i < 16; i = i + 1) begin
        energy[i] <= 8'hFF;
      end
    end else begin
      start_d <= start;
      done    <= 1'b0;

      if (start_pulse) begin
        // Initialize energies
        for (i = 0; i < 16; i = i + 1) begin
          if (S_mask[i])
            energy[i] <= 8'd0;
          else
            energy[i] <= 8'hFF;
        end
        // Precompute iteration limit = 8 * R * C (using clamped r_lim,c_lim)
        iter_limit <= (r_lim * c_lim) << 3;
        iter_cnt   <= 6'd0;
        running    <= 1'b1;
      end else if (running) begin
        // Perform one relaxation step (combinationally into next_energy)
        // Then update energy[] from next_energy
        for (i = 0; i < 16; i = i + 1) begin
          energy[i] <= next_energy[i];
        end

        if (iter_cnt == iter_limit - 1) begin
          running <= 1'b0;
          done    <= 1'b1;
        end
        iter_cnt <= iter_cnt + 1'b1;
      end else begin
        // Hold outputs when not running
        done <= 1'b0;
      end

      // When done is asserted in this cycle, compute min_energy for next cycle
      if (running && (iter_cnt == iter_limit - 1)) begin
        // Compute maximum energy over end positions
        reg [7:0] max_e;
        integer j;
        max_e = 8'd0;
        for (j = 0; j < 16; j = j + 1) begin
          if (E_mask[j]) begin
            if (energy[j] != 8'hFF && energy[j] > max_e)
              max_e = energy[j];
          end
        end
        min_energy <= max_e;
      end
    end
  end

  // Combinational relaxation for all cells in parallel
  integer idx;
  integer row, col;
  reg [7:0] cur_e;
  reg signed [4:0] cost;
  reg [7:0] cand_e, best_e;
  reg [7:0] nb_e;
  reg signed [8:0] sum;

  always @(*) begin
    // Default: hold current energy
    for (idx = 0; idx < 16; idx = idx + 1) begin
      next_energy[idx] = energy[idx];
    end

    if (running) begin
      for (idx = 0; idx < 16; idx = idx + 1) begin
        row = idx / c_lim;
        col = idx % c_lim;

        if (row < r_lim && col < c_lim) begin
          // current energy
          cur_e = energy[idx];

          // skip unreachable cells
          best_e = cur_e;

          // Check neighbors (4-directional), relax using neighbor -> this cell

          // Up neighbor (row-1, col)
          if (row > 0) begin
            nb_e = energy[(row-1)*c_lim + col];
            cost = grid[row][col];
            if (nb_e != 8'hFF) begin
              sum = $signed({1'b0, nb_e}) + cost;
              if (sum < 0)
                cand_e = 8'd0;
              else if (sum > 9'd255)
                cand_e = 8'hFF;
              else
                cand_e = sum[7:0];
              if (cand_e < best_e)
                best_e = cand_e;
            end
          end

          // Down neighbor (row+1, col)
          if (row + 1 < r_lim) begin
            nb_e = energy[(row+1)*c_lim + col];
            cost = grid[row][col];
            if (nb_e != 8'hFF) begin
              sum = $signed({1'b0, nb_e}) + cost;
              if (sum < 0)
                cand_e = 8'd0;
              else if (sum > 9'd255)
                cand_e = 8'hFF;
              else
                cand_e = sum[7:0];
              if (cand_e < best_e)
                best_e = cand_e;
            end
          end

          // Left neighbor (row, col-1)
          if (col > 0) begin
            nb_e = energy[row*c_lim + (col-1)];
            cost = grid[row][col];
            if (nb_e != 8'hFF) begin
              sum = $signed({1'b0, nb_e}) + cost;
              if (sum < 0)
                cand_e = 8'd0;
              else if (sum > 9'd255)
                cand_e = 8'hFF;
              else
                cand_e = sum[7:0];
              if (cand_e < best_e)
                best_e = cand_e;
            end
          end

          // Right neighbor (row, col+1)
          if (col + 1 < c_lim) begin
            nb_e = energy[row*c_lim + (col+1)];
            cost = grid[row][col];
            if (nb_e != 8'hFF) begin
              sum = $signed({1'b0, nb_e}) + cost;
              if (sum < 0)
                cand_e = 8'd0;
              else if (sum > 9'd255)
                cand_e = 8'hFF;
              else
                cand_e = sum[7:0];
              if (cand_e < best_e)
                best_e = cand_e;
            end
          end

          next_energy[idx] = best_e;
        end else begin
          // Outside active grid: keep as is (255 by init)
          next_energy[idx] = energy[idx];
        end
      end
    end
  end

endmodule