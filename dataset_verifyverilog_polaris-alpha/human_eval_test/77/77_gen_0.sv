module cube_checker(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire signed [15:0] a,
  output reg         is_cube,
  output reg         done
);

  // State encoding
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    CALC  = 2'b01,
    DONE  = 2'b10
  } state_t;

  state_t state, next_state;

  // Counter for candidate cube root: range -128 to 127
  reg  signed [7:0] n;
  wire signed [15:0] n_sq;
  wire signed [15:0] n_cu;

  // Combinational cube computation (fits in 16-bit signed range)
  assign n_sq = n * n;
  assign n_cu = n_sq * n;

  // Next state logic and control
  reg signed [7:0] next_n;
  reg next_is_cube;
  reg next_done;

  always @(*) begin
    // Default assignments
    next_state   = state;
    next_n       = n;
    next_is_cube = is_cube;
    next_done    = done;

    case (state)
      IDLE: begin
        next_is_cube = 1'b0;
        next_done    = 1'b0;
        next_n       = -8'sd128;
        if (start) begin
          next_state = CALC;
        end
      end

      CALC: begin
        next_is_cube = 1'b0;
        next_done    = 1'b0;
        // Check current candidate cube
        if (n_cu == a) begin
          next_is_cube = 1'b1;
          next_done    = 1'b1;
          next_state   = DONE; // Early termination on match
        end else begin
          // If reached maximum candidate without match
          if (n == 8'sd127) begin
            next_is_cube = 1'b0;
            next_done    = 1'b1;
            next_state   = DONE;
          end else begin
            // Move to next candidate
            next_n = n + 8'sd1;
          end
        end
      end

      DONE: begin
        // Hold results until a new start command
        next_state = DONE;
        if (start) begin
          // Start a new check
          next_is_cube = 1'b0;
          next_done    = 1'b0;
          next_n       = -8'sd128;
          next_state   = CALC;
        end
      end

      default: begin
        next_state   = IDLE;
        next_is_cube = 1'b0;
        next_done    = 1'b0;
        next_n       = -8'sd128;
      end
    endcase
  end

  // Sequential logic: state and registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= IDLE;
      n        <= -8'sd128;
      is_cube  <= 1'b0;
      done     <= 1'b0;
    end else begin
      state    <= next_state;
      n        <= next_n;
      is_cube  <= next_is_cube;
      done     <= next_done;
    end
  end

endmodule