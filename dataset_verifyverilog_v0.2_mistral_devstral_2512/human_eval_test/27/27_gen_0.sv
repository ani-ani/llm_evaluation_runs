module flip_case (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  input [3:0] char_index,
  input valid_in,
  output reg [7:0] char_out,
  output reg [3:0] char_index_out,
  output reg valid_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [3:0] current_index;
  reg [7:0] char_buffer;
  reg char_valid;
  reg [1:0] cycle_count;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 0;
      char_buffer <= 0;
      char_valid <= 0;
      cycle_count <= 0;
    end else begin
      state <= next_state;
      if (state == PROCESSING && valid_in) begin
        current_index <= char_index;
        char_buffer <= char_in;
        char_valid <= 1'b1;
      end
      if (state == PROCESSING && cycle_count == 2'b11) begin
        cycle_count <= 0;
      end else if (state == PROCESSING && char_valid) begin
        cycle_count <= cycle_count + 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (current_index == 15 && cycle_count == 2'b11) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Output logic
  always @(*) begin
    char_out = 8'b0;
    char_index_out = 4'b0;
    valid_out = 1'b0;
    done = 1'b0;

    case (state)
      IDLE: begin
        char_out = 8'b0;
        char_index_out = 4'b0;
        valid_out = 1'b0;
        done = 1'b0;
      end
      PROCESSING: begin
        if (cycle_count == 2'b10) begin
          if (char_buffer >= 8'h41 && char_buffer <= 8'h5A) begin
            char_out = char_buffer ^ 8'h20;
          end else if (char_buffer >= 8'h61 && char_buffer <= 8'h7A) begin
            char_out = char_buffer ^ 8'h20;
          end else begin
            char_out = char_buffer;
          end
          char_index_out = current_index;
          valid_out = 1'b1;
        end
        done = 1'b0;
      end
      DONE: begin
        char_out = 8'b0;
        char_index_out = 4'b0;
        valid_out = 1'b0;
        done = 1'b1;
      end
    endcase
  end

endmodule