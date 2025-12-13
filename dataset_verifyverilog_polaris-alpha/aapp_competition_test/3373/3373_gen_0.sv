module longest_balanced_parentheses(
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0][5:0] pieces, // 3 pieces, each 6 bits
  output reg [4:0] max_length,
  output reg       done
);

  // ------------------------------------------------------------
  // Internal types and signals
  // ------------------------------------------------------------
  typedef struct packed {
    logic signed [4:0] balance;      // -6..+6 fits in 5 bits signed
    logic       [4:0] max_valid;     // 0..6
    logic             is_balanced;   // 1 if entire piece is balanced
  } piece_info_t;

  piece_info_t pinfo   [2:0];
  piece_info_t pinfo_r [2:0]; // registered at start

  // DP / combination iteration state
  reg [1:0]  cycle_cnt;              // 0..3
  reg        busy;                   // active computation

  // Current DP state (carried across cycles)
  reg  signed [3:0] current_balance; // -8..+7
  reg        [4:0] current_length;   // 0..30
  reg        [4:0] best_length;      // running maximum

  // ------------------------------------------------------------
  // Combinational precompute for each piece (from raw bits)
  // ------------------------------------------------------------
  genvar gi;
  generate
    for (gi = 0; gi < 3; gi = gi + 1) begin : GEN_PIECE_INFO
      integer i;
      reg signed [4:0] bal;
      reg [4:0] max_valid_local;

      always @* begin
        // Compute net balance
        bal = 0;
        for (i = 0; i < 6; i = i + 1) begin
          if (pieces[gi][i])
            bal = bal + 1; // '('
          else
            bal = bal - 1; // ')'
        end

        // Compute longest balanced substring length
        // Brute-force over all substrings [s,e)
        max_valid_local = 0;
        for (int s = 0; s < 6; s = s + 1) begin
          reg signed [4:0] b_sub;
          b_sub = 0;
          for (int e = s; e < 6; e = e + 1) begin
            if (pieces[gi][e])
              b_sub = b_sub + 1;
            else
              b_sub = b_sub - 1;
            if (b_sub == 0) begin
              if ((e - s + 1) > max_valid_local)
                max_valid_local = e - s + 1;
            end
          end
        end

        pinfo[gi].balance    = bal;
        pinfo[gi].max_valid  = max_valid_local;
        pinfo[gi].is_balanced = (bal == 0);
      end
    end
  endgenerate

  // ------------------------------------------------------------
  // Helper function: update best length with effects of one piece
  // ------------------------------------------------------------
  function automatic [4:0] update_best_piece(
    input signed [3:0] cb,
    input       [4:0] cl,
    input       [4:0] best,
    input piece_info_t pi
  );
    reg [4:0] best_n;
    best_n = best;

    // 1) Full-piece balanced contribution if we can append whole piece
    if (cb + pi.balance >= 0) begin
      if (cl + 6 > best_n)
        best_n = cl + 6;
    end

    // 2) Standalone best inside this piece (max_valid) - independent
    if (pi.max_valid > best_n)
      best_n = pi.max_valid;

    update_best_piece = best_n;
  endfunction

  // ------------------------------------------------------------
  // Sequential control: pipeline over 3 cycles + 1 cycle latency
  // ------------------------------------------------------------
  integer k;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (k = 0; k < 3; k = k + 1) begin
        pinfo_r[k] <= '{balance:0, max_valid:0, is_balanced:1'b0};
      end
      cycle_cnt       <= 2'd0;
      busy            <= 1'b0;
      current_balance <= 4'sd0;
      current_length  <= 5'd0;
      best_length     <= 5'd0;
      max_length      <= 5'd0;
      done            <= 1'b0;
    end else begin
      done <= 1'b0;

      // Start pulse: latch precomputed info and initialize DP
      if (start && !busy) begin
        for (k = 0; k < 3; k = k + 1) begin
          pinfo_r[k] <= pinfo[k];
        end
        busy            <= 1'b1;
        cycle_cnt       <= 2'd0;
        current_balance <= 4'sd0;
        current_length  <= 5'd0;
        best_length     <= 5'd0;
      end else if (busy) begin
        // Process one piece per cycle; three total cycles
        piece_info_t pi_c;
        pi_c = pinfo_r[cycle_cnt];

        // Attempt to append this piece to the current sequence if valid
        if (current_balance + pi_c.balance >= 0 && current_length + 6 <= 5'd30) begin
          current_balance <= current_balance + pi_c.balance;
          current_length  <= current_length + 6;
        end

        // Update best_length using this piece (full and internal best)
        best_length <= update_best_piece(current_balance, current_length, best_length, pi_c);

        // Advance cycle count
        if (cycle_cnt == 2'd2) begin
          // After 3rd piece, computation completes next
          busy       <= 1'b0;
          cycle_cnt  <= 2'd0;
          max_length <= update_best_piece(current_balance, current_length, best_length, pi_c);
          done       <= 1'b1;
        end else begin
          cycle_cnt <= cycle_cnt + 2'd1;
        end
      end
    end
  end

endmodule