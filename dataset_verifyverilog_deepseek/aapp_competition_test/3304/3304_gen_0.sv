module elf_seating_simulator (input clk, input rst_n, input start, input [1:0] n, input [3:0][1:0] a, input [3:0][31:0] p, input [3:0][31:0] v, input [3:0][1:0] elf_order, output reg [2:0] victory_count, output reg done);
  typedef enum logic [1:0] { IDLE, FIND_SEAT, DONE } state_t;
  reg [1:0] current_elf;
  reg [3:0] occupied;
  state_t state;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      victory_count <= 0;
      done <= 0;
      occupied <= 4'b0;
      current_elf <= 2'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= FIND_SEAT;
            occupied <= 4'b0;
            victory_count <= 3'b0;
            current_elf <= 2'b0;
          end
        end
        FIND_SEAT: begin
          reg [1:0] elf_idx;
          reg [1:0] pref;
          reg [3:0] valid_mask;
          reg [3:0] occ_valid;
          reg [1:0] seat;
          reg found;
          elf_idx = elf_order[current_elf];
          pref = a[elf_idx] - 2'b1;
          valid_mask = (4'b1 << (n + 2'b1)) - 4'b1;
          occ_valid = occupied & valid_mask;
          seat = pref;
          found = 1'b0;
          if (occ_valid[pref] == 1'b0) begin
            seat = pref;
            found = 1'b1;
          end else begin
            for (int i=1; i<=3; i=i+1) begin
              reg [1:0] probe_idx;
              probe_idx = (pref + i) % (n + 1);
              if (probe_idx > (n)) begin
                probe_idx = probe_idx - (n + 1);
              end
              if (occ_valid[probe_idx] == 1'b0 && !found) begin
                seat = probe_idx;
                found = 1'b1;
              end
            end
          end
          occupied <= occupied | (4'b1 << seat);
          if (v[elf_idx] > p[seat]) begin
            victory_count <= victory_count + 3'b1;
          end
          if (current_elf == n) begin
            state <= DONE;
          end else begin
            current_elf <= current_elf + 2'b1;
          end
        end
        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= FIND_SEAT;
            occupied <= 4'b0;
            victory_count <= 3'b0;
            current_elf <= 2'b0;
            done <= 1'b0;
          end
        end
      endcase
    end
  end
endmodule