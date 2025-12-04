module unique_product (
  input clk,
  input rst_n,
  input start,
  input [3:0] data_in,
  input data_valid,
  output reg [31:0] product,
  output reg done
);

  typedef enum logic [1:0] { IDLE = 2'b00, COLLECT = 2'b01, CALCULATE = 2'b10, DONE = 2'b11 } state_t;
  state_t state, next_state;

  logic [3:0] uniq_mem [0:7];
  logic [7:0] uniq_count;
  logic seen_mask [0:15];
  logic last_data_valid;

  // State register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Determine last data valid (end of stream) in COLLECT state
  always_latch begin
    if (state != COLLECT) begin
      last_data_valid = 1'b0;
    end else begin
      if (!data_valid) last_data_valid = 1'b1;
    end
  end

  // State transitions
  always_comb begin
    next_state = state;
    case (state)
      IDLE:    next_state = start ? COLLECT : IDLE;
      COLLECT: next_state = last_data_valid ? CALCULATE : COLLECT;
      CALCULATE: next_state = DONE;
      DONE:     next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Control/memory updates
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      uniq_count <= 8'd0;
      for (int i = 0; i < 16; i++) seen_mask[i] <= 1'b0;
      for (int i = 0; i < 8; i++) uniq_mem[i] <= 4'd0;
    end else begin
      if (state == IDLE) begin
        uniq_count <= 8'd0;
        for (int i = 0; i < 16; i++) seen_mask[i] <= 1'b0;
        for (int i = 0; i < 8; i++) uniq_mem[i] <= 4'd0;
      end else if (state == COLLECT && data_valid) begin
        if (uniq_count < 8 && !seen_mask[data_in]) begin
          uniq_mem[uniq_count] <= data_in;
          uniq_count <= uniq_count + 1;
          seen_mask[data_in] <= 1'b1;
        end
      end
    end
  end

  // Combinational product of unique numbers
  always_comb begin
    if (uniq_count == 0) product = 32'd1;
    else begin
      product = 32'd1;
      for (int i = 0; i < 8; i++) begin
        if (i < uniq_count) product = product * {28'd0, uniq_mem[i]};
      end
    end
  end

  // Done pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) done <= 1'b0;
    else done <= (state == DONE);
  end

endmodule
