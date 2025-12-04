module list_packer(
  input clk,
  input rst_n,
  input start,
  input [15:0][7:0] data_in,
  input [3:0] length_in,
  output reg [3:0] group_count,
  output reg [15:0][3:0] start_indices,
  output reg [15:0][3:0] group_lengths,
  output reg done
);

  typedef enum {IDLE, PROCESSING, DONE} state_t;
  state_t state;

  reg [3:0] current_index;
  reg [3:0] current_group_start;
  reg [3:0] current_group_length;
  reg [3:0] group_count_reg;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 4'd0;
      current_group_start <= 4'd0;
      current_group_length <= 4'd0;
      group_count_reg <= 4'd0;
      group_count <= 4'd0;
      start_indices <= 64'd0;
      group_lengths <= 64'd0;
      done <= 1'b0;
    end
    else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= PROCESSING;
            current_index <= 4'd1;
            current_group_start <= 4'd0;
            current_group_length <= 4'd1;
            group_count_reg <= 4'd0;
          end
        end

        PROCESSING: begin
          if (current_index < length_in) begin
            if (data_in[current_index] == data_in[current_index - 1]) begin
              current_group_length <= current_group_length + 4'd1;
            end
            else begin
              start_indices[group_count_reg] <= current_group_start;
              group_lengths[group_count_reg] <= current_group_length;
              group_count_reg <= group_count_reg + 4'd1;
              current_group_start <= current_index;
              current_group_length <= 4'd1;
            end
            current_index <= current_index + 4'd1;
          end
          else begin
            if (current_index == length_in) begin
              start_indices[group_count_reg] <= current_group_start;
              group_lengths[group_count_reg] <= current_group_length;
              group_count <= group_count_reg + 4'd1;
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule