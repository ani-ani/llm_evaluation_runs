module elf_seating_simulator(
  input clk,
  input rst_n,
  input start,
  input [1:0] n,
  input [3:0][1:0] a,
  input [3:0][31:0] p,
  input [3:0][31:0] v,
  input [3:0][1:0] elf_order,
  output reg [2:0] victory_count,
  output reg done
);

  // State encoding
  localparam IDLE      = 2'b00;
  localparam FIND_SEAT = 2'b01;
  localparam DONE      = 2'b10;

  reg [1:0] state, next_state;

  // Internal registers
  reg [1:0] num_pairs;          // effective N = n+1 (1..4)
  reg [1:0] elf_idx;            // index of current elf (0..3)
  reg [1:0] seat_idx;           // current seat index being probed (0..3)
  reg [3:0] occupied;           // seat occupancy bitmap
  reg [31:0] curr_elf_strength; // current elf strength
  reg [31:0] curr_dwarf_strength; // current dwarf strength
  reg [1:0] curr_elf_id;        // current elf id from elf_order
  reg seat_assigned;            // indicates seat found in this cycle

  // Combinational next-state and control
  always @* begin
    next_state = state;
    seat_assigned = 1'b0;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = FIND_SEAT;
        end
      end

      FIND_SEAT: begin
        // Seat search: probe seats until an unoccupied one is found within num_pairs
        // We use a simple sequential search: at most num_pairs steps.
        // Combinational loop for one elf within one cycle.
        // Initialize defaults
        seat_assigned = 1'b0;
        begin : seat_search
          integer k;
          reg [1:0] probe;
          probe = seat_idx;
          for (k = 0; k < 4; k = k + 1) begin
            if (k < num_pairs) begin
              if (!occupied[probe]) begin
                seat_assigned = 1'b1;
                disable seat_search;
              end
              // advance probe with wrap within 4, but only first num_pairs considered logically
              probe = probe + 2'd1;
              if (probe >= num_pairs)
                probe = 2'd0;
            end
          end
        end

        // Next state decision
        if (seat_assigned) begin
          if (elf_idx + 2'd1 >= num_pairs)
            next_state = DONE;
          else
            next_state = FIND_SEAT;
        end
      end

      DONE: begin
        if (!start)
          next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state          <= IDLE;
      victory_count  <= 3'd0;
      done           <= 1'b0;
      occupied       <= 4'b0000;
      elf_idx        <= 2'd0;
      seat_idx       <= 2'd0;
      num_pairs      <= 2'd0;
      curr_elf_strength   <= 32'd0;
      curr_dwarf_strength <= 32'd0;
      curr_elf_id         <= 2'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            // n is 0-3 representing 1-4
            num_pairs     <= n + 2'd1;
            occupied      <= 4'b0000;
            victory_count <= 3'd0;
            elf_idx       <= 2'd0;

            // Load first elf info
            curr_elf_id         <= elf_order[0];
            curr_elf_strength   <= v[elf_order[0]];
            seat_idx            <= (a[elf_order[0]] - 2'd1); // 1-based to 0-based
          end
        end

        FIND_SEAT: begin
          if (seat_assigned) begin
            // Use seat_idx as the seat where elf will sit (seat_idx already set as start).
            // We need to recompute final chosen seat similarly as combinational search.
            integer k2;
            reg [1:0] probe2;
            reg [1:0] chosen_seat;
            probe2 = seat_idx;
            chosen_seat = seat_idx;
            for (k2 = 0; k2 < 4; k2 = k2 + 1) begin
              if (k2 < num_pairs) begin
                if (!occupied[probe2]) begin
                  chosen_seat = probe2;
                  disable for_search2;
                end
                probe2 = probe2 + 2'd1;
                if (probe2 >= num_pairs)
                  probe2 = 2'd0;
              end
            end
            for_search2: begin end

            // Mark seat occupied
            occupied[chosen_seat] <= 1'b1;

            // Compare strengths
            curr_dwarf_strength <= p[chosen_seat];
            if (curr_elf_strength > p[chosen_seat])
              victory_count <= victory_count + 3'd1;

            // Prepare next elf if any
            if (elf_idx + 2'd1 < num_pairs) begin
              elf_idx           <= elf_idx + 2'd1;
              curr_elf_id       <= elf_order[elf_idx + 2'd1];
              curr_elf_strength <= v[elf_order[elf_idx + 2'd1]];
              seat_idx          <= (a[elf_order[elf_idx + 2'd1]] - 2'd1);
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            // stay values until next start
            done <= 1'b0;
          end
        end

        default: begin
          // should not occur
        end
      endcase
    end
  end

endmodule