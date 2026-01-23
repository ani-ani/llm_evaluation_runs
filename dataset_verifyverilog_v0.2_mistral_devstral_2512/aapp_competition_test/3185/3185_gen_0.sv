module factorial_inverse (
  input clk,
  input rst_n,
  input start,
  input [63:0] target_factorial,
  output reg [7:0] result_n,
  output reg valid,
  output reg found
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CALCULATING,
    CHECKING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [7:0] n;
  reg [63:0] factorial_accum;
  reg [7:0] match_n;
  reg match_found;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      n <= 0;
      factorial_accum <= 1;
      match_n <= 0;
      match_found <= 0;
      result_n <= 0;
      valid <= 0;
      found <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          n <= 0;
          factorial_accum <= 1;
          match_n <= 0;
          match_found <= 0;
          result_n <= 0;
          valid <= 0;
          found <= 0;
        end

        CALCULATING: begin
          if (n == 0) begin
            factorial_accum <= 1;
          end else begin
            factorial_accum <= factorial_accum * n;
          end
        end

        CHECKING: begin
          if (factorial_accum == target_factorial) begin
            match_n <= n;
            match_found <= 1;
          end
        end

        DONE: begin
          result_n <= match_n;
          valid <= 1;
          found <= match_found;
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
          next_state = CALCULATING;
        end
      end

      CALCULATING: begin
        next_state = CHECKING;
      end

      CHECKING: begin
        if (n == 20) begin
          next_state = DONE;
        end else begin
          next_state = CALCULATING;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

  // Counter increment logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n <= 0;
    end else begin
      if (current_state == CALCULATING && next_state == CHECKING) begin
        n <= n + 1;
      end else if (current_state == CHECKING && next_state == CALCULATING) begin
        n <= n + 1;
      end
    end
  end

endmodule