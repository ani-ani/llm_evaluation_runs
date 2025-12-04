module harvard_min_instructions(
  input clk,
  input rst_n,
  input start,
  input [3:0] b,
  input [3:0] s,
  input [95:0] program,
  output reg [31:0] min_instructions,
  output reg done
);

typedef enum logic [1:0] {IDLE, PARSE, CALC_COST, DONE} state_t;
state_t state, next_state;

reg [3:0] bank_count;
reg [5:0] tokens [15:0];
reg [3:0] var_list [15:0];
reg [3:0] unique_vars;
reg [3:0] token_count;
reg [3:0] mapping_index;
reg [3:0] token_index;
reg [1:0] current_bank;
reg [31:0] current_cost;
reg [31:0] min_cost;
reg [3:0] var_bank_map [3:0];
reg [1:0] loop_stack [0:3];
reg [1:0] loop_ptr;

function automatic bit [3:0] find_var(input [3:0] value);
  for (int i=0; i<16; i=i+1)
    if (var_list[i] == value) return i;
  return 4'hF;
endfunction

always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 0;
    min_instructions <= 32'hFFFFFFFF;
    bank_count <= 0;
    unique_vars <= 0;
    token_count <= 0;
    mapping_index <= 0;
    token_index <= 0;
    loop_ptr <= 0;
    current_cost <= 0;
    min_cost <= 32'hFFFFFFFF;
    for (int i=0; i<16; i++) var_list[i] <= 4'h0;
  end else begin
    case (state)
      IDLE: begin
        done <= 0;
        min_instructions <= 32'hFFFFFFFF;
        if (start) begin
          state <= PARSE;
          bank_count <= (b > 4) ? 4 : b;
        end
      end
      
      PARSE: begin
        for (int i=0; i<16; i++)
          tokens[i] <= program[i*6 +:6];
        
        unique_vars <= 0;
        token_count <= 0;
        state <= CALC_COST;
      end
      
      CALC_COST: begin
        if (token_index == 16) begin
          if (current_cost < min_cost)
            min_cost <= current_cost;
          
          if (mapping_index == {unique_vars{2'b11}}) begin
            min_instructions <= min_cost;
            state <= DONE;
          end else begin
            mapping_index <= mapping_index + 1;
            token_index <= 0;
          end
          current_cost <= 0;
          current_bank <= 0;
        end else begin
          case (tokens[token_index][5:4])
            2'b00: begin // Variable access
              automatic bit [1:0] target_bank = var_bank_map[find_var(tokens[token_index][3:0])];
              if (target_bank != current_bank) begin
                current_cost <= current_cost + 1;
                current_bank <= target_bank;
              end
              token_index <= token_index + 1;
            end
            
            2'b01: begin // Register access
              automatic bit [1:0] target_bank = 0;
              if (target_bank != current_bank) begin
                current_cost <= current_cost + 1;
                current_bank <= target_bank;
              end
              token_index <= token_index + 1;
            end
            
            2'b10: begin // Loop end
              automatic bit [31:0] loop_cost = current_cost - loop_stack[loop_ptr-1][1];
              current_cost <= current_cost + (loop_cost * (tokens[token_index][3:0] - 1));
              loop_ptr <= loop_ptr - 1;
              token_index <= token_index + 1;
            end
            
            default: token_index <= token_index + 1;
          endcase
        end
      end
      
      DONE: begin
        done <= 1;
        if (!start)
          state <= IDLE;
      end
    endcase
  end
end

always_comb begin
  next_state = state;
  case (state)
    IDLE: if (start) next_state = PARSE;
    PARSE: next_state = CALC_COST;
    CALC_COST: if (token_index == 16 && mapping_index == {unique_vars{2'b11}}) next_state = DONE;
    DONE: if (!start) next_state = IDLE;
  endcase
end

endmodule