module alice_bob_meet(
  input clk,
  input rst_n,
  input start,
  input [15:0] adjacency,
  input [1:0] alice_start,
  input [1:0] bob_start,
  output reg [31:0] expected_time,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    INIT,
    CALCULATE,
    FINISH
  } state_t;

  state_t current_state, next_state;
  reg [31:0] P_A [0:3][0:3];
  reg [31:0] P_B [0:3][0:3];
  reg [31:0] E_current [0:15];
  reg [31:0] E_next [0:15];
  reg [3:0] iter;
  reg error_flag;
  wire [3:0] counts [0:3];

  always_comb begin
    for (int i=0; i<4; i++) begin
      counts[i] = 
        adjacency[i*4+0] + adjacency[i*4+1] + adjacency[i*4+2] + adjacency[i*4+3];
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      done <= 0;
      expected_time <= 32'h0;
      error_flag <= 0;
      iter <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done <= 0;
          error_flag <= 0;
          iter <= 0;
        end
        INIT: begin
          error_flag <= (counts[0] == 0) || (counts[1] == 0) || (counts[2] == 0) || (counts[3] == 0);
        end
        CALCULATE: begin
          E_current <= E_next;
          iter <= iter + 1;
        end
        FINISH: begin
          done <= 1;
          expected_time <= error_flag ? 32'hFFFFFFFF : E_current[{alice_start, bob_start}];
        end
      endcase
    end
  end

  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = CALCULATE;
      CALCULATE: next_state = (iter == 15) ? FINISH : CALCULATE;
      FINISH: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Transition probability calculation
  always_comb begin
    for (int i=0; i<4; i++) begin
      for (int j=0; j<4; j++) begin
        if (current_state == INIT) begin
          if (counts[i] > 0 && adjacency[i*4 + j]) begin
            unique case (counts[i])
              1: {P_A[i][j], P_B[i][j]} = {32'h00010000, 32'h00010000};
              2: {P_A[i][j], P_B[i][j]} = {32'h00008000, 32'h00008000};
              3: {P_A[i][j], P_B[i][j]} = {32'h00005555, 32'h00005555};
              4: {P_A[i][j], P_B[i][j]} = {32'h00004000, 32'h00004000};
              default: {P_A[i][j], P_B[i][j]} = {32'h0, 32'h0};
            endcase
          end else begin
            {P_A[i][j], P_B[i][j]} = {32'h0, 32'h0};
          end
        end
      end
    end
  end

  // Initial E values
  always_comb begin
    if (current_state == INIT) begin
      for (int s=0; s<16; s++) begin
        logic [1:0] i = s[3:2];
        logic [1:0] j = s[1:0];
        E_current[s] = (i == j) ? 32'h0 : 32'h00010000;
      end
    end
  end

  // E_next calculation
  always_comb begin
    for (int s=0; s<16; s++) begin
      logic [1:0] i = s[3:2];
      logic [1:0] j = s[1:0];
      logic [31:0] sum = 0;

      for (int k=0; k<4; k++) begin
        for (int l=0; l<4; l++) begin
          if (current_state == CALCULATE && i != j) begin
            logic [63:0] prod1 = P_A[i][k] * P_B[j][l];
            logic [95:0] prod2 = prod1 * E_current[{k,l}];
            logic [31:0] truncated = prod2[63:32];
            sum = sum + truncated;
          end
        end
      end

      if (current_state == CALCULATE) begin
        E_next[s] = (i == j) ? 32'h0 : (32'h00010000 + sum);
      end
    end
  end
endmodule