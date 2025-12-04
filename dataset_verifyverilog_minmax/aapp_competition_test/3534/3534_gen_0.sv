module mirka_piano_solver (
  input  clk,
  input  rst_n,
  input  start,
  input  [2:0] N,
  input  signed [7:0] a0, a1, a2, a3, a4, a5, a6, a7,
  output reg       done,
  output reg [3:0] max_correct,
  output reg [7:0] best_K
);

  // States
  localparam IDLE           = 3'd0;
  localparam INIT           = 3'd1;
  localparam EVAL_K_START   = 3'd2;
  localparam EVAL_NOTE      = 3'd3;
  localparam UPDATE_MAX     = 3'd4;
  localparam FINISH         = 3'd5;

  // Internal registers
  reg [2:0] state;
  reg [7:0] k_q;          // current K being evaluated
  reg [7:0] best_k_r;     // best K found so far
  reg [3:0] max_correct_r;
  reg [3:0] curr_count;   // correct count for current K

  reg signed [7:0] prev_note;
  reg signed [7:0] curr_note;

  // Latched inputs
  reg [2:0] n_r;
  reg signed [7:0] a_reg [0:7];

  // Index for note compare (2..N)
  reg [3:0] idx_r;

  // Comparison candidates
  wire signed [7:0] cand_up   = prev_note + $signed(k_q);
  wire signed [7:0] cand_down = prev_note - $signed(k_q);

  // Input sample selected by idx_r
  wire signed [7:0] target = a_reg[idx_r];

  // Determine which candidate matches target
  wire up_match   = (cand_up   == target);
  wire down_match = (cand_down == target);

  // Determine which direction to take (priority: up, down, equal)
  reg choose_up;
  reg choose_eq;
  always @(*) begin
    if (up_match)   choose_up = 1'b1;
    else            choose_up = 1'b0;
    if (down_match) choose_eq = 1'b0; // up has priority
    else if (up_match) choose_eq = 1'b0;
    else choose_eq = 1'b1; // equal branch
  end

  // State and data registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      done           <= 1'b0;
      max_correct    <= 4'd0;
      best_K         <= 8'd0;
      best_k_r       <= 8'd0;
      max_correct_r  <= 4'd0;
      curr_count     <= 4'd0;
      k_q            <= 8'd0;
      n_r            <= 3'd2;
      prev_note      <= 8'd0;
      curr_note      <= 8'd0;
      idx_r          <= 4'd2;
      a_reg[0]       <= 8'd0;
      a_reg[1]       <= 8'd0;
      a_reg[2]       <= 8'd0;
      a_reg[3]       <= 8'd0;
      a_reg[4]       <= 8'd0;
      a_reg[5]       <= 8'd0;
      a_reg[6]       <= 8'd0;
      a_reg[7]       <= 8'd0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs
            n_r    <= N;
            a_reg[0] <= a0;
            a_reg[1] <= a1;
            a_reg[2] <= a2;
            a_reg[3] <= a3;
            a_reg[4] <= a4;
            a_reg[5] <= a5;
            a_reg[6] <= a6;
            a_reg[7] <= a7;
            // Start with K = 0
            k_q    <= 8'd0;
            // Initialize with first note match
            curr_count     <= 4'd1;
            max_correct_r  <= 4'd1;
            best_k_r       <= 8'd0;
            state          <= EVAL_K_START;
          end else begin
            state <= IDLE;
          end
        end

        INIT: begin
          // Fallback; not used in current flow but kept for clarity
          k_q            <= 8'd0;
          curr_count     <= 4'd1;
          max_correct_r  <= 4'd1;
          best_k_r       <= 8'd0;
          state          <= EVAL_K_START;
        end

        EVAL_K_START: begin
          // First note is a_reg[0]; start comparisons from index 2
          prev_note      <= a_reg[0];
          curr_note      <= a_reg[0];
          idx_r          <= 4'd2;     // next note to compare is a_reg[2]
          state          <= EVAL_NOTE;
        end

        EVAL_NOTE: begin
          if (idx_r > n_r) begin
            // End of sequence for this K
            state <= UPDATE_MAX;
          end else begin
            // Select direction: up, then down, then equal
            if (choose_up) begin
              curr_note <= cand_up;
            end else begin
              if (choose_eq) begin
                curr_note <= prev_note; // equal case
              end else begin
                curr_note <= cand_down;
              end
            end

            // Increment count on match
            if (curr_note == target) begin
              curr_count <= curr_count + 1;
            end

            // Prepare for next note
            prev_note <= (choose_up) ? cand_up : ((choose_eq) ? prev_note : cand_down);
            idx_r     <= idx_r + 1;
          end
        end

        UPDATE_MAX: begin
          if (curr_count > max_correct_r) begin
            max_correct_r <= curr_count;
            best_k_r      <= k_q;
          end
          // Next K
          if (k_q == 8'd255) begin
            state <= FINISH;
          end else begin
            k_q        <= k_q + 1;
            curr_count <= 4'd1;     // reset count for next K (first note match)
            state      <= EVAL_K_START;
          end
        end

        FINISH: begin
          best_K      <= best_k_r;
          max_correct <= max_correct_r;
          done        <= 1'b1;
          state       <= IDLE; // Return to idle; outputs remain valid
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
