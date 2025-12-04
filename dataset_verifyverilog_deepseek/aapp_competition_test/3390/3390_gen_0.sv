module longest_menu_path(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [63:0] adjacency,
  output reg [3:0] max_path_length,
  output reg done
);

typedef enum logic [1:0] { IDLE, INIT, SEARCH, DONE } state_t;

typedef struct packed {
  logic [7:0] visited;
  logic [3:0] length;
  logic [3:0] node;
} stack_entry_t;

stack_entry_t stack [0:7];
state_t state;
reg [2:0] stack_ptr;
reg [2:0] init_counter;
reg [3:0] neighbor_counter;
reg processing;
stack_entry_t current_entry;
reg start_reg;
wire start_pulse;

assign start_pulse = start & ~start_reg;

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    start_reg <= 0;
    max_path_length <= 0;
    done <= 0;
    stack_ptr <= 0;
    init_counter <= 0;
    neighbor_counter <= 0;
    processing <= 0;
    current_entry <= '{default:0};
    stack <= '{default:0};
  end else begin
    start_reg <= start;
    case (state)
      IDLE: begin
        done <= 0;
        max_path_length <= 0;
        if (start_pulse) begin
          state <= INIT;
          init_counter <= 0;
        end
      end
      INIT: begin
        if (init_counter <= n) begin
          stack[stack_ptr].visited <= 1 << init_counter[2:0];
          stack[stack_ptr].length <= 4'd1;
          stack[stack_ptr].node <= init_counter[2:0];
          stack_ptr <= stack_ptr + 1;
          init_counter <= init_counter + 1;
        end else begin
          state <= SEARCH;
        end
      end
      SEARCH: begin
        if (processing) begin
          if (neighbor_counter <= n) begin
            if (adjacency[current_entry.node * 8 + neighbor_counter] && 
                !current_entry.visited[neighbor_counter] && 
                neighbor_counter <= n) begin
              if (stack_ptr < 8) begin
                stack[stack_ptr].visited <= current_entry.visited | (1 << neighbor_counter);
                stack[stack_ptr].node <= neighbor_counter;
                stack[stack_ptr].length <= current_entry.length + 1;
                stack_ptr <= stack_ptr + 1;
              end
            end
            neighbor_counter <= neighbor_counter + 1;
          end else begin
            processing <= 0;
          end
        end else begin
          if (stack_ptr > 0) begin
            stack_ptr <= stack_ptr - 1;
            current_entry <= stack[stack_ptr - 1];
            if (stack[stack_ptr - 1].length > max_path_length) begin
              max_path_length <= stack[stack_ptr - 1].length;
            end
            neighbor_counter <= 0;
            processing <= 1;
          end else begin
            state <= DONE;
            done <= 1;
          end
        end
      end
      DONE: begin
        if (start_pulse) begin
          state <= IDLE;
        end
      end
      default: begin
        state <= IDLE;
      end
    endcase
  end
end

endmodule