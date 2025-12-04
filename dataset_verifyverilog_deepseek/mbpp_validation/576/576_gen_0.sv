module sublist_checker (clk, rst_n, start, array_A, array_B, ENA, ENB, found, done);
  input clk;
  input rst_n;
  input start;
  input [15:0] array_A;
  input [15:0] array_B;
  input [1:0] ENA;
  input [1:0] ENB;
  output reg found;
  output reg done;

  // FSM state encoding
  typedef enum logic [1:0] { IDLE = 2'b00, COMPARING = 2'b01, FINISH = 2'b10 } state_t;
  state_t current_state, next_state;

  reg [3:0] A_reg [0:3];
  reg [3:0] B_reg [0:3];
  reg [1:0] lenA_reg, lenB_reg;
  reg [2:0] index_reg;
  
  reg found_next;
  wire match;

  wire [3:0] A_wire [0:3] = '{array_A[3:0], array_A[7:4], array_A[11:8], array_A[15:12]};
  wire [3:0] B_wire [0:3] = '{array_B[3:0], array_B[7:4], array_B[11:8], array_B[15:12]};

  // Comparison logic
  always_comb begin
    if (lenB_reg == 1)
      match = (B_reg[0] == A_reg[index_reg]);
    else if (lenB_reg == 2)
      match = (B_reg[0] == A_reg[index_reg]) && (B_reg[1] == A_reg[index_reg+1]);
    else if (lenB_reg == 3)
      match = (B_reg[0] == A_reg[index_reg]) && (B_reg[1] == A_reg[index_reg+1]) && (B_reg[2] == A_reg[index_reg+2]);
    else
      match = (B_reg[0] == A_reg[index_reg]) && (B_reg[1] == A_reg[index_reg+1]) && (B_reg[2] == A_reg[index_reg+2]) && (B_reg[3] == A_reg[index_reg+3]);
  end

  // FSM state transition
  always_comb begin
    next_state = current_state;
    found_next = found;
    case (current_state)
      IDLE: if (start) next_state = COMPARING;
      COMPARING: begin
        if (lenB_reg > lenA_reg) begin
          found_next = 1'b0;
          next_state = FINISH;
        end
        else begin
          logic [2:0] len_diff = lenA_reg - lenB_reg;
          if (match) begin
            found_next = 1'b1;
            next_state = FINISH;
          end
          else if (index_reg == len_diff) begin
            found_next = 1'b0;
            next_state = FINISH;
          end
          else begin
            next_state = COMPARING;
          end
        end
      end
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // FSM state register and datapath
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      found <= 1'b0;
      done <= 1'b0;
      index_reg <= 3'd0;
      lenA_reg <= 2'd0;
      lenB_reg <= 2'd0;
      A_reg <= '{4'd0, 4'd0, 4'd0, 4'd0};
      B_reg <= '{4'd0, 4'd0, 4'd0, 4'd0};
    end
    else begin
      current_state <= next_state;
      found <= found_next;
      done <= (next_state == FINISH);

      case (current_state)
        IDLE: if (start) begin
          A_reg <= A_wire;
          B_reg <= B_wire;
          lenA_reg <= ENA + 1'd1;
          lenB_reg <= ENB + 1'd1;
          index_reg <= 3'd0;
        end
        COMPARING: if (next_state == COMPARING) index_reg <= index_reg + 1'd1;
        default: ;
      endcase
    end
  end
endmodule