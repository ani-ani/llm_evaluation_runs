module translator_pairing(
  input clk,
  input rst_n,
  input start,
  input [2:0] M,
  input [2:0] N,
  input [2:0] lang1 [0:7],
  input [2:0] lang2 [0:7],
  output reg [2:0] pair1,
  output reg [2:0] pair2,
  output reg done,
  output reg impossible
);

  typedef enum logic [2:0] {IDLE, FIND_PAIRS, OUTPUT_PAIR, IMPOSSIBLE, DONE} state_t;
  state_t state;

  reg [7:0] paired_reg;
  wire m_odd = M[0];
  wire [7:0] mask = (1 << M) - 1;
  wire all_paired = (paired_reg & mask) == mask;

  // Combinational pair finding
  reg [2:0] found_i, found_j;
  reg found_pair;
  always_comb begin
    found_i = 3'b0;
    found_j = 3'b0;
    found_pair = 1'b0;
    for (int i = 0; i < 8; i++) begin
      if (i < M && !paired_reg[i]) begin
        for (int j = i+1; j < 8; j++) begin
          if (j < M && !paired_reg[j] && (lang1[i] == lang1[j] || lang1[i] == lang2[j] || lang2[i] == lang1[j] || lang2[i] == lang2[j])) begin
            found_i = i[2:0];
            found_j = j[2:0];
            found_pair = 1'b1;
            break;
          end
        end
        if (found_pair) break;
      end
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      pair1 <= 3'b0;
      pair2 <= 3'b0;
      done <= 1'b0;
      impossible <= 1'b0;
      paired_reg <= 8'b0;
    end else begin
      done <= 1'b0;
      impossible <= 1'b0;
      case (state)
        IDLE: begin
          paired_reg <= 8'b0;
          if (start) begin
            if (m_odd) state <= IMPOSSIBLE;
            else state <= FIND_PAIRS;
          end
        end

        FIND_PAIRS: begin
          if (all_paired) state <= DONE;
          else if (found_pair) state <= OUTPUT_PAIR;
          else state <= IMPOSSIBLE;
        end

        OUTPUT_PAIR: begin
          pair1 <= found_i;
          pair2 <= found_j;
          paired_reg[found_i] <= 1'b1;
          paired_reg[found_j] <= 1'b1;
          done <= 1'b1;
          state <= FIND_PAIRS;
        end

        IMPOSSIBLE: begin
          impossible <= 1'b1;
          state <= DONE;
        end

        DONE: state <= DONE;
      endcase
    end
  end

endmodule