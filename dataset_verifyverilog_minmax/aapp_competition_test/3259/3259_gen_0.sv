module alien_box_controller(
  input clk, // clock
  input rst_n, // active-low reset
  input input_valid, // high when new input available
  input query_type, // 1: update operation, 0: sum query
  input [3:0] L, // box start (1-16)
  input [3:0] R, // box end (1-16, L <= R)
  input [9:0] A, // parameter (1-1023)
  input [9:0] B, // modulus (1-1023)
  output reg output_valid, // high when result ready
  output reg [14:0] sum_out // result for type 2 queries
);

  // State machine states
  localparam IDLE = 3'b000;
  localparam CALC_OFFSET = 3'b001;
  localparam UPDATE_BOX = 3'b010;
  localparam ACCUMULATE = 3'b011;
  localparam DONE = 3'b100;

  // Internal registers
  reg [2:0] state, next_state;
  reg [3:0] L_reg, R_reg, current_index;
  reg [9:0] A_reg, B_reg;
  reg query_type_reg;
  reg [14:0] sum_reg;
  reg [9:0] boxes [0:15];
  integer i;

  // Combinational logic for next state
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (input_valid) 
          next_state = CALC_OFFSET;
      end
      CALC_OFFSET: begin
        if (query_type_reg) begin
          if (L_reg + 1 > R_reg) 
            next_state = DONE;
          else
            next_state = UPDATE_BOX;
        end else begin
          if (L_reg + 1 > R_reg) 
            next_state = DONE;
          else
            next_state = ACCUMULATE;
        end
      end
      UPDATE_BOX: begin
        if (current_index == R_reg) 
          next_state = DONE;
        else
          next_state = UPDATE_BOX;
      end
      ACCUMULATE: begin
        if (current_index == R_reg) 
          next_state = DONE;
        else
          next_state = ACCUMULATE;
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      for (i = 0; i < 16; i = i + 1) begin
        boxes[i] <= 10'd0;
      end
      L_reg <= 0;
      R_reg <= 0;
      A_reg <= 0;
      B_reg <= 0;
      query_type_reg <= 0;
      current_index <= 0;
      sum_reg <= 0;
      sum_out <= 0;
      output_valid <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (input_valid) begin
            L_reg <= L;
            R_reg <= R;
            A_reg <= A;
            B_reg <= B;
            query_type_reg <= query_type;
            current_index <= L;
          end
        end
        
        CALC_OFFSET: begin
          if (query_type_reg) begin
            // Update first box: offset = 1
            reg [4:0] offset = 1;
            reg [14:0] temp = offset * A_reg;
            reg [9:0] new_value = temp % B_reg;
            boxes[L_reg] <= new_value;
            current_index <= L_reg + 1;
          end else begin
            // Sum first box
            sum_reg <= boxes[L_reg];
            current_index <= L_reg + 1;
          end
        end
        
        UPDATE_BOX: begin
          // Calculate new value for current box
          reg [4:0] offset = current_index - L_reg + 1;
          reg [14:0] temp = offset * A_reg;
          reg [9:0] new_value = temp % B_reg;
          boxes[current_index] <= new_value;
          current_index <= current_index + 1;
        end
        
        ACCUMULATE: begin
          sum_reg <= sum_reg + boxes[current_index];
          current_index <= current_index + 1;
        end
        
        DONE: begin
          output_valid <= 1;
          if (query_type_reg == 0) begin
            sum_out <= sum_reg;
          end else begin
            sum_out <= 0;
          end
        end
      endcase
    end
  end
endmodule