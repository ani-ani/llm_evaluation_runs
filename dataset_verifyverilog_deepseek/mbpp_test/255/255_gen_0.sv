module combination_generator (
  input clk,
  input rst_n,
  input [1:0] combo_len,
  input start,
  output reg [5:0] current_combo,
  output reg [3:0] combo_count,
  output reg done
);

typedef enum logic [1:0] {IDLE, RUN, DONE} state_t;
state_t state;

reg [1:0] combo_len_reg;

function automatic logic is_last_combo(input [1:0] len, input [5:0] combo);
  case(len)
    2'd1: return (combo[1:0] == 2'b10);
    2'd2: return (combo[3:0] == 4'b1010);
    2'd3: return (combo == 6'b101010);
    default: return 1'b0;
  endcase
endfunction

function automatic [5:0] next_combo(input [1:0] len, input [5:0] current);
  logic [5:0] next;
  next = current;
  case(len)
    2'd1: if (current[1:0] < 2'b10) next[1:0] = current[1:0] + 1;
    2'd2: begin
      logic [1:0] elem1 = current[3:2];
      logic [1:0] elem0 = current[1:0];
      if (elem0 < 2'b10) begin
        next[1:0] = elem0 + 1;
      end else if (elem1 < 2'b10) begin
        next[3:2] = elem1 + 1;
        next[1:0] = next[3:2];
      end
    end
    2'd3: begin
      logic [1:0] elem2 = current[5:4];
      logic [1:0] elem1 = current[3:2];
      logic [1:0] elem0 = current[1:0];
      if (elem0 < 2'b10) begin
        next[1:0] = elem0 + 1;
      end else if (elem1 < 2'b10) begin
        next[3:2] = elem1 + 1;
        next[1:0] = next[3:2];
      end else if (elem2 < 2'b10) begin
        next[5:4] = elem2 + 1;
        next[3:2] = next[5:4];
        next[1:0] = next[5:4];
      end
    end
  endcase
  return next;
endfunction

wire is_last = is_last_combo(combo_len_reg, current_combo);
wire [5:0] next_comboval = next_combo(combo_len_reg, current_combo);

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    current_combo <= 6'b0;
    combo_count <= 4'b0;
    done <= 1'b0;
    combo_len_reg <= 2'b0;
  end else begin
    case(state)
      IDLE: begin
        done <= 1'b0;
        if (start) begin
          combo_len_reg <= combo_len;
          current_combo <= 6'b0;
          combo_count <= 4'd1;
          state <= RUN;
        end
      end
      
      RUN: begin
        if (is_last) begin
          state <= DONE;
        end else begin
          current_combo <= next_comboval;
          combo_count <= combo_count + 4'd1;
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