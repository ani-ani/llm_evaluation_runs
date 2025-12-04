module max_removal_score(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] array_in [7:0],
  output reg [18:0] max_score,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE = 3'h0,
    INIT = 3'h1,
    PROCESS = 3'h2,
    FINAL_PROCESS = 3'h3,
    DONE_ST = 3'h4
  } state_t;

  reg [2:0] state, next_state;
  reg [15:0] stack [0:7];
  reg [3:0] sp;
  reg [18:0] score;
  reg [3:0] init_cnt;
  reg [3:0] proc_index;
  reg [15:0] current_element;
  reg [15:0] min_val;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      sp <= 0;
      init_cnt <= 0;
      proc_index <= 0;
      score <= 0;
      done <= 0;
      max_score <= 0;
    end
    else begin
      state <= next_state;

      case (state)
        IDLE: begin
          sp <= 0;
          init_cnt <= 0;
          proc_index <= 0;
          score <= 0;
          done <= 0;
        end

        INIT: begin
          if (init_cnt < n) begin
            stack[sp] <= array_in[init_cnt];
            sp <= sp + 1;
            init_cnt <= init_cnt + 1;
          end
        end

        PROCESS: begin
          if (proc_index < n) begin
            if (sp >= 2) begin
              min_val = (stack[sp-2] <= array_in[proc_index]) ? stack[sp-2] : array_in[proc_index];
              if (stack[sp-1] <= min_val) begin
                sp <= sp - 1;
                score <= score + min_val;
              end
              else begin
                proc_index <= proc_index + 1;
              end
            end
            else begin
              proc_index <= proc_index + 1;
            end
          end
        end

        FINAL_PROCESS: begin
          if (sp >= 2) begin
            min_val = (stack[sp-2] <= stack[sp-1]) ? stack[sp-2] : stack[sp-1];
            score <= score + min_val;
            sp <= sp - 1;
          end
        end

        DONE_ST: begin
          done <= 1;
          max_score <= score;
        end

      endcase
    end
  end

  always_comb begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start) next_state = INIT;
      end

      INIT: begin
        if (init_cnt >= n) next_state = PROCESS;
      end

      PROCESS: begin
        if (proc_index >= n) begin
          next_state = FINAL_PROCESS;
        end
        else if (sp >= 2 && (stack[sp-1] <= ((stack[sp-2] <= array_in[proc_index]) ? stack[sp-2] : array_in[proc_index]))) begin
          next_state = PROCESS;
        end
        else if (proc_index < n) begin
          next_state = PROCESS;
        end
      end

      FINAL_PROCESS: begin
        if (sp < 2) next_state = DONE_ST;
        else next_state = FINAL_PROCESS;
      end

      DONE_ST: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule