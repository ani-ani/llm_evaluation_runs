module find_largest_d (
  input clk,
  input rst_n,
  input start,
  input [23:0] data_in,
  input [2:0] index,
  input write_en,
  output reg [23:0] result,
  output reg valid,
  output reg done
);

  // Internal state definitions
  typedef enum logic [2:0] {
    IDLE,
    WRITE_MODE,
    COMPUTE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers for storing 8 numbers
  reg signed [23:0] data [0:7];

  // Loop counters
  reg [2:0] i, j, k, l;
  reg [2:0] next_i, next_j, next_k, next_l;

  // Current max_d and valid flag
  reg signed [23:0] max_d;
  reg found_valid;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 24'b0;
      valid <= 1'b0;
      done <= 1'b0;
      i <= 3'b0;
      j <= 3'b0;
      k <= 3'b0;
      l <= 3'b0;
      max_d <= 24'b0;
      found_valid <= 1'b0;
    end else begin
      state <= next_state;
      i <= next_i;
      j <= next_j;
      k <= next_k;
      l <= next_l;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    next_i = i;
    next_j = j;
    next_k = k;
    next_l = l;

    case (state)
      IDLE: begin
        if (write_en) begin
          next_state = WRITE_MODE;
        end else if (start) begin
          next_state = COMPUTE;
          next_i = 3'b0;
          next_j = 3'b0;
          next_k = 3'b0;
          next_l = 3'b0;
          max_d = 24'b0;
          found_valid = 1'b0;
        end
      end

      WRITE_MODE: begin
        if (!write_en) begin
          next_state = IDLE;
        end
      end

      COMPUTE: begin
        // Check if current combination is valid
        if (i != j && i != k && i != l && 
            j != k && j != l && k != l &&
            data[i] + data[j] + data[k] == data[l]) begin
          if (data[l] > max_d) begin
            max_d = data[l];
            found_valid = 1'b1;
          end
        end

        // Increment counters
        if (l == 7) begin
          if (k == 7) begin
            if (j == 7) begin
              if (i == 7) begin
                next_state = DONE;
              end else begin
                next_i = i + 1;
                next_j = 3'b0;
                next_k = 3'b0;
                next_l = 3'b0;
              end
            end else begin
              next_j = j + 1;
              next_k = 3'b0;
              next_l = 3'b0;
            end
          end else begin
            next_k = k + 1;
            next_l = 3'b0;
          end
        end else begin
          next_l = l + 1;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Write data to internal registers
  always @(posedge clk) begin
    if (!rst_n) begin
      for (int idx = 0; idx < 8; idx = idx + 1) begin
        data[idx] <= 24'b0;
      end
    end else if (write_en && state == WRITE_MODE) begin
      data[index] <= data_in;
    end
  end

  // Output logic
  always @(*) begin
    result = 24'b0;
    valid = 1'b0;
    done = 1'b0;

    case (state)
      COMPUTE: done = 1'b0;
      DONE: begin
        done = 1'b1;
        if (found_valid) begin
          result = max_d;
          valid = 1'b1;
        end
      end
      default: begin
        done = 1'b0;
        valid = 1'b0;
      end
    endcase
  end

endmodule