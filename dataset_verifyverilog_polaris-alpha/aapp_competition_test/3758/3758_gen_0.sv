module packman_optimizer(
  input clk,
  input rst_n,
  input start,
  input [15:0] game_field, // 16-bit field: 01='*', 10='P', 00='.'
  output reg [5:0] min_time, // 6-bit output (max time 32)
  output reg done // high when computation completes
);

  // Decode grid: 16 cells, each 2 bits: index i uses bits [2*i+1 : 2*i]
  // 01 = '*', 10 = 'P', 00 = '.'

  // Combinational decode of packman and star masks
  reg [15:0] pack_mask;
  reg [15:0] star_mask;
  integer i;

  always @* begin
    pack_mask = 16'b0;
    star_mask = 16'b0;
    for (i = 0; i < 16; i = i + 1) begin
      case (game_field[2*i +: 2])
        2'b01: star_mask[i] = 1'b1;
        2'b10: pack_mask[i] = 1'b1;
        default: begin end
      endcase
    end
  end

  // State machine
  typedef enum logic [2:0] {
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_MID    = 3'd2,
    S_CHECK  = 3'd3,
    S_UPDATE = 3'd4,
    S_DONE   = 3'd5
  } state_t;

  state_t state, next_state;

  // Binary search registers
  reg [5:0] l_reg, r_reg, m_reg;

  // Latched masks at start to keep inputs stable during computation
  reg [15:0] pack_mask_reg;
  reg [15:0] star_mask_reg;

  // Feasibility result pipeline
  reg feasible_comb;
  reg feasible_reg;

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= S_IDLE;
      l_reg          <= 6'd0;
      r_reg          <= 6'd32;
      m_reg          <= 6'd0;
      pack_mask_reg  <= 16'd0;
      star_mask_reg  <= 16'd0;
      feasible_reg   <= 1'b0;
      min_time       <= 6'd0;
      done           <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch masks
            pack_mask_reg <= pack_mask;
            star_mask_reg <= star_mask;
            l_reg         <= 6'd0;
            r_reg         <= 6'd32;
          end
        end

        S_INIT: begin
          // Nothing additional; masks and bounds already set
        end

        S_MID: begin
          // Capture midpoint
          m_reg <= (l_reg + r_reg) >> 1;
        end

        S_CHECK: begin
          // Latch feasibility result
          feasible_reg <= feasible_comb;
        end

        S_UPDATE: begin
          // Update binary search bounds based on feasibility
          if (feasible_reg)
            r_reg <= m_reg;
          else
            l_reg <= m_reg;
        end

        S_DONE: begin
          // Output final result
          min_time <= r_reg;
          done     <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_INIT;
      end

      S_INIT: begin
        // Immediately proceed to first midpoint calculation
        next_state = S_MID;
      end

      S_MID: begin
        next_state = S_CHECK;
      end

      S_CHECK: begin
        next_state = S_UPDATE;
      end

      S_UPDATE: begin
        // Decide whether to continue binary search or finish
        if ((r_reg - l_reg) > 6'd1)
          next_state = S_MID;
        else
          next_state = S_DONE;
      end

      S_DONE: begin
        // Stay done until start deasserts then reasserted; return to IDLE when start=0
        if (!start)
          next_state = S_IDLE;
      end

      default: begin
        next_state = S_IDLE;
      end
    endcase
  end

  // Feasibility check for a given time m_reg (combinational)
  // For each star, verify there exists at least one packman such that
  // distance <= m_reg. Distance is |p - s| on 1D 16-cell line.

  function automatic logic can_cover_star(
    input [3:0] s_pos,
    input [15:0] p_mask,
    input [5:0] m
  );
    integer pj;
    logic hit;
    begin
      hit = 1'b0;
      for (pj = 0; pj < 16; pj = pj + 1) begin
        if (p_mask[pj]) begin
          if ((pj >= s_pos) ? ((pj - s_pos) <= m) : ((s_pos - pj) <= m)) begin
            hit = 1'b1;
          end
        end
      end
      can_cover_star = hit;
    end
  endfunction

  always @* begin
    feasible_comb = 1'b1;
    if (m_reg == 6'd32) begin
      // Max time always feasible if any packman exists for all stars; if no packman but stars exist => infeasible
      logic any_p;
      logic any_s;
      integer k;
      any_p = 1'b0;
      any_s = 1'b0;
      for (k = 0; k < 16; k = k + 1) begin
        if (pack_mask_reg[k]) any_p = 1'b1;
        if (star_mask_reg[k]) any_s = 1'b1;
      end
      if (any_s && !any_p)
        feasible_comb = 1'b0;
      else
        feasible_comb = 1'b1;
    end else begin
      integer si;
      logic ok;
      ok = 1'b1;
      for (si = 0; si < 16; si = si + 1) begin
        if (star_mask_reg[si]) begin
          if (!can_cover_star(si[3:0], pack_mask_reg, m_reg)) begin
            ok = 1'b0;
          end
        end
      end
      feasible_comb = ok;
    end
  end

endmodule