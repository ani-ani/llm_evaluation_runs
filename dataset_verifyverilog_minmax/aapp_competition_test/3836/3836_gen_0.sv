module debate_selector(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // pulse high to begin processing
  input [1:0] view_in, // political views (00, 01, 10, 11)
  input [12:0] influence_in, // 13-bit influence value (0-8191)
  input valid_in, // high when input data is valid
  output reg [12:0] max_influence, // maximum valid total influence
  output reg done // high when computation complete
);
  localparam MAX_ENTRIES = 8;
  localparam W = 13;
  localparam IDLE = 2'b00;
  localparam ACQ = 2'b01;
  localparam COMPUTE = 2'b10;
  localparam DONE = 2'b11;

  // Storage for up to 8 spectators
  reg [1:0] mem_view [0:MAX_ENTRIES-1];
  reg [W-1:0] mem_inf [0:MAX_ENTRIES-1];
  reg [3:0] n; // number of valid entries collected (0..8)

  // State
  reg [1:0] state;
  reg [3:0] i, j, k;
  reg [3:0] best_p, best_q, best_r;
  reg [W-1:0] best_sum;

  // Scratch arrays for compute
  reg [W-1:0] top11 [0:MAX_ENTRIES-1];
  reg [3:0] c11;
  reg [W-1:0] top10 [0:MAX_ENTRIES-1];
  reg [3:0] c10;
  reg [W-1:0] top01 [0:MAX_ENTRIES-1];
  reg [3:0] c01;
  reg [W-1:0] top00 [0:MAX_ENTRIES-1];
  reg [3:0] c00;
  reg [W-1:0] sum;
  reg [3:0] total;
  reg [3:0] alice_supp, bob_supp;
  reg [3:0] lim11, lim10, lim01, lim00, lim_extra;
  reg [12:0] tmp;

  function [3:0] min3;
    input [3:0] a, b, c;
    begin
      min3 = (a < b) ? ((a < c) ? a : c) : ((b < c) ? b : c);
    end
  endfunction

  // Insertion sort descending for a small fixed-size array (size <= 8)
  task insert_desc;
    input [12:0] val;
    inout [12:0] arr [0:MAX_ENTRIES-1];
    inout [3:0] cnt;
    reg [12:0] key;
    reg [3:0] ii, jj;
    begin
      if (cnt == 4'd0) begin
        arr[0] = val;
        cnt = 1;
      end else begin
        ii = 1;
        key = val;
        while ((ii < cnt) && (key <= arr[ii-1])) ii = ii + 1;
        // shift right (ii .. cnt-1)
        for (jj = cnt; jj > ii; jj = jj - 1) arr[jj-1] = arr[jj-2];
        if (cnt < MAX_ENTRIES) begin
          arr[ii-1] = key;
          cnt = cnt + 1;
        end else begin
          // buffer full and value is <= smallest -> do nothing
          if (key > arr[MAX_ENTRIES-1]) begin
            for (jj = cnt-1; jj > 0; jj = jj - 1) arr[jj] = arr[jj-1];
            arr[0] = key;
          end
        end
      end
    end
  endtask

  task bubble_sort_desc;
    inout [12:0] arr [0:MAX_ENTRIES-1];
    inout [3:0] cnt;
    reg [12:0] tmpv;
    reg [3:0] ii, jj;
    begin
      for (ii = 0; ii < cnt; ii = ii + 1) begin
        for (jj = 0; jj < cnt - 1 - ii; jj = jj + 1) begin
          if (arr[jj] < arr[jj+1]) begin
            tmpv = arr[jj];
            arr[jj] = arr[jj+1];
            arr[jj+1] = tmpv;
          end
        end
      end
    end
  endtask

  task compute_best;
    reg [3:0] a11, a10, a01, a00;
    reg [12:0] cur_sum;
    reg [3:0] cur_total;
    begin
      best_sum = 0;
      best_p = 0; best_q = 0; best_r = 0;

      // If no data, best is 0
      if (n == 0) begin
        best_sum = 0;
      end else begin
        // Enumerate feasible (p, q, r)
        // p: paired supporters count (each side)
        // q: extra from the minority side among 10/01
        // r: additional 00 or remaining from the majority side
        for (i = 0; i <= c11; i = i + 1) begin
          a11 = i;
          for (j = 0; j <= min3(c10, c01, (MAX_ENTRIES - a11)); j = j + 1) begin
            a10 = j; a01 = j;
            if (a11 + a10 + a01 > MAX_ENTRIES) continue;
            for (k = 0; k <= (MAX_ENTRIES - a11 - a10 - a01); k = k + 1) begin
              // Remaining capacity after base + extra minority side pick
              lim_extra = MAX_ENTRIES - a11 - a10 - a01 - k;
              if (lim_extra < 0) continue;

              // r picks from 00 first, then if capacity remains, from majority side leftovers
              a00 = (k <= c00) ? k : c00;
              cur_total = a11 + a10 + a01 + a00;
              if (cur_total > MAX_ENTRIES) continue;

              // Sum base 11 + paired 10/01
              cur_sum = 0;
              for (i = 0; i < a11; i = i + 1) cur_sum = cur_sum + top11[i];
              for (i = 0; i < a10; i = i + 1) cur_sum = cur_sum + top10[i];
              for (i = 0; i < a01; i = i + 1) cur_sum = cur_sum + top01[i];
              // Add chosen 00 (r)
              for (i = 0; i < a00; i = i + 1) cur_sum = cur_sum + top00[i];

              // If capacity remains, try to add from majority leftover to reach up to 8
              if (cur_total < MAX_ENTRIES) begin
                // Identify majority side
                // If c10 >= c01, 10 is majority; else 01 is majority
                if (c10 >= c01) begin
                  // leftovers from 10: top10[a10 .. min(c10-1, ...)]
                  lim10 = (c10 > a10) ? (c10 - a10) : 0;
                  // Add as many as we can up to capacity
                  for (i = 0; i < lim10 && (cur_total < MAX_ENTRIES); i = i + 1) begin
                    cur_sum = cur_sum + top10[a10 + i];
                    cur_total = cur_total + 1;
                  end
                end else begin
                  // leftovers from 01
                  lim01 = (c01 > a01) ? (c01 - a01) : 0;
                  for (i = 0; i < lim01 && (cur_total < MAX_ENTRIES); i = i + 1) begin
                    cur_sum = cur_sum + top01[a01 + i];
                    cur_total = cur_total + 1;
                  end
                end
              end

              // Update best (max sum, tie-break by larger total then smaller p then smaller q then smaller r)
              if (cur_sum > best_sum) begin
                best_sum = cur_sum;
                best_p = a10; // number of paired supporters per side
                best_q = k - a00; // extra from minority side
                best_r = a00; // number of 00 selected
              end else if (cur_sum == best_sum) begin
                // Tie-breaker: prefer larger total selected
                // compute totals for this candidate and current best
                // current best total: base + extra minority + 00 + any leftovers filled to cap
                // Recompute totals similarly to be consistent
                // This candidate's total is cur_total (already computed)
                // Best total recomputation:
                // base: best_p*2 + (c11 taken? we'll recompute:)
              end
            end
          end
        end
        // Proper tie-breaking inside the loop requires local totals.
        // Implement complete loop with tie-break.
        best_sum = 0; // reset to redo with tie-break handled
        for (i = 0; i <= c11; i = i + 1) begin
          a11 = i;
          for (j = 0; j <= min3(c10, c01, (MAX_ENTRIES - a11)); j = j + 1) begin
            a10 = j; a01 = j;
            if (a11 + a10 + a01 > MAX_ENTRIES) continue;
            for (k = 0; k <= (MAX_ENTRIES - a11 - a10 - a01); k = k + 1) begin
              a00 = (k <= c00) ? k : c00;
              cur_total = a11 + a10 + a01 + a00;
              if (cur_total > MAX_ENTRIES) continue;

              // sum base + 00
              cur_sum = 0;
              for (i = 0; i < a11; i = i + 1) cur_sum = cur_sum + top11[i];
              for (i = 0; i < a10; i = i + 1) cur_sum = cur_sum + top10[i];
              for (i = 0; i < a01; i = i + 1) cur_sum = cur_sum + top01[i];
              for (i = 0; i < a00; i = i + 1) cur_sum = cur_sum + top00[i];

              // fill to capacity from majority leftovers
              if (cur_total < MAX_ENTRIES) begin
                if (c10 >= c01) begin
                  lim10 = (c10 > a10) ? (c10 - a10) : 0;
                  for (i = 0; i < lim10 && (cur_total < MAX_ENTRIES); i = i + 1) begin
                    cur_sum = cur_sum + top10[a10 + i];
                    cur_total = cur_total + 1;
                  end
                end else begin
                  lim01 = (c01 > a01) ? (c01 - a01) : 0;
                  for (i = 0; i < lim01 && (cur_total < MAX_ENTRIES); i = i + 1) begin
                    cur_sum = cur_sum + top01[a01 + i];
                    cur_total = cur_total + 1;
                  end
                end
              end

              // Tie-break: prefer larger total, then smaller p, q, r
              if (best_sum === 0 && best_p === 0 && best_q === 0 && best_r === 0) begin
                // first valid
                best_sum = cur_sum;
                best_p = a10;
                best_q = k - a00;
                best_r = a00;
              end else begin
                // compute this total also (we have cur_total)
                // compute best total (recompute similar to how best was set):
                // base best total:
                // We'll recompute from best_* for consistency.
                // To keep it simple, compute a best_total the same way as cur_total for the stored best_*.
                // Recompute best_total using best_p, best_q, best_r.
                // We do not store best_11, best_10, best_01, best_00, so recompute from saved best_*.
                // For best_11 we can infer as a11 derived when best was set? Instead, we can store best_a11/a10/a01/a00 too.
                // For simplicity and guaranteed correctness, prefer strictly larger cur_sum; on equal sum, prefer larger total.
                // To decide, compute best_total and compare.
                // Reconstruct best selection from best_p, best_q, best_r and category counts using the same filling policy.
                // Determine best_a11: find a11 that matches best_sum? Not unique. We'll store best totals when updating.
              end
            end
          end
        end
        // The above incomplete tie-break logic is replaced by a simpler approach below.
      end
    end
  endtask

  // We'll implement the full search with explicit best_total tracking to simplify tie-breaking.
  task compute_best_full;
    reg [3:0] a11, a10, a01, a00;
    reg [12:0] cur_sum;
    reg [3:0] cur_total, best_total;
    reg [3:0] best_a11, best_a10, best_a01, best_a00;
    reg [3:0] min10_01;
    begin
      best_sum = 0;
      best_total = 0;
      best_a11 = 0; best_a10 = 0; best_a01 = 0; best_a00 = 0;

      if (n == 0) begin
        // nothing
      end else begin
        for (a11 = 0; a11 <= c11; a11 = a11 + 1) begin
          if (a11 > MAX_ENTRIES) continue;
          for (a10 = 0; a10 <= min3(c10, c01, (MAX_ENTRIES - a11)); a10 = a10 + 1) begin
            a01 = a10; // paired selection
            if (a11 + a10 + a01 > MAX_ENTRIES) continue;
            for (a00 = 0; a00 <= min3(c00, (MAX_ENTRIES - a11 - a10 - a01), 8); a00 = a00 + 1) begin
              // capacity after base + 00
              if (a11 + a10 + a01 + a00 > MAX_ENTRIES) continue;
              // sum base 11/10/01 and 00
              cur_sum = 0;
              for (i = 0; i < a11; i = i + 1) cur_sum = cur_sum + top11[i];
              for (i = 0; i < a10; i = i + 1) cur_sum = cur_sum + top10[i];
              for (i = 0; i < a01; i = i + 1) cur_sum = cur_sum + top01[i];
              for (i = 0; i < a00; i = i + 1) cur_sum = cur_sum + top00[i];

              cur_total = a11 + a10 + a01 + a00;
              // Fill remaining slots with best of majority leftovers
              if (cur_total < MAX_ENTRIES) begin
                if (c10 >= c01) begin
                  // 10 is majority or tied
                  min10_01 = c10 - a10; // remaining 10
                  if (min10_01 > 0) begin
                    for (i = 0; i < min10_01 && cur_total < MAX_ENTRIES; i = i + 1) begin
                      cur_sum = cur_sum + top10[a10 + i];
                      cur_total = cur_total + 1;
                    end
                  end
                end else begin
                  // 01 is majority
                  min10_01 = c01 - a01;
                  if (min10_01 > 0) begin
                    for (i = 0; i < min10_01 && cur_total < MAX_ENTRIES; i = i + 1) begin
                      cur_sum = cur_sum + top01[a01 + i];
                      cur_total = cur_total + 1;
                    end
                  end
                end
              end

              // Update best: prefer larger cur_sum; if equal, prefer larger total
              if (cur_sum > best_sum) begin
                best_sum = cur_sum;
                best_total = cur_total;
                best_a11 = a11; best_a10 = a10; best_a01 = a01; best_a00 = a00;
              end else if (cur_sum == best_sum) begin
                if (cur_total > best_total) begin
                  best_sum = cur_sum;
                  best_total = cur_total;
                  best_a11 = a11; best_a10 = a10; best_a01 = a01; best_a00 = a00;
                end
                // If still equal, do not change; any is fine
              end
            end
          end
        end
      end
    end
  endtask

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      n <= 0;
      max_influence <= 0;
      done <= 0;
      c11 <= 0; c10 <= 0; c01 <= 0; c00 <= 0;
      for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
        mem_view[i] <= 0;
        mem_inf[i] <= 0;
        top11[i] <= 0; top10[i] <= 0; top01[i] <= 0; top00[i] <= 0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            // Start acquisition fresh
            n <= 0;
            c11 <= 0; c10 <= 0; c01 <= 0; c00 <= 0;
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
              top11[i] <= 0; top10[i] <= 0; top01[i] <= 0; top00[i] <= 0;
            end
            state <= ACQ;
          end
        end

        ACQ: begin
          if (valid_in && (n < MAX_ENTRIES)) begin
            mem_view[n] <= view_in;
            mem_inf[n] <= influence_in;
            n <= n + 1;
            // Insert into category arrays (unsorted buffers, we will sort later)
            case (view_in)
              2'b11: insert_desc(influence_in, top11, c11);
              2'b10: insert_desc(influence_in, top10, c10);
              2'b01: insert_desc(influence_in, top01, c01);
              2'b00: insert_desc(influence_in, top00, c00);
              default: ;
            endcase
          end

          if (start) begin
            // If user re-starts during acquisition, re-init buffers
            n <= 0;
            c11 <= 0; c10 <= 0; c01 <= 0; c00 <= 0;
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
              top11[i] <= 0; top10[i] <= 0; top01[i] <= 0; top00[i] <= 0;
            end
          end

          if (n == MAX_ENTRIES) begin
            // Enough samples, go compute next cycle
            state <= COMPUTE;
          end
        end

        COMPUTE: begin
          // Sort category arrays descending (small N, bubble sort is fine)
          bubble_sort_desc(top11, c11);
          bubble_sort_desc(top10, c10);
          bubble_sort_desc(top01, c01);
          bubble_sort_desc(top00, c00);

          // Compute best selection
          compute_best_full;

          // If no feasible selection, best_sum may be 0 (also covers impossible case)
          max_influence <= best_sum;
          done <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b0;
          if (start) begin
            // Start a new run
            n <= 0;
            c11 <= 0; c10 <= 0; c01 <= 0; c00 <= 0;
            for (i = 0; i < MAX_ENTRIES; i = i + 1) begin
              top11[i] <= 0; top10[i] <= 0; top01[i] <= 0; top00[i] <= 0;
            end
            state <= ACQ;
          end else begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule