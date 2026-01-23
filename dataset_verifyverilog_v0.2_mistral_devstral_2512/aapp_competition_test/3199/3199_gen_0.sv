module vault_security(
  input clk,
  input rst_n,
  input start,
  input [15:0] L,
  input [10:0] A,
  input [10:0] B,
  output reg [31:0] insecure_count,
  output reg [31:0] secure_count,
  output reg [31:0] super_secure_count,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CHECK_X,
    CHECK_Y,
    CALCULATE,
    DONE
  } state_t;

  state_t state, next_state;

  // Counters and registers
  reg [15:0] x_reg, x_next;
  reg [11:0] y_reg, y_next; // y ranges from -A to B, so 11 bits covers -2000 to 2000
  reg [31:0] insecure, secure, super_secure;

  // GCD calculation registers
  reg [15:0] a1, b1, a2, b2; // For gcd(x, y+A) and gcd(x, B-y)
  reg [15:0] temp1, temp2;
  reg g1_done, g2_done;
  reg [1:0] vis_count;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      x_reg <= 0;
      y_reg <= 0;
      insecure <= 0;
      secure <= 0;
      super_secure <= 0;
      done <= 0;
      g1_done <= 0;
      g2_done <= 0;
    end else begin
      state <= next_state;
      x_reg <= x_next;
      y_reg <= y_next;
      if (state == DONE) begin
        insecure_count <= insecure;
        secure_count <= secure;
        super_secure_count <= super_secure;
        done <= 1;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    x_next = x_reg;
    y_next = y_reg;

    case (state)
      IDLE: begin
        if (start) begin
          next_state = CHECK_X;
          x_next = 1;
          y_next = -A;
        end
      end

      CHECK_X: begin
        if (x_reg == L) begin
          next_state = DONE;
        end else if (y_reg == B) begin
          next_state = CHECK_X;
          x_next = x_reg + 1;
          y_next = -A;
        end else begin
          next_state = CHECK_Y;
        end
      end

      CHECK_Y: begin
        next_state = CALCULATE;
      end

      CALCULATE: begin
        if (g1_done && g2_done) begin
          next_state = CHECK_X;
          if (y_reg == B) begin
            x_next = x_reg + 1;
            y_next = -A;
          end else begin
            y_next = y_reg + 1;
          end
        end
      end

      DONE: begin
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // GCD calculation for g1 = gcd(x, y + A)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a1 <= 0;
      b1 <= 0;
      g1_done <= 0;
    end else if (state == CHECK_Y) begin
      a1 <= x_reg;
      b1 <= y_reg + A;
      g1_done <= 0;
    end else if (state == CALCULATE && !g1_done) begin
      if (b1 == 0) begin
        g1_done <= 1;
      end else if (a1 > b1) begin
        a1 <= a1 - b1;
      end else begin
        b1 <= b1 - a1;
      end
    end
  end

  // GCD calculation for g2 = gcd(x, B - y)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      a2 <= 0;
      b2 <= 0;
      g2_done <= 0;
    end else if (state == CHECK_Y) begin
      a2 <= x_reg;
      b2 <= B - y_reg;
      g2_done <= 0;
    end else if (state == CALCULATE && !g2_done) begin
      if (b2 == 0) begin
        g2_done <= 1;
      end else if (a2 > b2) begin
        a2 <= a2 - b2;
      end else begin
        b2 <= b2 - a2;
      end
    end
  end

  // Count visibility and update counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      vis_count <= 0;
    end else if (state == CALCULATE && g1_done && g2_done) begin
      vis_count = (a1 == 1) + (a2 == 1);
      case (vis_count)
        0: insecure <= insecure + 1;
        1: secure <= secure + 1;
        2: super_secure <= super_secure + 1;
      endcase
    end
  end

endmodule