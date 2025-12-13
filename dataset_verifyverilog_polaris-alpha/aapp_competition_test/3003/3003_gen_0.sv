module graph_color(
  input clk,
  input rst_n,
  input start,
  input [2:0] n_val,
  input [63:0] adjacency,
  output reg [3:0] colors,
  output reg done
);

  // State encoding
  localparam IDLE      = 3'd0;
  localparam INIT      = 3'd1;
  localparam TRY_COLOR = 3'd2;
  localparam CHECK_VAL = 3'd3;
  localparam ASSIGN    = 3'd4;
  localparam BACKTRACK = 3'd5;
  localparam FINISH    = 3'd6;

  reg [2:0] state, next_state;

  // Internal registers
  reg [2:0] n;                    // number of vertices (2..8)
  reg [2:0] v_idx;                // current vertex index (0..7)
  reg [3:0] C_max;                // current upper bound on colors
  reg [3:0] best_C;               // best (minimal) colors found so far
  reg [7:0] color;                // color[v] for v=0..7 (4 bits each not needed; use 4 total as small range)

  // For checking candidate color
  reg [3:0] c;                    // current candidate color (1..C_max)
  reg conflict;                   // conflict flag during adjacency check
  reg [2:0] check_idx;            // neighbor index for conflict scan
  reg check_done;                 // indicates completion of scan

  // Control flags
  reg searching;                  // indicates active search
  reg new_start;                  // latch start edge

  // Flattened adjacency access function
  function automatic bit edge(input [2:0] i, input [2:0] j);
    begin
      edge = adjacency[{i,3'b000} + j];
    end
  endfunction

  // Detect start pulse (synchronous edge detect)
  reg start_d;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  wire start_pulse = start & ~start_d;

  // Sequential state and main registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      done      <= 1'b0;
      colors    <= 4'd0;
      n         <= 3'd0;
      v_idx     <= 3'd0;
      C_max     <= 4'd0;
      best_C    <= 4'd0;
      color     <= 8'd0;
      c         <= 4'd0;
      conflict  <= 1'b0;
      check_idx <= 3'd0;
      check_done<= 1'b0;
      searching <= 1'b0;
      new_start <= 1'b0;
    end else begin
      state <= next_state;

      // Latch new start when in IDLE
      if (state == IDLE) begin
        if (start_pulse) begin
          new_start <= 1'b1;
        end else if (next_state != IDLE) begin
          new_start <= 1'b0;
        end
      end

      case (state)
        IDLE: begin
          done   <= 1'b0;
          if (start_pulse || new_start) begin
            // Initialize for new computation
            n      <= (n_val < 3'd2) ? 3'd2 : n_val; // ensure minimum 2
            C_max  <= (n_val < 3'd2) ? 4'd2 : {1'b0,n_val};
            best_C <= 4'd15; // large initial
            color  <= 8'd0;
            v_idx  <= 3'd0;
            searching <= 1'b1;
            // c, conflict, etc. cleared in INIT
          end
        end

        INIT: begin
          // Starting new attempt with current C_max
          v_idx     <= 3'd0;
          color     <= 8'd0;
          c         <= 4'd1;
          conflict  <= 1'b0;
          check_idx <= 3'd0;
          check_done<= 1'b0;
        end

        TRY_COLOR: begin
          // TRY_COLOR: start trying candidate color for current vertex
          conflict  <= 1'b0;
          check_idx <= 3'd0;
          check_done<= 1'b0;
        end

        CHECK_VAL: begin
          // One step of checking adjacency for conflict
          if (!check_done) begin
            if (check_idx < v_idx) begin
              if (edge(v_idx, check_idx) && (color[check_idx] == c[0])) begin
                conflict <= 1'b1;
              end
              check_idx <= check_idx + 3'd1;
            end else begin
              check_done <= 1'b1;
            end
          end
        end

        ASSIGN: begin
          // Assign color to current vertex and move to next
          color[v_idx] <= c[0];
          if (v_idx + 3'd1 == n) begin
            // Found a full valid coloring with <= C_max colors
            if (C_max < best_C)
              best_C <= C_max;
          end
        end

        BACKTRACK: begin
          // Handled in combinational; nothing specific here
        end

        FINISH: begin
          done   <= 1'b1;
          colors <= best_C;
          searching <= 1'b0;
        end

        default: ;
      endcase
    end
  end

  // Next state and control logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start_pulse || new_start)
          next_state = INIT;
      end

      INIT: begin
        // Immediately go to TRY_COLOR for first vertex
        next_state = TRY_COLOR;
      end

      TRY_COLOR: begin
        // If candidate color exceeds C_max, need backtrack or stop
        if (c > C_max) begin
          next_state = BACKTRACK;
        end else begin
          next_state = CHECK_VAL;
        end
      end

      CHECK_VAL: begin
        if (!check_done) begin
          next_state = CHECK_VAL; // continue scanning
        end else begin
          if (!conflict) begin
            next_state = ASSIGN;  // valid color
          end else begin
            // Try next color
            if (c + 4'd1 > C_max)
              next_state = BACKTRACK;
            else
              next_state = TRY_COLOR;
          end
        end
      end

      ASSIGN: begin
        if (v_idx + 3'd1 == n) begin
          // Completed coloring for all vertices under C_max
          // Tighten C_max and restart search with new bound
          if (C_max > 4'd1)
            next_state = INIT;
          else
            next_state = FINISH;
        end else begin
          // Move to next vertex
          next_state = TRY_COLOR;
        end
      end

      BACKTRACK: begin
        // If at first vertex and no color works for current C_max
        // then either increase C_max (bounded by n) or finish
        if (v_idx == 3'd0) begin
          if (C_max < n) begin
            // increase color bound and restart
            next_state = INIT;
          end else begin
            // no better possible; finish with current best_C or C_max
            next_state = FINISH;
          end
        end else begin
          // step back one vertex and try next color
          next_state = TRY_COLOR;
        end
      end

      FINISH: begin
        // stay here until next start
        if (start_pulse)
          next_state = INIT;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule
