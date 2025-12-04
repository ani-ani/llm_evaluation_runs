module rocket_fuel_calc (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] m,
  input [15:0] a [7:0],
  input [15:0] b [7:0],
  output reg [39:0] fuel,
  output reg done
);

  // Internal state and data
  localparam W_OUT = 40;  // fuel output width (Q16.16 + guard bits)
  localparam W_ACC = 48;  // accumulator width for precise Q32.32 internal math

  typedef enum logic [1:0] {S_IDLE = 2'b00, S_RUN = 2'b01, S_DONE = 2'b10} state_t;
  state_t state, state_nxt;

  reg [3:0] cnt, cnt_nxt;                    // cycle counter (0..15)
  reg [15:0] n_reg, m_reg;                   // registered inputs for stable capture
  reg [15:0] a_reg [7:0];                    // registered coefficient arrays
  reg [15:0] b_reg [7:0];
  reg [W_ACC-1:0] fuel_acc, fuel_acc_nxt;    // internal accumulator (Q32.32)
  reg err_one, err_one_nxt;                  // flag: a_i==1 or b_i==1

  // Combinational updates
  always @(*) begin
    // Defaults (avoid latches)
    state_nxt   = state;
    cnt_nxt     = cnt;
    fuel_acc_nxt = fuel_acc;
    err_one_nxt = err_one;

    case (state)
      S_IDLE: begin
        if (start) begin
          // Latch inputs
          n_reg      = n;
          m_reg      = m;
          a_reg[0] = a[0]; a_reg[1] = a[1]; a_reg[2] = a[2]; a_reg[3] = a[3];
          a_reg[4] = a[4]; a_reg[5] = a[5]; a_reg[6] = a[6]; a_reg[7] = a[7];
          b_reg[0] = b[0]; b_reg[1] = b[1]; b_reg[2] = b[2]; b_reg[3] = b[3];
          b_reg[4] = b[4]; b_reg[5] = b[5]; b_reg[6] = b[6]; b_reg[7] = b[7];

          // Initialize fuel to payload mass in Q16.16 (16 fractional bits)
          fuel_acc_nxt = {m_reg, 16'b0};  // Q32.32: high 16 bits = integer(m), low 16 bits = frac
          err_one_nxt  = 1'b0;
          cnt_nxt      = 4'b0;
          state_nxt    = S_RUN;
        end
      end

      S_RUN: begin
        // Cycle i: 0..15 -> planet p = i/2 (0..7), half-cycle type 0=takeoff, 1=landing
        logic [3:0] p;
        logic is_takeoff;
        logic [15:0] coeff;
        logic [15:0] a_i, b_i;
        logic [W_ACC-1:0] next_fuel, term, numer;
        logic coeff_is_one;

        p            = cnt >> 1;
        is_takeoff   = ~cnt[0];
        a_i          = a_reg[p];
        b_i          = b_reg[p];
        coeff        = is_takeoff ? a_i : b_i;

        // If we are beyond the number of planets, freeze accumulator
        if (p >= n_reg) begin
          next_fuel  = fuel_acc;
          coeff_is_one = 1'b0;
        end else begin
          // Form numerator: (fuel + m) in Q32.32, then promote to Q48.48 for division
          numer = fuel_acc + {m_reg, 16'b0};                // Q32.32
          numer = numer << 16;                              // promote to Q48.48

          // Division in Q16.16 -> term in Q32.32
          term  = numer / coeff;                            // integer divide in Q16.16
          term  = term >> 16;                               // back to Q32.32

          // Update fuel: fuel -= term
          next_fuel = fuel_acc - term;

          // Error condition: coefficient equal to 1
          coeff_is_one = (coeff == 16'd1);
        end

        // Update error flag and accumulator
        err_one_nxt  = err_one | coeff_is_one;
        fuel_acc_nxt = next_fuel;

        // Cycle counter and state
        if (cnt == 4'd15) begin
          state_nxt = S_DONE;
        end else begin
          cnt_nxt = cnt + 1'b1;
        end
      end

      S_DONE: begin
        state_nxt = S_IDLE;
      end

      default: state_nxt = S_IDLE;
    endcase
  end

  // Output logic
  always @(*) begin
    if (state == S_DONE) begin
      if (err_one) begin
        fuel = 40'hFF_FFFF_FFFF;    // required special output
      end else begin
        // Convert Q32.32 accumulator to Q16.16 by dropping 16 fractional bits
        fuel = fuel_acc[47:8];
      end
    end else begin
      fuel = 40'b0;
    end
  end

  // done flag: asserted only in S_DONE
  always @(*) begin
    done = (state == S_DONE);
  end

  // Registers (non-blocking assignments)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      cnt        <= 4'b0;
      fuel_acc   <= {W_ACC{1'b0}};
      err_one    <= 1'b0;
      n_reg      <= 4'b0;
      m_reg      <= 16'b0;
      a_reg[0] <= 16'b0; a_reg[1] <= 16'b0; a_reg[2] <= 16'b0; a_reg[3] <= 16'b0;
      a_reg[4] <= 16'b0; a_reg[5] <= 16'b0; a_reg[6] <= 16'b0; a_reg[7] <= 16'b0;
      b_reg[0] <= 16'b0; b_reg[1] <= 16'b0; b_reg[2] <= 16'b0; b_reg[3] <= 16'b0;
      b_reg[4] <= 16'b0; b_reg[5] <= 16'b0; b_reg[6] <= 16'b0; b_reg[7] <= 16'b0;
    end else begin
      state      <= state_nxt;
      cnt        <= cnt_nxt;
      fuel_acc   <= fuel_acc_nxt;
      err_one    <= err_one_nxt;
      n_reg      <= n_reg;
      m_reg      <= m_reg;
      a_reg[0] <= a_reg[0]; a_reg[1] <= a_reg[1]; a_reg[2] <= a_reg[2]; a_reg[3] <= a_reg[3];
      a_reg[4] <= a_reg[4]; a_reg[5] <= a_reg[5]; a_reg[6] <= a_reg[6]; a_reg[7] <= a_reg[7];
      b_reg[0] <= b_reg[0]; b_reg[1] <= b_reg[1]; b_reg[2] <= b_reg[2]; b_reg[3] <= b_reg[3];
      b_reg[4] <= b_reg[4]; b_reg[5] <= b_reg[5]; b_reg[6] <= b_reg[6]; b_reg[7] <= b_reg[7];
    end
  end

endmodule
