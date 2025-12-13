module sublist_checker(
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  main_list [7:0],
  input  logic [7:0]  sub_list  [3:0],
  output logic        found,
  output logic        done
);

  // Internal signals
  logic [7:0] main_reg [7:0];
  logic [7:0] sub_reg  [3:0];

  logic [2:0] cycle_cnt;         // counts 0..7
  logic       running;           // indicates active search window
  logic       start_d;           // registered start
  logic       start_pulse;       // single-cycle pulse

  logic       empty_sub;         // all sub_list entries are zero
  logic [7:0] nz_prefix_mask;    // main_list non-zero prefix mask
  logic [3:0] sub_nz_len;        // effective sub_list length (non-zero prefix length)
  logic [3:0] main_nz_len;       // effective main_list length (non-zero prefix length)

  // Parallel match indicators for all possible starting indices 0..4
  logic [4:0] match_vec;

  // Register inputs on start pulse for consistent comparison window
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      main_reg[0] <= 8'd0; main_reg[1] <= 8'd0; main_reg[2] <= 8'd0; main_reg[3] <= 8'd0;
      main_reg[4] <= 8'd0; main_reg[5] <= 8'd0; main_reg[6] <= 8'd0; main_reg[7] <= 8'd0;
      sub_reg[0]  <= 8'd0; sub_reg[1]  <= 8'd0; sub_reg[2]  <= 8'd0; sub_reg[3]  <= 8'd0;
    end else begin
      if (start_pulse) begin
        main_reg[0] <= main_list[0];
        main_reg[1] <= main_list[1];
        main_reg[2] <= main_list[2];
        main_reg[3] <= main_list[3];
        main_reg[4] <= main_list[4];
        main_reg[5] <= main_list[5];
        main_reg[6] <= main_list[6];
        main_reg[7] <= main_list[7];

        sub_reg[0]  <= sub_list[0];
        sub_reg[1]  <= sub_list[1];
        sub_reg[2]  <= sub_list[2];
        sub_reg[3]  <= sub_list[3];
      end
    end
  end

  // Generate start pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end

  assign start_pulse = start & ~start_d;

  // Compute empty_sub (all zeros) combinationally from latched sub_reg when running or start
  // For strict behavior aligned with input, we also consider during start using sub_list.
  // To keep it simple and deterministic, base on sub_reg during run (captured at start).
  assign empty_sub = (sub_reg[0] == 8'd0) &&
                     (sub_reg[1] == 8'd0) &&
                     (sub_reg[2] == 8'd0) &&
                     (sub_reg[3] == 8'd0);

  // Non-zero prefix length for sub_list
  // sub_nz_len is index of first zero or 4 if none are zero; if all zero, becomes 0 via empty_sub logic.
  always_comb begin
    if (empty_sub) begin
      sub_nz_len = 4'd0;
    end else if (sub_reg[0] == 8'd0) begin
      sub_nz_len = 4'd0;
    end else if (sub_reg[1] == 8'd0) begin
      sub_nz_len = 4'd1;
    end else if (sub_reg[2] == 8'd0) begin
      sub_nz_len = 4'd2;
    end else if (sub_reg[3] == 8'd0) begin
      sub_nz_len = 4'd3;
    end else begin
      sub_nz_len = 4'd4;
    end
  end

  // Non-zero prefix length for main_list
  always_comb begin
    if (main_reg[0] == 8'd0) begin
      main_nz_len = 4'd0;
    end else if (main_reg[1] == 8'd0) begin
      main_nz_len = 4'd1;
    end else if (main_reg[2] == 8'd0) begin
      main_nz_len = 4'd2;
    end else if (main_reg[3] == 8'd0) begin
      main_nz_len = 4'd3;
    end else if (main_reg[4] == 8'd0) begin
      main_nz_len = 4'd4;
    end else if (main_reg[5] == 8'd0) begin
      main_nz_len = 4'd5;
    end else if (main_reg[6] == 8'd0) begin
      main_nz_len = 4'd6;
    end else if (main_reg[7] == 8'd0) begin
      main_nz_len = 4'd7;
    end else begin
      main_nz_len = 4'd8;
    end
  end

  // Parallel comparators for all starting indices (0..4) using latched main_reg and sub_reg
  // Only compare up to sub_nz_len; trailing zeros in sub_reg are ignored by definition.
  always_comb begin
    // default no matches
    match_vec = 5'b0;

    // Early out: empty sub_list is handled separately in control FSM; still keep safe here

    // start index 0
    if (sub_nz_len == 4'd0) begin
      match_vec[0] = 1'b1; // empty matches anywhere
    end else begin
      match_vec[0] = 1'b1;
      if (sub_nz_len > 0 && main_reg[0] != sub_reg[0]) match_vec[0] = 1'b0;
      if (sub_nz_len > 1 && main_reg[1] != sub_reg[1]) match_vec[0] = 1'b0;
      if (sub_nz_len > 2 && main_reg[2] != sub_reg[2]) match_vec[0] = 1'b0;
      if (sub_nz_len > 3 && main_reg[3] != sub_reg[3]) match_vec[0] = 1'b0;
    end

    // start index 1
    if (sub_nz_len == 4'd0) begin
      match_vec[1] = 1'b1;
    end else begin
      match_vec[1] = 1'b1;
      if (sub_nz_len > 0 && main_reg[1] != sub_reg[0]) match_vec[1] = 1'b0;
      if (sub_nz_len > 1 && main_reg[2] != sub_reg[1]) match_vec[1] = 1'b0;
      if (sub_nz_len > 2 && main_reg[3] != sub_reg[2]) match_vec[1] = 1'b0;
      if (sub_nz_len > 3 && main_reg[4] != sub_reg[3]) match_vec[1] = 1'b0;
    end

    // start index 2
    if (sub_nz_len == 4'd0) begin
      match_vec[2] = 1'b1;
    end else begin
      match_vec[2] = 1'b1;
      if (sub_nz_len > 0 && main_reg[2] != sub_reg[0]) match_vec[2] = 1'b0;
      if (sub_nz_len > 1 && main_reg[3] != sub_reg[1]) match_vec[2] = 1'b0;
      if (sub_nz_len > 2 && main_reg[4] != sub_reg[2]) match_vec[2] = 1'b0;
      if (sub_nz_len > 3 && main_reg[5] != sub_reg[3]) match_vec[2] = 1'b0;
    end

    // start index 3
    if (sub_nz_len == 4'd0) begin
      match_vec[3] = 1'b1;
    end else begin
      match_vec[3] = 1'b1;
      if (sub_nz_len > 0 && main_reg[3] != sub_reg[0]) match_vec[3] = 1'b0;
      if (sub_nz_len > 1 && main_reg[4] != sub_reg[1]) match_vec[3] = 1'b0;
      if (sub_nz_len > 2 && main_reg[5] != sub_reg[2]) match_vec[3] = 1'b0;
      if (sub_nz_len > 3 && main_reg[6] != sub_reg[3]) match_vec[3] = 1'b0;
    end

    // start index 4
    if (sub_nz_len == 4'd0) begin
      match_vec[4] = 1'b1;
    end else begin
      match_vec[4] = 1'b1;
      if (sub_nz_len > 0 && main_reg[4] != sub_reg[0]) match_vec[4] = 1'b0;
      if (sub_nz_len > 1 && main_reg[5] != sub_reg[1]) match_vec[4] = 1'b0;
      if (sub_nz_len > 2 && main_reg[6] != sub_reg[2]) match_vec[4] = 1'b0;
      if (sub_nz_len > 3 && main_reg[7] != sub_reg[3]) match_vec[4] = 1'b0;
    end
  end

  // Control: run for exactly 8 cycles after start_pulse, pipeline comparisons; done at cycle 7
  // Found behavior:
  // - If empty_sub: found=1
  // - Else if sub_nz_len > main_nz_len: found=0
  // - Else: found=1 if any match_vec bit is 1 where starting index is valid within main_nz_len

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cycle_cnt <= 3'd0;
      running   <= 1'b0;
      found     <= 1'b0;
      done      <= 1'b0;
    end else begin
      // Default done low unless explicitly set when completing window
      done <= 1'b0;

      if (start_pulse) begin
        running   <= 1'b1;
        cycle_cnt <= 3'd0;
        found     <= 1'b0; // will be updated during run
      end else if (running) begin
        cycle_cnt <= cycle_cnt + 3'd1;
        if (cycle_cnt == 3'd7) begin
          running <= 1'b0;
          done    <= 1'b1;
        end
      end

      if (running) begin
        // Evaluate found each cycle based on captured lists (combinational match_vec)
        // so that by final cycle the result is stable.
        if (empty_sub) begin
          found <= 1'b1;
        end else if (sub_nz_len > main_nz_len) begin
          found <= 1'b0;
        end else begin
          // Only consider starting indices where full sub_nz_len fits in main_nz_len
          // Valid start_max = main_nz_len - sub_nz_len
          logic [3:0] start_max;
          logic       any_match;
          start_max = main_nz_len - sub_nz_len;
          any_match = 1'b0;

          if (start_max >= 4'd0 && match_vec[0]) any_match = 1'b1;
          if (start_max >= 4'd1 && match_vec[1]) any_match = 1'b1;
          if (start_max >= 4'd2 && match_vec[2]) any_match = 1'b1;
          if (start_max >= 4'd3 && match_vec[3]) any_match = 1'b1;
          if (start_max >= 4'd4 && match_vec[4]) any_match = 1'b1;

          found <= any_match;
        end
      end
    end
  end

endmodule