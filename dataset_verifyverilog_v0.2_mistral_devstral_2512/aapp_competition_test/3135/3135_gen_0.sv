module signed_binary_converter (
  input clk,
  input rst_n,
  input start,
  input [15:0] binary_in,
  output reg [17:0] signed_out,
  output reg [4:0] length,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [17:0] signed_out_reg;
  reg [4:0] length_reg;
  reg done_reg;
  reg [17:0] carry;
  reg [4:0] bit_counter;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      signed_out_reg <= 18'b0;
      length_reg <= 5'b0;
      done_reg <= 1'b0;
      carry <= 18'b0;
      bit_counter <= 5'b0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          if (start) begin
            signed_out_reg <= 18'b0;
            length_reg <= 5'b0;
            done_reg <= 1'b0;
            carry <= 18'b0;
            bit_counter <= 5'b0;
            carry[0] <= 1'b0; // Initialize carry for bit 0
          end
        end
        
        PROCESSING: begin
          if (bit_counter == 17) begin
            // Last iteration, no next carry needed
            if (carry[bit_counter]) begin
              signed_out_reg[bit_counter*2+1:bit_counter*2] <= 2'b11; // -1
              length_reg <= bit_counter + 1;
            end else begin
              signed_out_reg[bit_counter*2+1:bit_counter*2] <= 2'b00; // 0
              // Don't increment length for trailing zeros
              if (bit_counter > length_reg) begin
                length_reg <= bit_counter;
              end
            end
          end else begin
            // Process current bit
            reg current_bit = (bit_counter < 16) ? binary_in[bit_counter] : 1'b0;
            reg sum = current_bit + carry[bit_counter];
            
            case (sum)
              2'b00: begin // 0
                signed_out_reg[bit_counter*2+1:bit_counter*2] <= 2'b00;
                carry[bit_counter+1] <= 1'b0;
              end
              2'b01: begin // +1
                signed_out_reg[bit_counter*2+1:bit_counter*2] <= 2'b01;
                carry[bit_counter+1] <= 1'b0;
              end
              2'b10: begin // -1 (2 in binary)
                signed_out_reg[bit_counter*2+1:bit_counter*2] <= 2'b11;
                carry[bit_counter+1] <= 1'b1;
              end
            endcase
            
            // Update length if non-zero
            if (sum != 2'b00) begin
              length_reg <= bit_counter + 1;
            end
          end
          
          bit_counter <= bit_counter + 1;
        end
        
        DONE: begin
          // Stay in DONE until reset
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = PROCESSING;
        end
      end
      
      PROCESSING: begin
        if (bit_counter == 17) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Output assignments
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      signed_out <= 18'b0;
      length <= 5'b0;
      done <= 1'b0;
    end else begin
      signed_out <= signed_out_reg;
      length <= length_reg;
      done <= (current_state == DONE) ? 1'b1 : 1'b0;
    end
  end

endmodule