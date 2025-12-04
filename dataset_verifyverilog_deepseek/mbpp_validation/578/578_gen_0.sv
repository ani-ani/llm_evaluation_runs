module list_interleaver (
  input clk,
  input rst_n,
  input start,
  input [2:0] list_len,
  input [7:0][15:0] list1,
  input [7:0][15:0] list2,
  input [7:0][15:0] list3,
  output reg [15:0] data_out,
  output reg valid,
  output reg done
);

  enum logic [1:0] {IDLE, PROCESSING, DONE} state, next_state;
  reg [2:0] len_reg;
  reg [7:0][15:0] list1_reg, list2_reg, list3_reg;
  reg [2:0] current_index;
  reg [1:0] step_counter;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 1'b0;
      done <= 1'b0;
      data_out <= 16'b0;
      len_reg <= 3'b0;
      current_index <= 3'b0;
      step_counter <= 2'b0;
      list1_reg <= 0;
      list2_reg <= 0;
      list3_reg <= 0;
    end else begin
      state <= next_state;
      done <= 1'b0;
      case(state)
        IDLE: begin
          valid <= 1'b0;
          if (start) begin
            len_reg <= list_len;
            list1_reg <= list1;
            list2_reg <= list2;
            list3_reg <= list3;
          end
        end
        PROCESSING: begin
          valid <= 1'b1;
          case(step_counter)
            2'b00: data_out <= list1_reg[current_index];
            2'b01: data_out <= list2_reg[current_index];
            2'b10: data_out <= list3_reg[current_index];
          endcase
          if (step_counter == 2'b10) begin
            step_counter <= 2'b00;
            if (current_index == len_reg - 3'b1) current_index <= 3'b0;
            else current_index <= current_index + 3'b1;
          end else step_counter <= step_counter + 2'b1;
        end
        DONE: done <= 1'b1;
      endcase
    end
  end

  always_comb begin
    unique case(state)
      IDLE: next_state = (start) ? ((list_len == 0) ? DONE : PROCESSING) : IDLE;
      PROCESSING: next_state = ((step_counter == 2'b10) && (current_index == len_reg - 3'b1)) ? DONE : PROCESSING;
      DONE: next_state = IDLE;
    endcase
  end

endmodule