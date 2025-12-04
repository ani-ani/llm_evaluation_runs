module even_nested_elements (
  input reg clk,
  input reg rst_n,
  input reg start,
  input reg [15:0][2:0][7:0] flat_tuple, // flattened tuple structure (16 elements, each 9 bits: [2:0]=level, [7:0]=value)
  input reg [3:0] size_in,                // number of valid elements in input (1-16)
  output reg [15:0][2:0][7:0] flat_out,   // filtered output tuple
  output reg [3:0] size_out,              // number of elements in output
  output reg done                         // high when processing complete
);

  // Level encoding: 0=top, 1=first nested, 2=second nested, 3=third nested
  // Each tuple element: {level[2:0], value[7:0]} -> 11 bits total (10:0)
  localparam LEVEL_W = 3;
  localparam VAL_W   = 8;
  localparam EL_W    = LEVEL_W + VAL_W; // 11
  localparam DEPTH   = 3; // maximum depth
  localparam MAXN    = 16;
  localparam SIZE_W  = 4;

  // States
  localparam ST_IDLE      = 2'b00;
  localparam ST_PROCESS   = 2'b01;
  localparam ST_DONE      = 2'b10;

  reg [1:0] state, next_state;
  reg [SIZE_W-1:0] i;        // input index
  reg [SIZE_W-1:0] o_idx;    // output index
  reg [$clog2(DEPTH+2)-1:0] sp; // stack pointer (0..DEPTH)
  reg [DEPTH:0][LEVEL_W-1:0] par_stack; // parent levels stack (0..DEPTH)
  reg [VAL_W-1:0] val;
  reg [LEVEL_W-1:0] lvl;
  reg valids_in_window;

  function [LEVEL_W-1:0] current_level;
    current_level = (sp == 0) ? '0 : par_stack[sp-1];
  endfunction

  function [LEVEL_W-1:0] next_expected_level;
    input [LEVEL_W-1:0] cur;
    next_expected_level = (cur < DEPTH) ? (cur + 1) : cur;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= ST_IDLE;
      i <= '0;
      o_idx <= '0;
      sp <= '0;
      par_stack <= '0;
      size_out <= '0;
      flat_out <= '0;
      done <= 1'b0;
      val <= '0;
      lvl <= '0;
      valids_in_window <= 1'b0;
    end else begin
      // Defaults (can be overridden by next_state logic)
      valids_in_window <= 1'b0;

      case (state)
        ST_IDLE: begin
          done <= 1'b0;
          size_out <= '0;
          o_idx <= '0;
          i <= '0;
          sp <= '0;
          par_stack <= '0;
          flat_out <= '0;
          if (start) begin
            state <= ST_PROCESS;
          end
        end

        ST_PROCESS: begin
          if (i < size_in) begin
            // Parse input element (10:8 -> level[2:0], 7:0 -> value[7:0])
            lvl <= flat_tuple[i][2:0];
            val <= flat_tuple[i][7:0];
            i <= i + 1;

            // If there are still remaining elements in the window, mark window non-empty
            if ((i + 1) < size_in) begin
              valids_in_window <= 1'b1;
            end else begin
              valids_in_window <= 1'b0;
            end

            // Verify level hierarchy (allow 0 or current_level+1)
            if ((lvl == '0) || (lvl == next_expected_level(current_level()))) begin
              // Value is even and non-zero
              if ((val[0] == 1'b0) && (val != 8'h00)) begin
                if (o_idx < MAXN) begin
                  // Write out filtered element, preserving structure
                  flat_out[o_idx][2:0] <= lvl;
                  flat_out[o_idx][7:0] <= val;
                  o_idx <= o_idx + 1;
                  // Push parent for next level if within max depth
                  if (lvl < DEPTH) begin
                    par_stack[sp] <= lvl;
                    sp <= sp + 1;
                  end
                end
              end else begin
                // Odd or zero value removed: do not write, do not push
              end
            end else begin
              // Invalid level jump: treat as unused; no write, no push
            end
          end else begin
            // Drain condition: no more input and no pending structure
            if (!valids_in_window) begin
              state <= ST_DONE;
              done <= 1'b1;
              size_out <= o_idx;
            end
          end
        end

        ST_DONE: begin
          done <= 1'b1;
          size_out <= o_idx;
          // Hold outputs until next start
          if (!start) begin
            // remain in DONE until start deasserted; returning to IDLE on next start
          end
          if (start) begin
            // Allow immediate restart
            state <= ST_PROCESS;
            done <= 1'b0;
            i <= '0;
            o_idx <= '0;
            sp <= '0;
            par_stack <= '0;
            size_out <= '0;
            flat_out <= '0;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

  // Unused output elements should be set to 8'hFF for value field
  // (level can be anything, we keep last assigned level; this is a don't-care)
  genvar gi;
  for (gi = 0; gi < MAXN; gi = gi + 1) begin : unused_fill
    always @(*) begin
      if (o_idx > gi) begin
        // Already written; do not modify
      end else begin
        flat_out[gi][7:0] = 8'hFF;
      end
    end
  end

endmodule
