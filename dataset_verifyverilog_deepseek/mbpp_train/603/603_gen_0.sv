module ludic_numbers (
  input clk,
  input rst_n,
  input start,
  input [5:0] n,
  output reg [5:0] out_value,
  output reg valid,
  output reg done
);

  typedef enum logic [2:0] {
    IDLE,
    INIT,
    PROCESSING,
    OUTPUT,
    DONE
  } state_t;

  state_t state, state_next;
  logic proc_substate, proc_substate_next;
  reg [63:0] status_flags, status_flags_next;
  reg [5:0] current_base_reg, current_base_reg_next;
  reg [5:0] pos, pos_next;
  reg [5:0] count, count_next;
  reg [5:0] output_counter, output_counter_next;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      status_flags <= '0;
      current_base_reg <= '0;
      pos <= '0;
      count <= '0;
      output_counter <= '0;
      proc_substate <= 0;
      out_value <= '0;
      valid <= '0;
      done <= '0;
    end else begin
      state <= state_next;
      status_flags <= status_flags_next;
      current_base_reg <= current_base_reg_next;
      pos <= pos_next;
      count <= count_next;
      output_counter <= output_counter_next;
      proc_substate <= proc_substate_next;
      out_value <= (state_next == DONE) ? '0 :
                   (state_next == OUTPUT) ? output_counter_next : '0;

      valid <= (state_next == OUTPUT) ? status_flags_next[output_counter_next-1] : '0;
      done <= (state_next == DONE);
    end
  end

  always_comb begin
    state_next = state;
    status_flags_next = status_flags;
    current_base_reg_next = current_base_reg;
    pos_next = pos;
    count_next = count;
    output_counter_next = output_counter;
    proc_substate_next = proc_substate;

    unique case (state)
      IDLE: begin
        if (start) begin
          state_next = INIT;
        end
      end

      INIT: begin
        status_flags_next = '0;
        for (int i=0; i<64; i++) begin
          status_flags_next[i] = (i < n) ? 1'b1 : 1'b0;
        end
        current_base_reg_next = 6'd1;
        proc_substate_next = 0;
        state_next = PROCESSING;
      end

      PROCESSING: begin
        case (proc_substate)
          1'b0: begin
            if (current_base_reg > n) begin
              state_next = OUTPUT;
              output_counter_next = 6'd1;
            end else if (status_flags[current_base_reg-1]) begin
              pos_next = current_base_reg + 6'd1;
              count_next = 6'd0;
              proc_substate_next = 1'b1;
            end else begin
              current_base_reg_next = current_base_reg + 6'd1;
            end
          end
          1'b1: begin
            if (pos > n) begin
              proc_substate_next = 1'b0;
              current_base_reg_next = current_base_reg + 6'd1;
            end else begin
              if (status_flags[pos-1]) begin
                count_next = count + 6'd1;
                if (count + 6'd1 == current_base_reg) begin
                  status_flags_next[pos-1] = 1'b0;
                  count_next = 6'd0;
                end
              end
              pos_next = pos + 6'd1;
            end
          end
        endcase
      end

      OUTPUT: begin
        if (output_counter <= n) begin
          output_counter_next = output_counter + 6'd1;
        end else begin
          state_next = DONE;
        end
      end

      DONE: begin
        state_next = IDLE;
      end

      default: state_next = IDLE;
    endcase
  end

endmodule