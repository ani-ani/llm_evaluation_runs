module jon_snow_rangers(
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [9:0] x,
  input [9:0] a0, a1, a2, a3, a4, a5, a6, a7,
  output reg [9:0] max_strength,
  output reg [9:0] min_strength,
  output reg done
);

  typedef enum logic [1:0] { IDLE, PROCESSING, FINAL_CALC, DONE } state_t;
  state_t state;

  reg [9:0] strength [0:7];
  reg [9:0] modified [0:7];
  reg [9:0] sorted [0:7];
  reg [3:0] op_count;

  function automatic void compare_and_swap(ref logic [9:0] a, ref logic [9:0] b);
    logic [9:0] tmp;
    if (a > b) begin
      tmp = a;
      a = b;
      b = tmp;
    end
  endfunction

  function automatic void sort_8_elements(ref logic [9:0] arr[0:7]);
    compare_and_swap(arr[0], arr[1]);
    compare_and_swap(arr[2], arr[3]);
    compare_and_swap(arr[4], arr[5]);
    compare_and_swap(arr[6], arr[7]);
    compare_and_swap(arr[0], arr[2]);
    compare_and_swap(arr[1], arr[3]);
    compare_and_swap(arr[4], arr[6]);
    compare_and_swap(arr[5], arr[7]);
    compare_and_swap(arr[1], arr[2]);
    compare_and_swap(arr[5], arr[6]);
    compare_and_swap(arr[0], arr[4]);
    compare_and_swap(arr[3], arr[7]);
    compare_and_swap(arr[1], arr[5]);
    compare_and_swap(arr[2], arr[6]);
    compare_and_swap(arr[1], arr[4]);
    compare_and_swap(arr[3], arr[6]);
    compare_and_swap(arr[2], arr[4]);
    compare_and_swap(arr[3], arr[5]);
    compare_and_swap(arr[3], arr[4]);
  endfunction

  always_comb begin
    automatic logic [9:0] temp [0:7] = strength;
    sort_8_elements(temp);
    sorted = temp;
  end

  always_comb begin
    modified = sorted;
    modified[0] = sorted[0] ^ x;
    modified[2] = sorted[2] ^ x;
    modified[4] = sorted[4] ^ x;
    modified[6] = sorted[6] ^ x;
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      max_strength <= 10'b0;
      min_strength <= 10'b0;
      foreach (strength[i]) strength[i] <= 10'b0;
      op_count <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= PROCESSING;
            op_count <= 4'b0;
          end
        end

        PROCESSING: begin
          if (op_count == 0) begin
            strength[0] <= a0;
            strength[1] <= a1;
            strength[2] <= a2;
            strength[3] <= a3;
            strength[4] <= a4;
            strength[5] <= a5;
            strength[6] <= a6;
            strength[7] <= a7;
            op_count <= op_count + 4'b1;
          end else if (op_count <= k) begin
            strength <= modified;
            op_count <= op_count + 4'b1;
          end else begin
            state <= FINAL_CALC;
          end
        end

        FINAL_CALC: begin
          min_strength <= strength[0];
          max_strength <= strength[0];
          for (int i = 1; i < 8; i++) begin
            if (strength[i] < min_strength) min_strength <= strength[i];
            if (strength[i] > max_strength) max_strength <= strength[i];
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule