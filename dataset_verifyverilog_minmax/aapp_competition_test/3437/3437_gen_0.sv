module max_tube_pairs (
  input clk,
  input rst_n,
  input start,
  input [13:0] L1,
  input [13:0] L2,
  input [7:0][13:0] tubes,
  output reg [15:0] max_total,
  output reg impossible,
  output reg done
);

  // State machine states
  typedef enum {IDLE, PIPE1, PIPE2, PIPE3, DONE} state_t;
  state_t state, next_state;

  // Internal registers to store tube values
  reg [13:0] tube_reg [0:7];
  
  // Precomputed combinations and splits
  // For simplicity, we will use a function to generate combinations (in practice, this would be hardcoded or generated at compile time)
  function [2:0] get_comb0 (input int idx);
    int i, j, k, m, count;
    count = 0;
    for (i = 0; i < 5; i++) begin
      for (j = i+1; j < 6; j++) begin
        for (k = j+1; k < 7; k++) begin
          for (m = k+1; m < 8; m++) begin
            if (count == idx) return i;
            count++;
          end
        end
      end
    end
    return 0; // default
  endfunction

  function [2:0] get_comb1 (input int idx);
    int i, j, k, m, count;
    count = 0;
    for (i = 0; i < 5; i++) begin
      for (j = i+1; j < 6; j++) begin
        for (k = j+1; k < 7; k++) begin
          for (m = k+1; m < 8; m++) begin
            if (count == idx) return j;
            count++;
          end
        end
      end
    end
    return 0;
  endfunction

  function [2:0] get_comb2 (input int idx);
    int i, j, k, m, count;
    count = 0;
    for (i = 0; i < 5; i++) begin
      for (j = i+1; j < 6; j++) begin
        for (k = j+1; k < 7; k++) begin
          for (m = k+1; m < 8; m++) begin
            if (count == idx) return k;
            count++;
          end
        end
      end
    end
    return 0;
  endfunction

  function [2:0] get_comb3 (input int idx);
    int i, j, k, m, count;
    count = 0;
    for (i = 0; i < 5; i++) begin
      for (j = i+1; j < 6; j++) begin
        for (k = j+1; k < 7; k++) begin
          for (m = k+1; m < 8; m++) begin
            if (count == idx) return m;
            count++;
          end
        end
      end
    end
    return 0;
  endfunction

  // Registers for Stage 1 (PIPE1)
  reg [13:0] total_sum_reg [0:69];
  reg [13:0] s1_reg [0:209];
  reg [13:0] s2_reg [0:209];
  
  // Registers for Stage 2 (PIPE2)
  reg valid_reg [0:209];
  reg [15:0] total_sum_check_reg [0:209];
  
  // Registers for Stage 3 (PIPE3) results
  reg [15:0] max_tree;
  reg valid_tree;

  // State machine next state logic
  always_comb begin
    case (state)
      IDLE: if (start) next_state = PIPE1; else next_state = IDLE;
      PIPE1: next_state = PIPE2;
      PIPE2: next_state = PIPE3;
      PIPE3: next_state = DONE;
      DONE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // State machine state register
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) state <= IDLE;
    else state <= next_state;
  end

  // Stage 1: Compute total sums and pair sums
  always_ff @(posedge clk) begin
    if (state == IDLE) begin
      if (start) begin
        // Store tube values
        for (int i = 0; i < 8; i++) begin
          tube_reg[i] <= tubes[i];
        end
      end
    end
    else if (state == PIPE1) begin
      // Compute total sums for all 70 combinations
      for (int j = 0; j < 70; j++) begin
        total_sum_reg[j] <= tube_reg[get_comb0(j)] + tube_reg[get_comb1(j)] + tube_reg[get_comb2(j)] + tube_reg[get_comb3(j)];
      end
      
      // Compute pair sums for all 210 checks (70 combinations * 3 splits)
      for (int k = 0; k < 210; k++) begin
        int j = k / 3;
        int i = k % 3;
        case (i)
          0: begin
            s1_reg[k] <= tube_reg[get_comb0(j)] + tube_reg[get_comb1(j)];
            s2_reg[k] <= tube_reg[get_comb2(j)] + tube_reg[get_comb3(j)];
          end
          1: begin
            s1_reg[k] <= tube_reg[get_comb0(j)] + tube_reg[get_comb2(j)];
            s2_reg[k] <= tube_reg[get_comb1(j)] + tube_reg[get_comb3(j)];
          end
          2: begin
            s1_reg[k] <= tube_reg[get_comb0(j)] + tube_reg[get_comb3(j)];
            s2_reg[k] <= tube_reg[get_comb1(j)] + tube_reg[get_comb2(j)];
          end
        endcase
      end
    end
  end

  // Stage 2: Validate pairs and collect total sums
  always_ff @(posedge clk) begin
    if (state == PIPE2) begin
      for (int k = 0; k < 210; k++) begin
        int j = k / 3;
        valid_reg[k] <= (s1_reg[k] <= L1) && (s2_reg[k] <= L2);
        total_sum_check_reg[k] <= total_sum_reg[j];
      end
    end
  end

  // Stage 3: Find maximum valid total sum using a linear scan
  always_comb begin
    max_tree = 16'h0;
    valid_tree = 1'b0;
    for (int k = 0; k < 210; k++) begin
      if (valid_reg[k]) begin
        if (valid_tree) begin
          if (total_sum_check_reg[k] > max_tree) begin
            max_tree = total_sum_check_reg[k];
          end
        end else begin
          max_tree = total_sum_check_reg[k];
        end
        valid_tree = 1'b1;
      end
    end
  end

  // Capture Stage 3 results and set done pulse
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      max_total <= 16'h0;
      impossible <= 1'b0;
      done <= 1'b0;
    end else begin
      if (state == PIPE3) begin
        max_total <= max_tree;
        impossible <= ~valid_tree;
        done <= 1'b0;
      end else if (state == DONE) begin
        done <= 1'b1;
      end else begin
        done <= 1'b0;
      end
    end
  end

endmodule