module reverse_pair_counter (
  input clk,
  input rst_n,
  input start,
  input [7:0][7:0] strings[8],
  input [2:0] n_strings,
  output reg [4:0] count,
  output reg done
);

typedef enum logic [1:0] {
  IDLE,
  COMPARING,
  DONE
} state_t;

state_t state;
reg [2:0] current_i, current_j;

wire [7:0][7:0] reversed_string_i;
genvar k;
generate
  for (k = 0; k < 8; k++) begin : gen_rev
    assign reversed_string_i[k] = strings[current_i][7 - k];
  end
endgenerate

wire strings_equal = (reversed_string_i == strings[current_j]);

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    count <= 0;
    done <= 0;
    current_i <= 0;
    current_j <= 1;
  end else begin
    done <= 0;
    case (state)
      IDLE: begin
        if (start) begin
          state <= COMPARING;
          count <= 0;
          current_i <= 0;
          current_j <= 1;
        end
      end

      COMPARING: begin
        if (strings_equal) count <= count + 1;

        logic [2:0] next_i, next_j;
        if (current_j < (n_strings - 1)) begin
          next_i = current_i;
          next_j = current_j + 1;
        end else begin
          next_i = current_i + 1;
          next_j = next_i + 1;
        end

        current_i <= next_i;
        current_j <= next_j;

        if (next_i >= (n_strings - 1)) state <= DONE;
        else state <= COMPARING;
      end

      DONE: begin
        done <= 1;
        state <= IDLE;
      end

      default: state <= IDLE;
    endcase
  end
end

endmodule
