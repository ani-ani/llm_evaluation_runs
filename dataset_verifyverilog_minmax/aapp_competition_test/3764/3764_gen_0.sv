module jon_snow_rangers(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // init computation
  input [3:0] k, // operations count (0-15)
  input [9:0] x, // XOR value (0-1023)
  input [9:0] a0, a1, a2, a3, a4, a5, a6, a7, // ranger strengths (max 8 rangers)
  output reg [9:0] max_strength, // maximum strength
  output reg [9:0] min_strength, // minimum strength
  output reg done // high when results valid
);

  // State definitions
  localparam IDLE = 2'b00;
  localparam PROCESSING = 2'b01;
  localparam FINAL_CALC = 2'b10;
  localparam DONE = 2'b11;

  // Internal signals
  reg [1:0] state, next_state;
  reg [3:0] op_count;
  reg [9:0] strengths [7:0];
  reg [9:0] sorted_strengths [7:0];
  reg [9:0] next_strengths [7:0];
  reg load_done;

  // FSM state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start) next_state = PROCESSING;
        else next_state = IDLE;
      end
      PROCESSING: begin
        if (op_count == k) next_state = FINAL_CALC;
        else next_state = PROCESSING;
      end
      FINAL_CALC: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Operation counter and load logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      op_count <= 4'd0;
      load_done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          op_count <= 4'd0;
          load_done <= 1'b0;
        end
        PROCESSING: begin
          if (load_done) begin
            op_count <= op_count + 1;
          end else begin
            load_done <= 1'b1;
          end
        end
        FINAL_CALC: begin
          op_count <= op_count;
        end
        DONE: begin
          op_count <= 4'd0;
        end
      endcase
    end
  end

  // Load initial strengths
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      strengths[0] <= 10'd0;
      strengths[1] <= 10'd0;
      strengths[2] <= 10'd0;
      strengths[3] <= 10'd0;
      strengths[4] <= 10'd0;
      strengths[5] <= 10'd0;
      strengths[6] <= 10'd0;
      strengths[7] <= 10'd0;
    end else begin
      if (state == IDLE && start) begin
        strengths[0] <= a0;
        strengths[1] <= a1;
        strengths[2] <= a2;
        strengths[3] <= a3;
        strengths[4] <= a4;
        strengths[5] <= a5;
        strengths[6] <= a6;
        strengths[7] <= a7;
      end else if (state == PROCESSING && load_done) begin
        strengths[0] <= next_strengths[0];
        strengths[1] <= next_strengths[1];
        strengths[2] <= next_strengths[2];
        strengths[3] <= next_strengths[3];
        strengths[4] <= next_strengths[4];
        strengths[5] <= next_strengths[5];
        strengths[6] <= next_strengths[6];
        strengths[7] <= next_strengths[7];
      end
    end
  end

  // Sorting and XOR processing (parallel for each operation)
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : sort_xor
      always @(*) begin
        // First pass: sort adjacent pairs
        if (i % 2 == 0) begin
          if (i < 7) begin
            if (strengths[i] <= strengths[i+1]) begin
              sorted_strengths[i] = strengths[i];
              sorted_strengths[i+1] = strengths[i+1];
            end else begin
              sorted_strengths[i] = strengths[i+1];
              sorted_strengths[i+1] = strengths[i];
            end
          end else begin
            sorted_strengths[i] = strengths[i];
          end
        end else begin
          if (i < 7) begin
            if (strengths[i] <= strengths[i+1]) begin
              sorted_strengths[i] = strengths[i];
              sorted_strengths[i+1] = strengths[i+1];
            end else begin
              sorted_strengths[i] = strengths[i+1];
              sorted_strengths[i+1] = strengths[i];
            end
          end else begin
            sorted_strengths[i] = strengths[i];
          end
        end
      end
    end
  endgenerate

  // Second pass sorting and XOR application
  always @(*) begin
    // Apply XOR to alternate elements (0, 2, 4, 6) from sorted array
    for (int j = 0; j < 8; j = j + 1) begin
      if (j % 2 == 0) begin
        next_strengths[j] = sorted_strengths[j] ^ x;
      end else begin
        next_strengths[j] = sorted_strengths[j];
      end
    end
  end

  // Final max/min calculation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_strength <= 10'd0;
      min_strength <= 10'd0;
      done <= 1'b0;
    end else begin
      case (state)
        FINAL_CALC: begin
          max_strength <= strengths[7]; // After sorting, index 7 has max
          min_strength <= strengths[0]; // After sorting, index 0 has min
          done <= 1'b1;
        end
        DONE: begin
          done <= 1'b0;
        end
        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule