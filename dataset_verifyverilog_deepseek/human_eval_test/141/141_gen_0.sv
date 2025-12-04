module file_name_checker (
  input clk,
  input rst_n,
  input start,
  input [127:0] file_name,
  output reg valid,
  output reg done
);

  typedef enum logic [1:0] { IDLE, PROCESSING, DONE } state_t;
  state_t state, next_state;

  reg [3:0] index;
  reg [1:0] dot_count;
  reg [4:0] digit_count;
  reg [3:0] dot_position;
  reg multi_dot_error;
  reg prefix_valid;

  wire [7:0] current_char = file_name[index*8 +:8];

  wire [23:0] suffix = {file_name[111:104], file_name[119:112], file_name[127:120]};
  wire suffix_match = (suffix == 24'h747478) || 
                      (suffix == 24'h657865) ||
                      (suffix == 24'h646C6C);

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      valid <= 0;
      done <= 0;
      dot_count <= 0;
      digit_count <= 0;
      multi_dot_error <= 0;
      dot_position <= 0;
      index <= 0;
      prefix_valid <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          valid <= 0;
          if (start) begin
            state <= PROCESSING;
            dot_count <= 0;
            digit_count <= 0;
            multi_dot_error <= 0;
            dot_position <= 0;
            index <= 0;
            prefix_valid <= (file_name[7:0] inside {[8'h41:8'h5A], [8'h61:8'h7A]});
          end
        end

        PROCESSING: begin
          if (current_char == 8'h2E) begin
            dot_count <= dot_count + 1;
            if (dot_count == 0) begin
              dot_position <= index;
            end else begin
              multi_dot_error <= 1;
            end
          end

          if (current_char inside {[8'h30:8'h39]}) begin
            digit_count <= digit_count + 1;
          end

          if (index == 15) begin
            state <= DONE;
          end else begin
            index <= index + 1;
          end
        end

        DONE: begin
          valid <= !multi_dot_error && (dot_count == 1) && (dot_position == 4'd12) &&
                   prefix_valid && (digit_count <= 3) && suffix_match;
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

  always_comb begin
    next_state = state;
    case (state)
      IDLE: if (start) next_state = PROCESSING;
      PROCESSING: if (index == 15) next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule