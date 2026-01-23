module date_format_converter (
  input clk,
  input rst_n,
  input start,
  input [7:0] char_in,
  output reg [7:0] char_out,
  output reg out_valid,
  output reg done
);

  // State definitions
  typedef enum logic [4:0] {
    IDLE,
    READ_Y1, READ_Y2, READ_Y3, READ_Y4,
    SKIP_DASH1,
    READ_M1, READ_M2,
    SKIP_DASH2,
    READ_D1, READ_D2,
    OUTPUT_D1, OUTPUT_D2,
    OUTPUT_DASH1,
    OUTPUT_M1, OUTPUT_M2,
    OUTPUT_DASH2,
    OUTPUT_Y1, OUTPUT_Y2, OUTPUT_Y3, OUTPUT_Y4,
    DONE
  } state_t;

  state_t state, next_state;

  // Storage registers for digits
  reg [7:0] y1, y2, y3, y4;
  reg [7:0] m1, m2;
  reg [7:0] d1, d2;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      out_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    out_valid = 0;
    done = 0;

    case (state)
      IDLE: begin
        if (start) next_state = READ_Y1;
      end

      READ_Y1: next_state = READ_Y2;
      READ_Y2: next_state = READ_Y3;
      READ_Y3: next_state = READ_Y4;
      READ_Y4: next_state = SKIP_DASH1;

      SKIP_DASH1: next_state = READ_M1;

      READ_M1: next_state = READ_M2;
      READ_M2: next_state = SKIP_DASH2;

      SKIP_DASH2: next_state = READ_D1;

      READ_D1: next_state = READ_D2;
      READ_D2: next_state = OUTPUT_D1;

      OUTPUT_D1: begin next_state = OUTPUT_D2; out_valid = 1; end
      OUTPUT_D2: begin next_state = OUTPUT_DASH1; out_valid = 1; end
      OUTPUT_DASH1: begin next_state = OUTPUT_M1; out_valid = 1; end
      OUTPUT_M1: begin next_state = OUTPUT_M2; out_valid = 1; end
      OUTPUT_M2: begin next_state = OUTPUT_DASH2; out_valid = 1; end
      OUTPUT_DASH2: begin next_state = OUTPUT_Y1; out_valid = 1; end
      OUTPUT_Y1: begin next_state = OUTPUT_Y2; out_valid = 1; end
      OUTPUT_Y2: begin next_state = OUTPUT_Y3; out_valid = 1; end
      OUTPUT_Y3: begin next_state = OUTPUT_Y4; out_valid = 1; end
      OUTPUT_Y4: begin next_state = DONE; out_valid = 1; end

      DONE: begin done = 1; if (!start) next_state = IDLE; end

      default: next_state = IDLE;
    endcase
  end

  // Input processing
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      y1 <= 0; y2 <= 0; y3 <= 0; y4 <= 0;
      m1 <= 0; m2 <= 0;
      d1 <= 0; d2 <= 0;
    end else begin
      case (state)
        READ_Y1: y1 <= char_in;
        READ_Y2: y2 <= char_in;
        READ_Y3: y3 <= char_in;
        READ_Y4: y4 <= char_in;
        READ_M1: m1 <= char_in;
        READ_M2: m2 <= char_in;
        READ_D1: d1 <= char_in;
        READ_D2: d2 <= char_in;
      endcase
    end
  end

  // Output generation
  always @(*) begin
    char_out = 8'h0;

    case (state)
      OUTPUT_D1: char_out = d1;
      OUTPUT_D2: char_out = d2;
      OUTPUT_DASH1: char_out = 8'h2d; // ASCII '-'
      OUTPUT_M1: char_out = m1;
      OUTPUT_M2: char_out = m2;
      OUTPUT_DASH2: char_out = 8'h2d; // ASCII '-'
      OUTPUT_Y1: char_out = y1;
      OUTPUT_Y2: char_out = y2;
      OUTPUT_Y3: char_out = y3;
      OUTPUT_Y4: char_out = y4;
    endcase
  end

endmodule