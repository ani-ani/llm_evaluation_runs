module permutation_generator (
  input clk,
  input rst_n,
  input start,
  input [9:0] N,
  input [5:0] A,
  input [5:0] B,
  output reg [9:0] data_out,
  output reg valid_out,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    SETUP,
    OUTPUT_BLOCK,
    NEXT_BLOCK
  } state_t;

  state_t state;
  reg [9:0] current_val;
  reg [5:0] group_index;
  reg [9:0] block_size;
  reg [9:0] block_counter;
  reg [9:0] rem;
  reg [9:0] base;
  reg [5:0] rem_count;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      data_out <= 0;
      valid_out <= 0;
      done <= 0;
      current_val <= 0;
      group_index <= 0;
      block_size <= 0;
      block_counter <= 0;
      rem <= 0;
      base <= 0;
      rem_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= SETUP;
          end
        end
        SETUP: begin
          rem <= N - A;
          base <= (B > 1) ? rem / (B - 1) : 0;
          rem_count <= (B > 1) ? rem % (B - 1) : 0;
          current_val <= N;
          group_index <= 0;
          state <= OUTPUT_BLOCK;
        end
        OUTPUT_BLOCK: begin
          if (group_index < B - 1) begin
            block_size <= base + (group_index < rem_count ? 1 : 0);
          end else begin
            block_size <= A;
          end
          block_counter <= 0;
          state <= NEXT_BLOCK;
        end
        NEXT_BLOCK: begin
          if (block_counter < block_size - 1) begin
            block_counter <= block_counter + 1;
            if (group_index < B - 1) begin
              current_val <= current_val - 1;
            end
          end else begin
            if (group_index < B - 1) begin
              current_val <= current_val - block_size;
            end
            group_index <= group_index + 1;
            if (group_index < B) begin
              state <= OUTPUT_BLOCK;
            end else begin
              state <= IDLE;
              done <= 1;
            end
          end
        end
      endcase
    end
  end

  always @(*) begin
    valid_out = 0;
    data_out = 0;
    case (state)
      OUTPUT_BLOCK: begin
        if (group_index < B - 1) begin
          data_out = current_val - block_counter;
        end else begin
          data_out = block_counter + 1;
        end
        valid_out = 1;
      end
      NEXT_BLOCK: begin
        if (block_counter < block_size - 1) begin
          if (group_index < B - 1) begin
            data_out = current_val - block_counter - 1;
          end else begin
            data_out = block_counter + 2;
          end
          valid_out = 1;
        end
      end
    endcase
  end

endmodule