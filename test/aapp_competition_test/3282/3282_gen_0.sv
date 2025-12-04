module lunch_bill_processor(
  input clk,
  input rst_n,
  input start,
  input [7:0] P,
  output reg [7:0] B_out,
  output reg [7:0] M_out,
  output reg valid,
  output reg done,
  output reg [7:0] count
);

  // Internal registers
  reg [7:0] B;
  reg [7:0] M;
  reg [7:0] P_reg;
  reg [7:0] P_half;
  reg active;

  // Pre-decoded P digits
  reg [3:0] Ph, Pt, Pu;

  // State machine for processing B values
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    LOAD  = 2'b01,
    RUN   = 2'b10,
    FINISH= 2'b11
  } state_t;

  state_t state, next_state;

  // Digit extraction function for 8-bit values (0-255)
  function automatic void extract_digits(
    input  [7:0] val,
    output [3:0] dh,
    output [3:0] dt,
    output [3:0] du
  );
    integer tmp;
    begin
      tmp = val;
      du  = tmp % 10;
      tmp = tmp / 10;
      dt  = tmp % 10;
      tmp = tmp / 10;
      dh  = tmp % 10;
    end
  endfunction

  // Check that 9 digits are all unique using a 10-bit flag vector
  function automatic logic all_unique_9(
    input [3:0] d0,
    input [3:0] d1,
    input [3:0] d2,
    input [3:0] d3,
    input [3:0] d4,
    input [3:0] d5,
    input [3:0] d6,
    input [3:0] d7,
    input [3:0] d8
  );
    logic [9:0] used;
    begin
      used = 10'b0;

      if (used[d0]) begin all_unique_9 = 1'b0; return; end
      used[d0] = 1'b1;

      if (used[d1]) begin all_unique_9 = 1'b0; return; end
      used[d1] = 1'b1;

      if (used[d2]) begin all_unique_9 = 1'b0; return; end
      used[d2] = 1'b1;

      if (used[d3]) begin all_unique_9 = 1'b0; return; end
      used[d3] = 1'b1;

      if (used[d4]) begin all_unique_9 = 1'b0; return; end
      used[d4] = 1'b1;

      if (used[d5]) begin all_unique_9 = 1'b0; return; end
      used[d5] = 1'b1;

      if (used[d6]) begin all_unique_9 = 1'b0; return; end
      used[d6] = 1'b1;

      if (used[d7]) begin all_unique_9 = 1'b0; return; end
      used[d7] = 1'b1;

      if (used[d8]) begin all_unique_9 = 1'b0; return; end
      used[d8] = 1'b1;

      all_unique_9 = 1'b1;
    end
  endfunction

  // Sequential logic: state, outputs, and counters
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state  <= IDLE;
      P_reg  <= 8'd0;
      P_half <= 8'd0;
      B      <= 8'd0;
      M      <= 8'd0;
      Ph     <= 4'd0;
      Pt     <= 4'd0;
      Pu     <= 4'd0;
      B_out  <= 8'd0;
      M_out  <= 8'd0;
      valid  <= 1'b0;
      done   <= 1'b0;
      count  <= 8'd0;
      active <= 1'b0;
    end else begin
      state <= next_state;

      // Default per-cycle outputs
      valid <= 1'b0;

      case (state)
        IDLE: begin
          done   <= 1'b0;
          active <= 1'b0;
          if (start) begin
            // Latch P, precompute digits and bounds
            P_reg      <= P;
            P_half     <= P >> 1; // floor(P/2)
            count      <= 8'd0;
            B          <= 8'd1;
            active     <= 1'b1;
            // Pre-extract P digits
            extract_digits(P, Ph, Pt, Pu);
          end
        end

        LOAD: begin
          // LOAD is used immediately after latching P in IDLE/start
          // Initialize first B to 1 already done in IDLE; nothing extra here
        end

        RUN: begin
          if (active) begin
            if (B <= P_half) begin
              M = P_reg - B;

              if (B < M) begin
                // Compute B and M digits
                logic [3:0] Bh, Bt, Bu;
                logic [3:0] Mh, Mt, Mu;
                extract_digits(B, Bh, Bt, Bu);
                extract_digits(M, Mh, Mt, Mu);

                // Check all 9 digits unique: B(3), M(3), P(3)
                if (all_unique_9(Bh, Bt, Bu, Mh, Mt, Mu, Ph, Pt, Pu)) begin
                  B_out <= B;
                  M_out <= M;
                  valid <= 1'b1;
                  count <= count + 8'd1;
                end
              end

              // Increment B each cycle
              B <= B + 8'd1;
            end else begin
              // Completed all B values
              active <= 1'b0;
              done   <= 1'b1;
            end
          end
        end

        FINISH: begin
          // Hold done high until next start; no changes to count/B_out/M_out
          done <= 1'b1;
          if (start) begin
            // New run request handled by next_state logic
          end
        end

        default: begin
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = RUN; // Go directly to RUN after loading parameters
        else
          next_state = IDLE;
      end

      RUN: begin
        if (!active) // when scanning finished
          next_state = FINISH;
        else
          next_state = RUN;
      end

      FINISH: begin
        if (start)
          next_state = RUN; // Restart computation on new start
        else
          next_state = FINISH;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule