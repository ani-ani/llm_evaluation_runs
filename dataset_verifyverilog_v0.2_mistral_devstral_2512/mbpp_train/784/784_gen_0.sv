module mul_even_odd (
  input clk,
  input rst_n,
  input start,
  input [7:0][15:0] data_in,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SCAN,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] ptr;
  reg [15:0] first_even, first_odd;
  reg [15:0] product;
  reg [3:0] cycle_count;

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      ptr <= 0;
      first_even <= -1;
      first_odd <= -1;
      product <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SCAN;
      end
      SCAN: begin
        if (ptr == 7) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (cycle_count == 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ptr <= 0;
      first_even <= -1;
      first_odd <= -1;
      product <= 0;
      cycle_count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          ptr <= 0;
          first_even <= -1;
          first_odd <= -1;
          product <= 0;
          cycle_count <= 0;
          result <= 0;
          done <= 0;
        end
        SCAN: begin
          if (ptr < 8) begin
            if (first_even == -1 && data_in[ptr][0] == 0) begin
              first_even <= data_in[ptr];
            end
            if (first_odd == -1 && data_in[ptr][0] == 1) begin
              first_odd <= data_in[ptr];
            end
            ptr <= ptr + 1;
          end
        end
        COMPUTE: begin
          if (cycle_count == 0) begin
            if (first_even == -1 || first_odd == -1) begin
              product <= -1;
            end else begin
              product <= first_even * first_odd;
            end
            cycle_count <= cycle_count + 1;
          end else if (cycle_count == 1) begin
            result <= product;
            cycle_count <= cycle_count + 1;
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule