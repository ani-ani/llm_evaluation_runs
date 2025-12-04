module vote_swap_optimizer (
  input clk, rst_n, start,
  input [31:0] input_str,
  output reg [4:0] min_swaps,
  output reg is_impossible,
  output reg done
);

  typedef enum logic [2:0] { IDLE, INIT, DONE } state_t;
  state_t curr_state, next_state;
  reg [7:0] cycle_count;
  reg [3:0] i;
  reg [31:0] input_str_reg;
  reg [3:0] p1_count, p2_count, teller_count;
  reg [3:0] target_start;
  reg [7:0] target_sum;
  reg [4:0] non_tellers_in_target;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      curr_state <= IDLE;
      done <= 0;
      cycle_count <= 0;
      min_swaps <= 0;
      is_impossible <= 0;
    end else begin
      case (curr_state)
        IDLE: begin
          if (start) begin
            input_str_reg <= input_str;
            curr_state <= INIT;
            done <= 0;
            cycle_count <= 0;
          end
        end

        INIT: begin
          p1_count <= 0;
          p2_count <= 0;
          teller_count <= 0;
          for (i = 0; i < 16; i = i + 1) begin
            case (input_str_reg[2*i +: 2])
              2'b01: p1_count <= p1_count + 1;
              2'b10: p2_count <= p2_count + 1;
              2'b00: teller_count <= teller_count + 1;
              default: ;
            endcase
          end
          target_start <= 16 - teller_count;
          non_tellers_in_target <= 0;
          for (i = target_start; i < 16; i = i + 1) begin
            if (input_str_reg[2*i +: 2] != 2'b00) non_tellers_in_target <= non_tellers_in_target + 1;
          end
          if (teller_count == 0)
            target_sum <= 0;
          else
            target_sum <= (target_start + 15) * teller_count / 2;
          curr_state <= DONE;
        end

        DONE: begin
          if (cycle_count == 99) begin
            done <= 1;
            if (p1_count + target_sum > p2_count) begin
              min_swaps <= non_tellers_in_target;
              is_impossible <= 0;
            end else begin
              min_swaps <= 0;
              is_impossible <= 1;
            end
            curr_state <= IDLE;
          end else begin
            cycle_count <= cycle_count + 1;
          end
        end

        default: curr_state <= IDLE;
      endcase
    end
  end
endmodule