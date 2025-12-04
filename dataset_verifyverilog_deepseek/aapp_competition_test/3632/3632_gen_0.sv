module composite_string_position(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [1:0] k,
  input [7:0][31:0] sorted_strings, // unused
  input [3:0][2:0] test_indices,
  output reg [15:0] position,
  output reg done
);

  // Internal registers
  reg [2:0] n_reg;
  reg [1:0] k_reg;
  reg [3:0][2:0] test_indices_reg;
  reg [15:0] acc;
  reg [2:0] step_counter;
  reg [7:0] used_mask;
  reg computing;

  // Permutation function
  function automatic [15:0] Permutation(input [2:0] a, input [1:0] b);
    integer i;
    reg [15:0] res;
    begin
      if (a < b)
        Permutation = 0;
      else begin
        res = 1;
        for(i=0; i < b; i=i+1) begin
          res = res * (a - i);
        end
        Permutation = res;
      end
    end
  endfunction

  // Combinatorial signals for current step
  wire [2:0] current_test_index = test_indices_reg[step_counter];
  reg [3:0] count;
  integer j;
  wire [1:0] b_perm = k_reg - step_counter - 1;
  wire [2:0] a_perm = n_reg - step_counter - 1;
  wire [15:0] perm_value = Permutation(a_perm, b_perm);

  // Count logic
  always @(*) begin
    count = 0;
    for (j=0; j<8; j=j+1) begin
      if ( (j < n_reg) && (!used_mask[j]) && (j < current_test_index) )
        count = count + 1;
    end
  end

  // FSM logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      position <= 16'b0;
      computing <= 1'b0;
      acc <= 16'b0;
      used_mask <= 8'b0;
      step_counter <= 3'b0;
    end else begin
      if (start && !computing) begin
        n_reg <= n;
        k_reg <= k;
        test_indices_reg <= test_indices;
        computing <= 1'b1;
        done <= 1'b0;
        acc <= 0;
        used_mask <= 0;
        step_counter <= 0;
      end else if (computing) begin
        if (step_counter < k_reg) begin
          acc <= acc + count * perm_value;
          used_mask <= used_mask | (1 << current_test_index);
          step_counter <= step_counter + 1;
        end else begin
          position <= acc + 1;
          done <= 1'b1;
          computing <= 1'b0;
        end
      end
    end
  end

endmodule