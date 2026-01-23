module odd_xor_pairs (
  input [7:0] data_i,
  input [2:0] idx,
  input valid,
  input done,
  input clk,
  input reset,
  output reg [7:0] result,
  output reg ready
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    COLLECTING,
    COMPUTING,
    DONE
  } state_t;

  state_t state, next_state;
  reg [2:0] odd_count, even_count;
  reg [7:0] product;

  // State transition logic
  always @(posedge clk or posedge reset) begin
    if (reset) begin
      state <= IDLE;
      odd_count <= 0;
      even_count <= 0;
      product <= 0;
      result <= 0;
      ready <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (valid) next_state = COLLECTING;
      end
      COLLECTING: begin
        if (done) next_state = COMPUTING;
        else if (valid) next_state = COLLECTING;
      end
      COMPUTING: next_state = DONE;
      DONE: begin
        if (reset) next_state = IDLE;
      end
    endcase
  end

  // Count accumulation logic
  always @(posedge clk) begin
    if (reset) begin
      odd_count <= 0;
      even_count <= 0;
    end else if (state == COLLECTING && valid) begin
      if (data_i[0]) odd_count <= odd_count + 1;
      else even_count <= even_count + 1;
    end
  end

  // Multiplication logic (combinational)
  always @(*) begin
    if (state == COMPUTING) begin
      product = odd_count * even_count;
    end else begin
      product = 0;
    end
  end

  // Output logic
  always @(posedge clk) begin
    if (reset) begin
      result <= 0;
      ready <= 0;
    end else if (state == COMPUTING) begin
      result <= product;
      ready <= 0;
    end else if (state == DONE) begin
      ready <= 1;
    end else begin
      ready <= 0;
    end
  end

endmodule