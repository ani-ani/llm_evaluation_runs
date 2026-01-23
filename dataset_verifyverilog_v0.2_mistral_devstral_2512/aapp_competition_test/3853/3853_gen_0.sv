module magic_boxes (
  input clk,
  input rst_n,
  input start,
  input [4:0] k_in,
  input [19:0] a_in,
  input [1:0] type_index,
  input valid_in,
  output reg [5:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    CAPTURE,
    COMPUTE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers for storing box data
  reg [4:0] k_reg [0:3];
  reg [19:0] a_reg [0:3];
  reg [1:0] capture_count;
  reg [5:0] max_p;
  reg [1:0] compute_index;

  // Compute ceil(log4(a))
  function logic [3:0] compute_log4;
    input [19:0] a;
    begin
      if (a <= 1) begin
        compute_log4 = 4'd0;
      end else if (a <= 4) begin
        compute_log4 = 4'd1;
      end else if (a <= 16) begin
        compute_log4 = 4'd2;
      end else if (a <= 64) begin
        compute_log4 = 4'd3;
      end else if (a <= 256) begin
        compute_log4 = 4'd4;
      end else if (a <= 1024) begin
        compute_log4 = 4'd5;
      end else if (a <= 4096) begin
        compute_log4 = 4'd6;
      end else if (a <= 16384) begin
        compute_log4 = 4'd7;
      end else if (a <= 65536) begin
        compute_log4 = 4'd8;
      end else if (a <= 262144) begin
        compute_log4 = 4'd9;
      end else begin
        compute_log4 = 4'd10;
      end
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      capture_count <= 2'd0;
      compute_index <= 2'd0;
      max_p <= 6'd0;
      result <= 6'd0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = CAPTURE;
      end
      CAPTURE: begin
        if (capture_count == 2'd3 && valid_in) next_state = COMPUTE;
      end
      COMPUTE: begin
        if (compute_index == 2'd3) next_state = DONE;
      end
      DONE: begin
        if (start) next_state = CAPTURE;
      end
    endcase
  end

  // Capture state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      capture_count <= 2'd0;
    end else if (current_state == CAPTURE && valid_in) begin
      k_reg[type_index] <= k_in;
      a_reg[type_index] <= a_in;
      if (type_index == 2'd3) begin
        capture_count <= 2'd0;
      end else begin
        capture_count <= capture_count + 1'b1;
      end
    end
  end

  // Compute state logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compute_index <= 2'd0;
      max_p <= 6'd0;
    end else if (current_state == COMPUTE) begin
      if (compute_index == 2'd0) begin
        max_p <= 6'd0;
      end
      if (compute_index < 2'd4) begin
        logic [3:0] log4_val = compute_log4(a_reg[compute_index]);
        logic [5:0] p_val = k_reg[compute_index] + log4_val;
        if (p_val > max_p) begin
          max_p <= p_val;
        end
        compute_index <= compute_index + 1'b1;
      end
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 6'd0;
      done <= 1'b0;
    end else begin
      if (current_state == DONE) begin
        result <= max_p;
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule