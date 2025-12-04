module number_display_processor (
  input  logic        clk,
  input  logic        rst_n,
  input  logic        start,
  input  logic [7:0]  input_num,
  output logic [7:0]  display_out,
  output logic        done
);

  // Internal signals and storage
  logic [7:0] reg_A, reg_X, reg_Y;
  logic [7:0] stack [0:39];
  logic [5:0] sp;               // stack pointer (0..40)
  logic [5:0] pc;               // program counter
  logic [7:0] instr;            // current instruction opcode

  // FSM state
  typedef enum logic [1:0] {
    IDLE    = 2'b00,
    FETCH   = 2'b01,
    EXECUTE = 2'b10,
    DONE    = 2'b11
  } fsm_state_t;
  fsm_state_t state, state_next;

  // Instruction decode signals (combinational)
  logic [7:0] out_reg_val;
  logic       reg_wr, out_mux_sel;
  logic       pop_op, push_op, add_op;
  logic       st_op, ze_op, di_op;
  logic       stack_underflow;
  logic       underflow_pulse;
  logic [5:0] sp_next;

  // Instruction encoding (8-bit)
  // 8'b00000rrr: POP   -> Pop to reg r (0:A,1:X,2:Y)
  // 8'b00001rrr: ST    -> Set reg r <- N (input_num)
  // 8'b00010rrr: ZE r  -> Set reg r <- 0
  // 8'b00011rrr: DI r  -> Display reg r (set display_out and done)
  // 8'b10000000: PH    -> Push N (input_num) onto stack (overflow ok, capped at 40)
  // 8'b10000001: PL    -> Pop from stack (sets done on underflow)
  // 8'b10000010: AD    -> (stack[sp-1] + stack[sp-2]) % 256; push; sp -= 1

  // Decode current instruction (combinational)
  always_comb begin
    // Defaults
    pop_op = 1'b0;
    push_op = 1'b0;
    add_op = 1'b0;
    st_op = 1'b0;
    ze_op = 1'b0;
    di_op = 1'b0;
    out_mux_sel = 1'b0;  // 0 -> reg_A, 1 -> reg_X, 2 -> reg_Y (from rrr)
    reg_wr = 1'b0;
    out_reg_val = reg_A;
    sp_next = sp;
    stack_underflow = 1'b0;
    underflow_pulse = 1'b0;

    if (instr[7] == 1'b0) begin
      case (instr[2:0])
        3'b000: begin // POP A
          pop_op = 1'b1;
          out_mux_sel = 2'b00;
          reg_wr = 1'b1;
          out_reg_val = (sp > 0) ? stack[sp-1] : 8'hXX; // don't care if underflow
          sp_next = (sp > 0) ? (sp - 1) : sp;
        end
        3'b001: begin // POP X
          pop_op = 1'b1;
          out_mux_sel = 2'b01;
          reg_wr = 1'b1;
          out_reg_val = (sp > 0) ? stack[sp-1] : 8'hXX;
          sp_next = (sp > 0) ? (sp - 1) : sp;
        end
        3'b010: begin // POP Y
          pop_op = 1'b1;
          out_mux_sel = 2'b10;
          reg_wr = 1'b1;
          out_reg_val = (sp > 0) ? stack[sp-1] : 8'hXX;
          sp_next = (sp > 0) ? (sp - 1) : sp;
        end
        3'b011: begin // ST A (set A <- N)
          st_op = 1'b1;
          reg_wr = 1'b1;
          out_mux_sel = 2'b00;
          out_reg_val = input_num;
        end
        3'b100: begin // ST X (set X <- N)
          st_op = 1'b1;
          reg_wr = 1'b1;
          out_mux_sel = 2'b01;
          out_reg_val = input_num;
        end
        3'b101: begin // ST Y (set Y <- N)
          st_op = 1'b1;
          reg_wr = 1'b1;
          out_mux_sel = 2'b10;
          out_reg_val = input_num;
        end
        3'b110: begin // ZE A
          ze_op = 1'b1;
          reg_wr = 1'b1;
          out_mux_sel = 2'b00;
          out_reg_val = 8'h00;
        end
        3'b111: begin // DI A
          di_op = 1'b1;
          out_mux_sel = 2'b00;
        end
        default: begin
          // No operation for undefined encodings
        end
      endcase
    end else begin
      case (instr[2:0])
        3'b000: begin // PH (push N)
          push_op = 1'b1;
          sp_next = (sp < 6'd40) ? (sp + 1) : sp; // cap at 40
        end
        3'b001: begin // PL (pop)
          pop_op = 1'b1;
          stack_underflow = (sp == 6'd0);
          underflow_pulse = stack_underflow;       // show underflow in same cycle
          sp_next = stack_underflow ? sp : ((sp > 0) ? (sp - 1) : sp);
          // Value on underflow is don't-care; we don't write to a register here.
        end
        3'b010: begin // AD (add top two values and push result)
          add_op = 1'b1;
          stack_underflow = (sp < 2);
          underflow_pulse = stack_underflow;
          sp_next = stack_underflow ? sp : (sp - 1); // -1 because we add back 1 result
        end
        3'b011: begin // DI X
          di_op = 1'b1;
          out_mux_sel = 2'b01;
        end
        3'b100: begin // DI Y
          di_op = 1'b1;
          out_mux_sel = 2'b10;
        end
        default: begin
          // No operation for other encodings
        end
      endcase
    end
  end

  // Output mux for DI
  always_comb begin
    case (out_mux_sel)
      2'b00: out_reg_val = reg_A;
      2'b01: out_reg_val = reg_X;
      2'b10: out_reg_val = reg_Y;
      default: out_reg_val = 8'hXX;
    endcase
  end

  // Next-state logic
  always_comb begin
    state_next = state;
    case (state)
      IDLE:    state_next = start ? FETCH : IDLE;
      FETCH:   state_next = EXECUTE;
      EXECUTE: begin
        if (underflow_pulse || di_op) begin
          state_next = DONE;
        end else begin
          state_next = FETCH;
        end
      end
      DONE:    state_next = DONE; // remain until reset
      default: state_next = IDLE;
    endcase
  end

  // Sequential state update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= state_next;
    end
  end

  // Program counter and instruction fetch
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc <= 6'd0;
      instr <= 8'h00;
    end else begin
      if (state == IDLE) begin
        pc <= 6'd0;
        instr <= 8'h00;
      end else if (state == FETCH) begin
        instr <= input_num; // instruction stream provided externally via input_num[7:0]
      end else if (state == EXECUTE) begin
        if (!(underflow_pulse || di_op)) begin
          pc <= pc + 1;
        end
        // instr held during EXECUTE
      end else begin
        // DONE: no change
      end
    end
  end

  // Register file write (A, X, Y)
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      reg_A <= 8'hXX;  // simulate unknown/X value after reset
      reg_X <= 8'hXX;
      reg_Y <= 8'hXX;
    end else begin
      if (reg_wr) begin
        case (out_mux_sel)
          2'b00: reg_A <= out_reg_val;
          2'b01: reg_X <= out_reg_val;
          2'b10: reg_Y <= out_reg_val;
          default: ;
        endcase
      end
    end
  end

  // Stack pointer and stack memory
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sp <= 6'd0;
    end else begin
      if (state == IDLE) begin
        sp <= 6'd0;
      end else if (state == EXECUTE) begin
        sp <= sp_next;
        if (push_op && (sp < 6'd40)) begin
          stack[sp] <= input_num; // push N
        end else if (add_op && !stack_underflow) begin
          // (a + b) % 256, pop two, push result
          stack[sp-2] <= (stack[sp-1] + stack[sp-2]);
        end
      end
    end
  end

  // Outputs: display_out and done
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      display_out <= 8'h00;
      done <= 1'b0;
    end else begin
      if (state == IDLE) begin
        display_out <= 8'h00;
        done <= 1'b0;
      end else if (state == EXECUTE) begin
        if (di_op) begin
          display_out <= out_reg_val;
          done <= 1'b1;  // high when DI executed
        end else if (underflow_pulse) begin
          done <= 1'b1;  // high on PL underflow
        end
      end
      // In DONE state, hold values
    end
  end

endmodule
