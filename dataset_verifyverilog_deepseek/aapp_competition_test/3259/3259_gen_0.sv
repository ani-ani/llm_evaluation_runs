module alien_box_controller(
  input clk, 
  input rst_n, 
  input input_valid, 
  input query_type, 
  input [3:0] L, 
  input [3:0] R, 
  input [9:0] A, 
  input [9:0] B, 
  output reg output_valid, 
  output reg [14:0] sum_out
);

  // State definitions
  localparam IDLE            = 3'b000;
  localparam CALC_OFFSET     = 3'b001;
  localparam UPDATE_BOX      = 3'b010;
  localparam ACCUMULATE      = 3'b011;
  localparam DONE            = 3'b100;

  reg [2:0] current_state, next_state;
  reg [9:0] boxes[0:15];  // Box storage
  reg [3:0] L_reg, R_reg;
  reg [9:0] A_reg, B_reg;
  reg query_type_reg;
  reg [4:0] counter;      // Supports up to 16 cycles (max R-L+1=16)
  reg [3:0] current_box;
  reg [14:0] sum_acc;
  reg [4:0] offset;

  integer i;

  // Sequential state transition
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      output_valid <= 1'b0;
      sum_out <= 15'b0;
      for(i=0; i<16; i=i+1)
        boxes[i] <= 10'b0;
    end else begin
      current_state <= next_state;

      // Control output_valid
      output_valid <= (next_state == DONE);

      case (current_state)
        IDLE: begin
          if (input_valid) begin
            query_type_reg <= query_type;
            L_reg <= L;
            R_reg <= R;
            A_reg <= A;
            B_reg <= B;
          end
        end
        
        CALC_OFFSET: begin
          // Always process first value in this state
          counter <= R_reg - L_reg;
          current_box <= L_reg + 1;
          offset <= 1;
          
          if (query_type_reg) begin  // Type 1
            boxes[L_reg-1] <= (A_reg * 1) % B_reg;
          end else begin            // Type 2
            sum_acc <= boxes[L_reg-1];
          end
        end

        UPDATE_BOX: begin
          offset <= offset + 1;
          boxes[current_box-1] <= (A_reg * offset) % B_reg;
          current_box <= current_box + 1;
          counter <= counter - 1;
        end

        ACCUMULATE: begin
          sum_acc <= sum_acc + boxes[current_box-1];
          current_box <= current_box + 1;
          counter <= counter - 1;
        end

        DONE: begin
          if (!query_type_reg)
            sum_out <= sum_acc;
        end
      endcase
    end
  end

  // Combinational next-state logic
  always @(*) begin
    next_state = current_state;

    case (current_state)
      IDLE:   next_state = input_valid ? CALC_OFFSET : IDLE;

      CALC_OFFSET: begin
        if (counter != 0)                  // If more boxes exist
          next_state = query_type_reg ? UPDATE_BOX : ACCUMULATE;
        else
          next_state = DONE;
      end

      UPDATE_BOX,
      ACCUMULATE: next_state = (counter == 0) ? DONE : current_state;

      DONE: next_state = IDLE;
      
      default: next_state = IDLE;
    endcase
  end

endmodule