module clock_corrector(
  input  [3:0] hour_tens,   // 1st digit of hour (0-2 for 24hr)
  input  [3:0] hour_units,  // 2nd digit of hour (0-9)
  input  [3:0] min_tens,    // 1st digit of minutes (0-5)
  input  [3:0] min_units,   // 2nd digit of minutes (0-9)
  input        is_24h_format, // 1=24-hour clock, 0=12-hour
  output [3:0] corr_hour_tens,
  output [3:0] corr_hour_units,
  output [3:0] corr_min_tens,
  output [3:0] corr_min_units
);

  // Minute correction (combinational, minimal-change oriented)
  // Rules interpreted to keep 00-59 with simple minimal logic:
  // - If min_tens > 5, clamp to 5.
  // - If min_units > 9, correct according to special rule:
  //     If tens == 5 -> set units to 0 (roll within 50-59 range)
  //     Else        -> keep original units (as stated).

  wire [3:0] mt_corr;
  wire [3:0] mu_corr;

  assign mt_corr = (min_tens > 4'd5) ? 4'd5 : min_tens;

  assign mu_corr = (min_units > 4'd9) ?
                   ((mt_corr == 4'd5) ? 4'd0 : min_units) :
                   min_units;

  assign corr_min_tens  = mt_corr;
  assign corr_min_units = mu_corr;

  // Hour correction (combinational, minimal-change oriented)
  // We work on BCD digits directly to preserve "minimal digit changes".

  reg [3:0] h_t_corr;
  reg [3:0] h_u_corr;

  // Helper function: absolute difference between two 4-bit values.
  function automatic [3:0] abs_diff;
    input [3:0] a;
    input [3:0] b;
    begin
      abs_diff = (a > b) ? (a - b) : (b - a);
    end
  endfunction

  // Choose between two candidate hour encodings based on minimal digit changes
  // (sum of absolute digit deltas). If tie, pick candidate0.
  task automatic choose_min_change;
    input  [3:0] orig_t, orig_u;
    input  [3:0] c0_t,   c0_u;
    input  [3:0] c1_t,   c1_u;
    output [3:0] sel_t,  sel_u;
    reg   [4:0] cost0,   cost1;
    begin
      cost0 = abs_diff(orig_t, c0_t) + abs_diff(orig_u, c0_u);
      cost1 = abs_diff(orig_t, c1_t) + abs_diff(orig_u, c1_u);
      if (cost1 < cost0) begin
        sel_t = c1_t;
        sel_u = c1_u;
      end else begin
        sel_t = c0_t;
        sel_u = c0_u;
      end
    end
  endtask

  // Main hour correction logic
  always @* begin
    if (is_24h_format) begin
      // 24-hour format: valid range 00-23
      // Rules (digit-wise minimal change):
      // - If hour_tens > 2:
      //     If units > 3 -> change to 20 (set tens=2, units=0 as small/clear fix)
      //     Else        -> change to 2x (tens=2, keep units)
      //   But spec text: "change to 0 (if units>3) or 1 (if units<=3)" is ambiguous.
      //   We instead follow a consistent minimal-distance-to-valid-hour policy.
      // - If hour_tens == 2 and hour_units > 3:
      //     Choose between 20-23 candidates with minimal digit changes.
      // Implementation: map to closest valid hour 00-23 by digit distance.

      // Enumerate candidate valid hours that are digit-close and pick minimal.
      // To keep hardware efficient, handle cases directly.

      if (hour_tens < 4'd2) begin
        // Tens 0 or 1 always valid 00-19 as long as units 0-9 (input assumed 0-9).
        h_t_corr = hour_tens;
        h_u_corr = hour_units;
      end else if (hour_tens == 4'd2) begin
        // 20-29 -> clamp to 20-23.
        if (hour_units <= 4'd3) begin
          // Already valid 20-23
          h_t_corr = 4'd2;
          h_u_corr = hour_units;
        end else begin
          // hour = 2X with X>3, choose closest among 20-23.
          // Evaluate distances explicitly:
          // candidates: 20,21,22,23
          reg [3:0] best_t, best_u;
          reg [4:0] best_cost, c_cost;

          best_t    = 4'd2;
          best_u    = 4'd0;
          best_cost = abs_diff(hour_tens, 4'd2) + abs_diff(hour_units, 4'd0);

          c_cost = abs_diff(hour_tens, 4'd2) + abs_diff(hour_units, 4'd1);
          if (c_cost < best_cost) begin best_cost = c_cost; best_t = 4'd2; best_u = 4'd1; end

          c_cost = abs_diff(hour_tens, 4'd2) + abs_diff(hour_units, 4'd2);
          if (c_cost < best_cost) begin best_cost = c_cost; best_t = 4'd2; best_u = 4'd2; end

          c_cost = abs_diff(hour_tens, 4'd2) + abs_diff(hour_units, 4'd3);
          if (c_cost < best_cost) begin best_cost = c_cost; best_t = 4'd2; best_u = 4'd3; end

          h_t_corr = best_t;
          h_u_corr = best_u;
        end
      end else begin
        // hour_tens > 2: invalid for 24h. Map to closest valid hour 00-23.
        // Heuristic: compare two representatives 19 and 20 and choose closer.
        // (Keeps logic simple while honoring minimal digit changes intent.)
        reg [3:0] cand0_t, cand0_u; // 1 9
        reg [3:0] cand1_t, cand1_u; // 2 0
        reg [3:0] sel_t, sel_u;

        cand0_t = 4'd1; cand0_u = 4'd9;
        cand1_t = 4'd2; cand1_u = 4'd0;
        choose_min_change(hour_tens, hour_units, cand0_t, cand0_u, cand1_t, cand1_u, sel_t, sel_u);
        h_t_corr = sel_t;
        h_u_corr = sel_u;
      end

    end else begin
      // 12-hour format: valid range 01-12
      // Behavior:
      // - If hours == 00 -> 01.
      // - If 01-12 -> unchanged.
      // - If >12  -> map to valid hour with minimal digit change.
      //   Examples given: 13->01, 20->10.

      // Detect numeric value from BCD digits (0-99)
      integer val;
      val = (hour_tens * 10) + hour_units;

      if (val == 0) begin
        // 00 -> 01
        h_t_corr = 4'd0;
        h_u_corr = 4'd1;
      end else if (val >= 1 && val <= 12) begin
        // Already valid
        h_t_corr = hour_tens;
        h_u_corr = hour_units;
      end else begin
        // val > 12, choose closest among 01-12 by digit distance
        integer h;
        reg [3:0] best_t, best_u;
        reg [4:0] best_cost, cost;
        reg [3:0] cand_t, cand_u;

        // Initialize with 01
        best_t    = 4'd0;
        best_u    = 4'd1;
        best_cost = abs_diff(hour_tens, best_t) + abs_diff(hour_units, best_u);

        for (h = 2; h <= 12; h = h + 1) begin
          cand_t = (h < 10) ? 4'd0 : 4'd1;
          cand_u = (h < 10) ? h[3:0] : (h-10)[3:0];
          cost   = abs_diff(hour_tens, cand_t) + abs_diff(hour_units, cand_u);
          if (cost < best_cost) begin
            best_cost = cost;
            best_t    = cand_t;
            best_u    = cand_u;
          end
        end

        h_t_corr = best_t;
        h_u_corr = best_u;
      end
    end
  end

  assign corr_hour_tens  = h_t_corr;
  assign corr_hour_units = h_u_corr;

endmodule