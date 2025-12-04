module horse_chase(
  input clk,
  input rst_n,
  input start,
  input [3:0] L,
  input [3:0] A,
  input [3:0] B,
  input [3:0] P,
  output reg [4:0] time_out,
  output reg done
);

  // Internal state and registers
  reg [3:0] A_curr, B_curr, P_curr;
  reg [1:0] state;
  
  // State encoding
  localparam IDLE      = 2'b00;
  localparam INIT      = 2'b01;
  localparam PROCESS   = 2'b10;
  localparam CAPTURED  = 2'b11;

  // Combinational signals
  logic [3:0] A_next, B_next, P_next;
  logic [3:0] dA, dB;
  logic [3:0] speed;
  logic [3:0] leftCandidate, rightCandidate;
  logic [3:0] minDistLeft, minDistRight;
  logic capture;

  // Cow movement logic: move 1m towards horse if distance > 1
  always_comb begin
    // Cow A
    if (A_curr > P_curr) begin
      A_next = (A_curr - P_curr > 1) ? (A_curr - 1) : A_curr;
    end else begin
      A_next = (P_curr - A_curr > 1) ? (A_curr + 1) : A_curr;
    end
    // Cow B
    if (B_curr > P_curr) begin
      B_next = (B_curr - P_curr > 1) ? (B_curr - 1) : B_curr;
    end else begin
      B_next = (P_curr - B_curr > 1) ? (B_curr + 1) : B_curr;
    end

    // Determine horse speed (1m if at a cow's position, otherwise 2m)
    speed = (P_curr == A_curr || P_curr == B_curr) ? 4'd1 : 4'd2;

    // Compute left candidate
    if (speed == 4'd1) begin
      leftCandidate = (P_curr > 0) ? (P_curr - 1) : P_curr;
    end else begin // speed == 2
      if (P_curr >= 4'd2) leftCandidate = P_curr - 2;
      else if (P_curr == 4'd1) leftCandidate = P_curr - 1; // becomes 0
      else leftCandidate = 0; // P_curr == 0
    end

    // Compute right candidate
    if (speed == 4'd1) begin
      rightCandidate = (P_curr < L) ? (P_curr + 1) : P_curr;
    end else begin // speed == 2
      if (P_curr + 4'd2 <= L) rightCandidate = P_curr + 2;
      else if (P_curr + 4'd1 <= L) rightCandidate = P_curr + 1;
      else rightCandidate = P_curr; // cannot move right
    end

    // Minimum distance to cows for left candidate
    dA = (A_curr > leftCandidate) ? (A_curr - leftCandidate) : (leftCandidate - A_curr);
    dB = (B_curr > leftCandidate) ? (B_curr - leftCandidate) : (leftCandidate - B_curr);
    minDistLeft = (dA < dB) ? dA : dB;

    // Minimum distance to cows for right candidate
    dA = (A_curr > rightCandidate) ? (A_curr - rightCandidate) : (rightCandidate - A_curr);
    dB = (B_curr > rightCandidate) ? (B_curr - rightCandidate) : (rightCandidate - B_curr);
    minDistRight = (dA < dB) ? dA : dB;

    // Choose direction that maximizes the minimum distance (left on tie)
    if (minDistLeft >= minDistRight) begin
      P_next = leftCandidate;
    end else begin
      P_next = rightCandidate;
    end

    // Capture condition after horse moves
    capture = (A_next == P_next) || (B_next == P_next);
  end

  // Sequential logic: state machine and register updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      time_out   <= 5'd0;
      done       <= 1'b0;
      A_curr     <= 4'd0;
      B_curr     <= 4'd0;
      P_curr     <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          // Wait for start pulse
          if (start) begin
            state      <= INIT;
            time_out   <= 5'd0;
            done       <= 1'b0;
            A_curr     <= 4'd0;
            B_curr     <= 4'd0;
            P_curr     <= 4'd0;
          end else begin
            state      <= IDLE;
            time_out   <= 5'd0;
            done       <= 1'b0;
            A_curr     <= 4'd0;
            B_curr     <= 4'd0;
            P_curr     <= 4'd0;
          end
        end

        INIT: begin
          // Load initial positions and start simulation
          A_curr   <= A;
          B_curr   <= B;
          P_curr   <= P;
          time_out <= 5'd0;
          done     <= 1'b0;
          state    <= PROCESS;
        end

        PROCESS: begin
          // Increment time (each cycle represents one minute)
          time_out <= time_out + 5'd1;
          // Update positions according to the movement rules
          A_curr   <= A_next;
          B_curr   <= B_next;
          P_curr   <= P_next;
          done     <= 1'b0;
          // Check for capture
          if (capture) begin
            state    <= CAPTURED;
            done     <= 1'b1;
          end else begin
            state    <= PROCESS;
          end
        end

        CAPTURED: begin
          // Hold the result until reset
          time_out <= time_out;
          A_curr   <= A_curr;
          B_curr   <= B_curr;
          P_curr   <= P_curr;
          done     <= 1'b1;
          state    <= CAPTURED;
        end
      endcase
    end
  end

endmodule