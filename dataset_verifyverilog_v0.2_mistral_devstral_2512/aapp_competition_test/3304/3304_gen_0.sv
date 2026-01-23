module elf_dwarf_optimizer (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [7:0] A_i [0:7],
  input [15:0] P_i [0:7],
  input [15:0] V_i [0:7],
  output reg [3:0] result,
  output reg done
);

  parameter MAX_N = 8;
  parameter STRENGTH_WIDTH = 16;
  parameter LABEL_WIDTH = 3;

  typedef enum logic [2:0] {
    IDLE,
    INIT_PERM,
    NEXT_PERM,
    SIM_SEAT,
    SEAT_ELF,
    COUNT_WINS,
    UPDATE_MAX,
    DONE
  } state_t;

  state_t state;
  reg [2:0] elf_count;
  reg [2:0] perm_ptr;
  reg [2:0] elf_idx;
  reg [2:0] dwarf_idx;
  reg [2:0] perm [0:MAX_N-1];
  reg [2:0] current_perm [0:MAX_N-1];
  reg [7:0] occupied;
  reg [3:0] current_wins;
  reg [3:0] max_wins;
  reg [2:0] count_ptr;
  reg [2:0] next_elf;
  reg [2:0] temp_dwarf;
  reg found;
  reg [2:0] i, j;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      elf_count <= 0;
      perm_ptr <= 0;
      elf_idx <= 0;
      dwarf_idx <= 0;
      for (i = 0; i < MAX_N; i = i + 1) begin
        perm[i] <= 0;
        current_perm[i] <= 0;
      end
      occupied <= 0;
      current_wins <= 0;
      max_wins <= 0;
      count_ptr <= 0;
      next_elf <= 0;
      temp_dwarf <= 0;
      found <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT_PERM;
            elf_count <= 0;
            perm_ptr <= 0;
            max_wins <= 0;
            for (i = 0; i < MAX_N; i = i + 1) begin
              perm[i] <= i;
              current_perm[i] <= 0;
            end
          end
        end

        INIT_PERM: begin
          state <= SIM_SEAT;
          for (i = 0; i < MAX_N; i = i + 1) begin
            current_perm[i] <= perm[i];
          end
          occupied <= 0;
          current_wins <= 0;
          elf_idx <= 0;
        end

        SIM_SEAT: begin
          if (elf_idx < N) begin
            state <= SEAT_ELF;
            dwarf_idx <= A_i[current_perm[elf_idx]];
            found <= 0;
          end else begin
            state <= COUNT_WINS;
            count_ptr <= 0;
          end
        end

        SEAT_ELF: begin
          if (!found && dwarf_idx < MAX_N) begin
            if (!occupied[dwarf_idx]) begin
              occupied[dwarf_idx] <= 1;
              found <= 1;
            end else begin
              dwarf_idx <= dwarf_idx + 1;
            end
          end else begin
            if (found) begin
              elf_idx <= elf_idx + 1;
              state <= SIM_SEAT;
            end else begin
              state <= NEXT_PERM;
            end
          end
        end

        COUNT_WINS: begin
          if (count_ptr < N) begin
            temp_dwarf <= 0;
            for (j = 0; j < MAX_N; j = j + 1) begin
              if (occupied[j]) begin
                temp_dwarf <= j;
                break;
              end
            end
            if (V_i[current_perm[count_ptr]] > P_i[temp_dwarf]) begin
              current_wins <= current_wins + 1;
            end
            occupied[temp_dwarf] <= 0;
            count_ptr <= count_ptr + 1;
          end else begin
            state <= UPDATE_MAX;
          end
        end

        UPDATE_MAX: begin
          if (current_wins > max_wins) begin
            max_wins <= current_wins;
          end
          state <= NEXT_PERM;
          current_wins <= 0;
          count_ptr <= 0;
        end

        NEXT_PERM: begin
          if (elf_count == 0) begin
            state <= DONE;
            result <= max_wins;
            done <= 1;
          end else begin
            elf_count <= elf_count - 1;
            if (perm[elf_count] < perm[elf_count + 1]) begin
              next_elf <= elf_count;
            end else begin
              next_elf <= elf_count + 1;
            end
            if (next_elf < MAX_N - 1) begin
              for (i = MAX_N - 1; i > next_elf; i = i - 1) begin
                if (perm[next_elf] < perm[i]) begin
                  temp_dwarf <= perm[next_elf];
                  perm[next_elf] <= perm[i];
                  perm[i] <= temp_dwarf;
                  break;
                end
              end
              for (i = next_elf + 1, j = MAX_N - 1; i < j; i = i + 1, j = j - 1) begin
                temp_dwarf <= perm[i];
                perm[i] <= perm[j];
                perm[j] <= temp_dwarf;
              end
              state <= INIT_PERM;
            end else begin
              state <= NEXT_PERM;
            end
          end
        end

        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule