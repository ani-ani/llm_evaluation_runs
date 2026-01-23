module winning_strategy (
  input clk,
  input rst_n,
  input start,
  input [15:0] k,
  input [15:0] c_in,
  input valid_c,
  input done_c,
  output reg result,
  output reg output_valid
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    READ_C,
    CALC_GCD1,
    CALC_GCD2,
    CALC_LCM,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [31:0] L;
  reg [31:0] temp1, temp2;
  reg [15:0] G1, G2;
  reg [15:0] a, b;
  reg [4:0] count;
  reg [3:0] c_count;

  // GCD state machine
  typedef enum logic [1:0] {
    GCD_IDLE,
    GCD_COMPUTE,
    GCD_DONE
  } gcd_state_t;

  gcd_state_t gcd_state, gcd_next_state;

  // GCD computation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      gcd_state <= GCD_IDLE;
      a <= 0;
      b <= 0;
      count <= 0;
    end else begin
      gcd_state <= gcd_next_state;
      if (gcd_state == GCD_COMPUTE) begin
        if (a < b) begin
          temp1 <= a;
          a <= b;
          b <= temp1;
        end
        if (b != 0) begin
          temp1 <= a % b;
          a <= b;
          b <= temp1;
        end
      end
    end
  end

  always @(*) begin
    gcd_next_state = gcd_state;
    case (gcd_state)
      GCD_IDLE: begin
        if (next_state == CALC_GCD1 || next_state == CALC_GCD2) begin
          gcd_next_state = GCD_COMPUTE;
        end
      end
      GCD_COMPUTE: begin
        if (b == 0) begin
          gcd_next_state = GCD_DONE;
        end
      end
      GCD_DONE: begin
        gcd_next_state = GCD_IDLE;
      end
      default: gcd_next_state = GCD_IDLE;
    endcase
  end

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      L <= 1;
      G1 <= 0;
      G2 <= 0;
      c_count <= 0;
      result <= 0;
      output_valid <= 0;
    end else begin
      current_state <= next_state;
      case (current_state)
        IDLE: begin
          if (start) begin
            L <= 1;
            c_count <= 0;
            result <= 0;
            output_valid <= 0;
          end
        end
        READ_C: begin
          if (valid_c) begin
            a <= k;
            b <= c_in;
            gcd_state <= GCD_COMPUTE;
          end
        end
        CALC_GCD1: begin
          if (gcd_state == GCD_DONE) begin
            G1 <= a;
            a <= L[15:0];
            b <= G1;
            gcd_state <= GCD_COMPUTE;
          end
        end
        CALC_GCD2: begin
          if (gcd_state == GCD_DONE) begin
            G2 <= a;
            temp1 <= L * G1;
            temp2 <= temp1 / G2;
            L <= temp2;
            c_count <= c_count + 1;
          end
        end
        CALC_LCM: begin
          if (done_c) begin
            result <= (L == k) ? 1 : 0;
            output_valid <= 1;
          end
        end
        DONE: begin
          if (!start) begin
            output_valid <= 0;
          end
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
          next_state = READ_C;
        end
      end
      READ_C: begin
        if (valid_c) begin
          next_state = CALC_GCD1;
        end else if (done_c) begin
          next_state = CALC_LCM;
        end
      end
      CALC_GCD1: begin
        if (gcd_state == GCD_DONE) begin
          next_state = CALC_GCD2;
        end
      end
      CALC_GCD2: begin
        if (gcd_state == GCD_DONE) begin
          if (done_c) begin
            next_state = CALC_LCM;
          end else begin
            next_state = READ_C;
          end
        end
      end
      CALC_LCM: begin
        if (done_c) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
      default: next_state = IDLE;
    endcase
  end

endmodule