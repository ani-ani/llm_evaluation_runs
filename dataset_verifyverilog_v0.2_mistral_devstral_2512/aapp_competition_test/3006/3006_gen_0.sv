module dna_program_comparator (
  input clk,
  input rst_n,
  input start,
  input [7:0] op_type,
  input [15:0] op_pos,
  input [7:0] op_char,
  input program_sel,
  output reg result,
  output reg done,
  output reg error
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    READ_OPS1,
    READ_OPS2,
    SIMPLIFY1,
    SIMPLIFY2,
    COMPARE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Operation buffers for program 1
  reg [7:0] op1_type [0:7];
  reg [15:0] op1_pos [0:7];
  reg [7:0] op1_char [0:7];
  reg [2:0] op1_count = 0;

  // Operation buffers for program 2
  reg [7:0] op2_type [0:7];
  reg [15:0] op2_pos [0:7];
  reg [7:0] op2_char [0:7];
  reg [2:0] op2_count = 0;

  // Temporary storage for simplification
  reg [7:0] temp_type [0:7];
  reg [15:0] temp_pos [0:7];
  reg [7:0] temp_char [0:7];
  reg [2:0] temp_count = 0;

  // Flags
  reg program1_done = 0;
  reg program2_done = 0;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      result <= 0;
      done <= 0;
      error <= 0;
      program1_done <= 0;
      program2_done <= 0;
      op1_count <= 0;
      op2_count <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          if (program_sel == 0)
            next_state = READ_OPS1;
          else
            next_state = READ_OPS2;
        end
      end
      READ_OPS1: begin
        if (op_type == 3) begin
          program1_done = 1;
          next_state = SIMPLIFY1;
        end
      end
      READ_OPS2: begin
        if (op_type == 3) begin
          program2_done = 1;
          next_state = SIMPLIFY2;
        end
      end
      SIMPLIFY1: begin
        next_state = (program2_done) ? COMPARE : READ_OPS2;
      end
      SIMPLIFY2: begin
        next_state = COMPARE;
      end
      COMPARE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
          result <= 0;
          done <= 0;
          error <= 0;
          program1_done <= 0;
          program2_done <= 0;
          op1_count <= 0;
          op2_count <= 0;
        end
      end
    endcase
  end

  // Operation storage
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (current_state)
        READ_OPS1: begin
          if (op_type != 0 && op_type != 3) begin
            // Store operation for program 1
            if (op1_count < 8) begin
              op1_type[op1_count] <= op_type;
              op1_pos[op1_count] <= op_pos;
              op1_char[op1_count] <= op_char;
              op1_count <= op1_count + 1;
            end else begin
              error <= 1;
            end
          end
        end
        READ_OPS2: begin
          if (op_type != 0 && op_type != 3) begin
            // Store operation for program 2
            if (op2_count < 8) begin
              op2_type[op2_count] <= op_type;
              op2_pos[op2_count] <= op_pos;
              op2_char[op2_count] <= op_char;
              op2_count <= op2_count + 1;
            end else begin
              error <= 1;
            end
          end
        end
      endcase
    end
  end

  // Simplification logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == SIMPLIFY1) begin
      // Simplify program 1 operations
      temp_count = 0;
      for (int i = 0; i < op1_count; i++) begin
        if (temp_count == 0) begin
          // First operation, just store
          temp_type[temp_count] = op1_type[i];
          temp_pos[temp_count] = op1_pos[i];
          temp_char[temp_count] = op1_char[i];
          temp_count = temp_count + 1;
        end else begin
          // Check for cancellation
          if (temp_type[temp_count-1] == 1 && op1_type[i] == 2 && 
              temp_pos[temp_count-1] == op1_pos[i]) begin
            // Cancel insert-delete pair
            temp_count = temp_count - 1;
          end else if (temp_type[temp_count-1] == 2 && op1_type[i] == 2 && 
                       op1_pos[i] > temp_pos[temp_count-1]) begin
            // Adjust delete position
            temp_pos[temp_count] = op1_pos[i] - 1;
            temp_type[temp_count] = op1_type[i];
            temp_char[temp_count] = op1_char[i];
            temp_count = temp_count + 1;
          end else begin
            // Store operation
            temp_type[temp_count] = op1_type[i];
            temp_pos[temp_count] = op1_pos[i];
            temp_char[temp_count] = op1_char[i];
            temp_count = temp_count + 1;
          end
        end
      end
      // Copy back to op1 buffers
      op1_count = temp_count;
      for (int i = 0; i < temp_count; i++) begin
        op1_type[i] = temp_type[i];
        op1_pos[i] = temp_pos[i];
        op1_char[i] = temp_char[i];
      end
    end else if (current_state == SIMPLIFY2) begin
      // Simplify program 2 operations
      temp_count = 0;
      for (int i = 0; i < op2_count; i++) begin
        if (temp_count == 0) begin
          // First operation, just store
          temp_type[temp_count] = op2_type[i];
          temp_pos[temp_count] = op2_pos[i];
          temp_char[temp_count] = op2_char[i];
          temp_count = temp_count + 1;
        end else begin
          // Check for cancellation
          if (temp_type[temp_count-1] == 1 && op2_type[i] == 2 && 
              temp_pos[temp_count-1] == op2_pos[i]) begin
            // Cancel insert-delete pair
            temp_count = temp_count - 1;
          end else if (temp_type[temp_count-1] == 2 && op2_type[i] == 2 && 
                       op2_pos[i] > temp_pos[temp_count-1]) begin
            // Adjust delete position
            temp_pos[temp_count] = op2_pos[i] - 1;
            temp_type[temp_count] = op2_type[i];
            temp_char[temp_count] = op2_char[i];
            temp_count = temp_count + 1;
          end else begin
            // Store operation
            temp_type[temp_count] = op2_type[i];
            temp_pos[temp_count] = op2_pos[i];
            temp_char[temp_count] = op2_char[i];
            temp_count = temp_count + 1;
          end
        end
      end
      // Copy back to op2 buffers
      op2_count = temp_count;
      for (int i = 0; i < temp_count; i++) begin
        op2_type[i] = temp_type[i];
        op2_pos[i] = temp_pos[i];
        op2_char[i] = temp_char[i];
      end
    end
  end

  // Comparison logic
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else if (current_state == COMPARE) begin
      if (op1_count != op2_count) begin
        result <= 1;
      end else begin
        result <= 0;
        for (int i = 0; i < op1_count; i++) begin
          if (op1_type[i] != op2_type[i] || 
              op1_pos[i] != op2_pos[i] || 
              op1_char[i] != op2_char[i]) begin
            result <= 1;
          end
        end
      end
      done <= 1;
    end
  end

endmodule