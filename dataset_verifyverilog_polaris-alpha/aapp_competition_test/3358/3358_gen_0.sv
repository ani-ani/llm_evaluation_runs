module number_display_processor(
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] input_num,
  output reg [7:0] display_out,
  output reg done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    FETCH   = 2'b01,
    EXECUTE = 2'b10,
    DONE    = 2'b11
  } state_t;

  state_t state, next_state;

  // Registers A, X, Y (initialized to X on reset via 'x assignment)
  reg [7:0] A_reg;
  reg [7:0] X_reg;
  reg [7:0] Y_reg;

  // Stack: 40 x 8-bit and stack pointer
  reg [7:0] stack_mem [0:39];
  reg [5:0] sp; // needs to represent 0..40

  // Simple program counter and instruction register
  reg [5:0] pc;
  reg [7:0] ir;

  // Opcodes definition (example mapping)
  localparam [7:0]
    OP_PH_A  = 8'h10,
    OP_PH_X  = 8'h11,
    OP_PH_Y  = 8'h12,
    OP_PL_A  = 8'h20,
    OP_PL_X  = 8'h21,
    OP_PL_Y  = 8'h22,
    OP_AD    = 8'h30,
    OP_ZE_A  = 8'h40,
    OP_ZE_X  = 8'h41,
    OP_ZE_Y  = 8'h42,
    OP_ST_A  = 8'h50,
    OP_ST_X  = 8'h51,
    OP_ST_Y  = 8'h52,
    OP_DI_A  = 8'h60,
    OP_DI_X  = 8'h61,
    OP_DI_Y  = 8'h62,
    OP_DI_IN = 8'h63;

  // Fixed instruction sequence (example) using all instruction types
  // Program:
  //  0: ZE_A      ; A = 0
  //  1: ST_A      ; push A
  //  2: PH_A      ; push A
  //  3: ZE_X      ; X = 0
  //  4: ST_X      ; push X
  //  5: PH_X      ; push X
  //  6: ZE_Y      ; Y = 0
  //  7: ST_Y      ; push Y
  //  8: PH_Y      ; push Y
  //  9: AD        ; add top two stack values
  // 10: DI_IN     ; display input_num
  // 11: DI_A      ; display A (demonstrate multiple DI capability)
  // 12: DI_X      ; display X
  // 13: DI_Y      ; display Y
  // 14: (implicit end: if fetched value is not recognized, treat as DI_IN)

  function automatic [7:0] instr_rom(input [5:0] addr);
    case (addr)
      6'd0:  instr_rom = OP_ZE_A;
      6'd1:  instr_rom = OP_ST_A;
      6'd2:  instr_rom = OP_PH_A;
      6'd3:  instr_rom = OP_ZE_X;
      6'd4:  instr_rom = OP_ST_X;
      6'd5:  instr_rom = OP_PH_X;
      6'd6:  instr_rom = OP_ZE_Y;
      6'd7:  instr_rom = OP_ST_Y;
      6'd8:  instr_rom = OP_PH_Y;
      6'd9:  instr_rom = OP_AD;
      6'd10: instr_rom = OP_DI_IN;
      6'd11: instr_rom = OP_DI_A;
      6'd12: instr_rom = OP_DI_X;
      6'd13: instr_rom = OP_DI_Y;
      default: instr_rom = OP_DI_IN; // default to DI on overflow
    endcase
  endfunction

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = FETCH;
      end
      FETCH: begin
        next_state = EXECUTE;
      end
      EXECUTE: begin
        // Transition to DONE handled in sequential logic via done flag
        if (done)
          next_state = DONE;
        else
          next_state = FETCH;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      A_reg       <= 8'hxx;
      X_reg       <= 8'hxx;
      Y_reg       <= 8'hxx;
      sp          <= 6'd0;
      pc          <= 6'd0;
      ir          <= 8'h00;
      display_out <= 8'h00;
      done        <= 1'b0;
      for (i = 0; i < 40; i = i + 1) begin
        stack_mem[i] <= 8'h00;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            pc <= 6'd0;
          end
        end

        FETCH: begin
          // Fetch next instruction
          ir <= instr_rom(pc);
        end

        EXECUTE: begin
          // Default: not done yet
          done <= 1'b0;

          // Execute current instruction in ir
          unique case (ir)
            // Push high-level registers onto stack (PH)
            OP_PH_A: begin
              if (sp < 40) begin
                stack_mem[sp] <= A_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end
            OP_PH_X: begin
              if (sp < 40) begin
                stack_mem[sp] <= X_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end
            OP_PH_Y: begin
              if (sp < 40) begin
                stack_mem[sp] <= Y_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end

            // Pull from stack into registers (PL) with underflow handling
            OP_PL_A: begin
              if (sp == 0) begin
                done        <= 1'b1;
                display_out <= 8'h00;
              end else begin
                sp    <= sp - 1'b1;
                A_reg <= stack_mem[sp - 1'b1];
                pc    <= pc + 1'b1;
              end
            end
            OP_PL_X: begin
              if (sp == 0) begin
                done        <= 1'b1;
                display_out <= 8'h00;
              end else begin
                sp    <= sp - 1'b1;
                X_reg <= stack_mem[sp - 1'b1];
                pc    <= pc + 1'b1;
              end
            end
            OP_PL_Y: begin
              if (sp == 0) begin
                done        <= 1'b1;
                display_out <= 8'h00;
              end else begin
                sp    <= sp - 1'b1;
                Y_reg <= stack_mem[sp - 1'b1];
                pc    <= pc + 1'b1;
              end
            end

            // AD: add top two stack elements modulo 256
            OP_AD: begin
              if (sp >= 2) begin
                stack_mem[sp - 2] <= stack_mem[sp - 1] + stack_mem[sp - 2];
                sp <= sp - 1'b1;
                pc <= pc + 1'b1;
              end else begin
                // Underflow: treat as termination
                done        <= 1'b1;
                display_out <= 8'h00;
              end
            end

            // ZE: zero registers
            OP_ZE_A: begin
              A_reg <= 8'h00;
              pc    <= pc + 1'b1;
            end
            OP_ZE_X: begin
              X_reg <= 8'h00;
              pc    <= pc + 1'b1;
            end
            OP_ZE_Y: begin
              Y_reg <= 8'h00;
              pc    <= pc + 1'b1;
            end

            // ST: store registers onto stack
            OP_ST_A: begin
              if (sp < 40) begin
                stack_mem[sp] <= A_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end
            OP_ST_X: begin
              if (sp < 40) begin
                stack_mem[sp] <= X_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end
            OP_ST_Y: begin
              if (sp < 40) begin
                stack_mem[sp] <= Y_reg;
                sp <= sp + 1'b1;
              end
              pc <= pc + 1'b1;
            end

            // DI: display and terminate
            OP_DI_A: begin
              display_out <= A_reg;
              done        <= 1'b1;
            end
            OP_DI_X: begin
              display_out <= X_reg;
              done        <= 1'b1;
            end
            OP_DI_Y: begin
              display_out <= Y_reg;
              done        <= 1'b1;
            end
            OP_DI_IN: begin
              display_out <= input_num;
              done        <= 1'b1;
            end

            // Default: treat any undefined opcode as DI_IN termination
            default: begin
              display_out <= input_num;
              done        <= 1'b1;
            end
          endcase
        end

        DONE: begin
          // Hold outputs stable until start goes low and FSM returns to IDLE
          done <= 1'b1;
        end

        default: begin
          // Safety fallback
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule
