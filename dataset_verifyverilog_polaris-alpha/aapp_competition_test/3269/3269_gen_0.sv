module digit_distance_accumulator(
  input  wire        clk,
  input  wire        rst_n,
  input  reg         start,
  input  reg  [15:0] A,
  input  reg  [15:0] B,
  output reg  [31:0] result,
  output reg         done
);

  // Constants
  localparam MOD = 32'd1000000007;

  // Internal registers
  reg [15:0] curr_X;
  reg [15:0] curr_Y;

  // FSM states
  typedef enum logic [1:0] {
    S_IDLE  = 2'b00,
    S_RUN   = 2'b01,
    S_DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Distance computation for current pair (curr_X, curr_Y)
  wire [3:0] X0 = curr_X[3:0];
  wire [3:0] X1 = curr_X[7:4];
  wire [3:0] X2 = curr_X[11:8];
  wire [3:0] X3 = curr_X[15:12];

  wire [3:0] Y0 = curr_Y[3:0];
  wire [3:0] Y1 = curr_Y[7:4];
  wire [3:0] Y2 = curr_Y[11:8];
  wire [3:0] Y3 = curr_Y[15:12];

  wire [3:0] d0 = (X0 >= Y0) ? (X0 - Y0) : (Y0 - X0);
  wire [3:0] d1 = (X1 >= Y1) ? (X1 - Y1) : (Y1 - X1);
  wire [3:0] d2 = (X2 >= Y2) ? (X2 - Y2) : (Y2 - X2);
  wire [3:0] d3 = (X3 >= Y3) ? (X3 - Y3) : (Y3 - X3);

  wire [5:0] sum01 = d0 + d1;
  wire [5:0] sum23 = d2 + d3;
  wire [6:0] dist  = sum01 + sum23; // max 36

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start && done) begin
          next_state = S_RUN;
        end
      end
      S_RUN: begin
        // Transition to DONE when final pair processed: X==B and Y==B
        if ((curr_X == B) && (curr_Y == B)) begin
          next_state = S_DONE;
        end
      end
      S_DONE: begin
        // Wait for next start while done=1
        if (start && done) begin
          next_state = S_RUN;
        end
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= S_IDLE;
      result  <= 32'd0;
      done    <= 1'b0;
      curr_X  <= 16'd0;
      curr_Y  <= 16'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          if (start && done) begin
            // Initialize for new computation
            result <= 32'd0;
            done   <= 1'b0;
            curr_X <= A;
            curr_Y <= A;
          end else if (!done) begin
            // First ever reset-to-run case: allow start without done previously high
            if (start) begin
              result <= 32'd0;
              done   <= 1'b0;
              curr_X <= A;
              curr_Y <= A;
            end else begin
              done <= 1'b0;
            end
          end else begin
            done <= done; // hold
          end
        end

        S_RUN: begin
          // Accumulate distance for current (curr_X, curr_Y)
          // Modular addition: (result + dist) mod MOD
          if (result + dist >= MOD)
            result <= result + dist - MOD;
          else
            result <= result + dist;

          // Advance Y, then X when Y reaches X
          if (curr_Y == curr_X) begin
            // Move to next X, reset Y
            if (curr_X != B) begin
              curr_X <= curr_X + 16'd1;
              curr_Y <= A;
            end else begin
              // When curr_X==B and curr_Y==curr_X, next_state will go to S_DONE
              curr_Y <= curr_Y; // hold
              curr_X <= curr_X; // hold
            end
          end else begin
            // Increment Y within [A, curr_X]
            curr_Y <= curr_Y + 16'd1;
          end

          done <= 1'b0;
        end

        S_DONE: begin
          done <= 1'b1;
          // Wait for new start while done=1; initialization handled in S_IDLE via next_state
        end

        default: begin
          state   <= S_IDLE;
          result  <= 32'd0;
          done    <= 1'b0;
          curr_X  <= 16'd0;
          curr_Y  <= 16'd0;
        end
      endcase
    end
  end

endmodule