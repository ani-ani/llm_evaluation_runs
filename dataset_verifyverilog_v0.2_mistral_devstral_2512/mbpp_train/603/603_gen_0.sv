module ludic_sieve (
  input clk,
  input rst_n,
  input start,
  input [5:0] max_value,
  output reg [5:0] result_index,
  output reg [5:0] result_value,
  output reg result_valid,
  output reg done
);

  // Define states
  typedef enum logic [2:0] {
    IDLE,
    INIT_ARRAY,
    PROCESS_SIEVE,
    COMPACT_ARRAY,
    OUTPUT_RESULTS,
    DONE
  } state_t;

  // State machine
  state_t state, next_state;

  // Internal RAM (64x6 bits)
  reg [5:0] ram [0:63];
  reg valid [0:63];

  // Control signals
  reg [5:0] current_index;
  reg [5:0] current_ludic;
  reg [5:0] output_index;
  reg [5:0] sieve_index;
  reg [5:0] compact_write_ptr;
  reg [5:0] compact_read_ptr;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_index <= 0;
      current_ludic <= 0;
      output_index <= 0;
      sieve_index <= 0;
      compact_write_ptr <= 0;
      compact_read_ptr <= 0;
      result_index <= 0;
      result_value <= 0;
      result_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // State transition logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = INIT_ARRAY;
      end
      INIT_ARRAY: begin
        if (current_index == max_value) next_state = PROCESS_SIEVE;
      end
      PROCESS_SIEVE: begin
        if (sieve_index == max_value) next_state = COMPACT_ARRAY;
      end
      COMPACT_ARRAY: begin
        if (compact_read_ptr == max_value + 1) next_state = OUTPUT_RESULTS;
      end
      OUTPUT_RESULTS: begin
        if (output_index == max_value) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // State actions
  always @(posedge clk) begin
    if (!rst_n) begin
      // Reset handled in state machine
    end else begin
      case (state)
        INIT_ARRAY: begin
          if (current_index <= max_value) begin
            ram[current_index] <= current_index;
            valid[current_index] <= 1'b1;
            current_index <= current_index + 1;
          end
        end
        PROCESS_SIEVE: begin
          if (valid[sieve_index]) begin
            current_ludic <= ram[sieve_index];
            // Mark multiples for removal
            for (int i = sieve_index + current_ludic; i <= max_value; i = i + current_ludic) begin
              valid[i] <= 0;
            end
          end
          sieve_index <= sieve_index + 1;
        end
        COMPACT_ARRAY: begin
          if (valid[compact_read_ptr]) begin
            ram[compact_write_ptr] <= ram[compact_read_ptr];
            valid[compact_write_ptr] <= 1'b1;
            compact_write_ptr <= compact_write_ptr + 1;
          end
          compact_read_ptr <= compact_read_ptr + 1;
        end
        OUTPUT_RESULTS: begin
          if (valid[output_index]) begin
            result_index <= output_index;
            result_value <= ram[output_index];
            result_valid <= 1'b1;
          end
          output_index <= output_index + 1;
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

  // Reset outputs when not in OUTPUT_RESULTS
  always @(posedge clk) begin
    if (state != OUTPUT_RESULTS && state != DONE) begin
      result_valid <= 0;
      done <= 0;
    end
  end

endmodule