module negabase_converter (
  input clk,
  input rst_n,
  input start,
  input [63:0] p,
  input [15:0] k,
  output reg [5:0] count,
  output reg [15:0] coeff_out,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    OUTPUT,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [63:0] p_reg;
  reg [15:0] k_reg;
  reg [15:0] coeff_buffer [0:63];
  reg [5:0] coeff_count;
  reg [5:0] output_index;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      p_reg <= 0;
      k_reg <= 0;
      coeff_count <= 0;
      output_index <= 0;
      count <= 0;
      coeff_out <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (p_reg == 0) next_state = OUTPUT;
      end
      OUTPUT: begin
        if (output_index == coeff_count) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      p_reg <= 0;
      k_reg <= 0;
      coeff_count <= 0;
      output_index <= 0;
    end else begin
      case (current_state)
        IDLE: begin
          if (start) begin
            p_reg <= p;
            k_reg <= k;
            coeff_count <= 0;
            output_index <= 0;
          end
        end
        PROCESSING: begin
          if (p_reg != 0) begin
            reg [63:0] remainder;
            reg [63:0] quotient;
            
            // Calculate remainder and quotient
            remainder = p_reg % k_reg;
            quotient = p_reg / k_reg;
            
            // Adjust for negative remainder
            if (remainder < 0) begin
              remainder = remainder + k_reg;
              quotient = quotient + 1;
            end
            
            // Store coefficient
            coeff_buffer[coeff_count] <= remainder;
            coeff_count <= coeff_count + 1;
            
            // Update p
            p_reg <= -quotient;
          end
        end
        OUTPUT: begin
          if (output_index < coeff_count) begin
            coeff_out <= coeff_buffer[output_index];
            output_index <= output_index + 1;
          end
        end
        DONE: begin
          if (!start) begin
            p_reg <= 0;
            k_reg <= 0;
            coeff_count <= 0;
            output_index <= 0;
          end
        end
      endcase
    end
  end

  // Output logic
  always @(*) begin
    count = coeff_count;
    done = (current_state == DONE);
  end

endmodule