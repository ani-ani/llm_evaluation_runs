module minimal_unique_substring_gen (
  input clk,
  input rst_n,
  input start,
  input [15:0] n,
  input [15:0] k,
  output reg out_bit,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    GENERATING,
    FINISHED
  } state_t;

  state_t current_state, next_state;
  reg [15:0] bit_counter;
  reg [15:0] spacing;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      bit_counter <= 16'd0;
      out_bit <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      if (next_state == GENERATING) begin
        bit_counter <= bit_counter + 16'd1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = GENERATING;
      end
      GENERATING: begin
        if (bit_counter == n - 16'd1) next_state = FINISHED;
      end
      FINISHED: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Spacing calculation
  always @(*) begin
    if (n == k) begin
      spacing = 16'd0;
    end else begin
      spacing = (n - k) / 16'd2;
    end
  end

  // Output bit generation
  always @(*) begin
    out_bit = 1'b0;
    done = 1'b0;
    case (current_state)
      IDLE: begin
        out_bit = 1'b0;
        done = 1'b0;
      end
      GENERATING: begin
        if (n == k) begin
          out_bit = 1'b1;
        end else if (spacing > 16'd0) begin
          if ((bit_counter + 16'd1) % (spacing + 16'd1) == spacing) begin
            out_bit = 1'b1;
          end else begin
            out_bit = 1'b0;
          end
        end else begin
          out_bit = 1'b0;
        end
        done = (bit_counter == n - 16'd1) ? 1'b1 : 1'b0;
      end
      FINISHED: begin
        out_bit = 1'b0;
        done = 1'b1;
      end
    endcase
  end

endmodule