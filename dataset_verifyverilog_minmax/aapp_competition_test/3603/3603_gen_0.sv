module translator_pairing(
  input clk, // clock signal
  input rst_n, // active-low reset (asynchronous)
  input start, // pulse high to begin computation
  input [2:0] M, // number of translators (3-bit, 0-7 values)
  input [2:0] N, // number of languages (3-bit, 1-7 values)
  input [2:0] lang1 [0:7], // 8-element array of first languages
  input [2:0] lang2 [0:7], // 8-element array of second languages
  output reg [2:0] pair1, // first translator in pair
  output reg [2:0] pair2, // second translator in pair
  output reg done, // high when pairing is complete
  output reg impossible // high when no pairing exists
);

  // State parameters
  parameter IDLE = 3'd0;
  parameter CHECK_PAIRS = 3'd1;
  parameter FIND_I = 3'd2;
  parameter FIND_PARTNER = 3'd3;
  parameter OUTPUT_PAIR = 3'd4;
  parameter IMPOSSIBLE = 3'd5;
  parameter DONE = 3'd6;

  // State variables
  reg [2:0] state;
  reg [7:0] paired_mask; // bit k set if translator k is paired
  reg [2:0] current_i; // current translator i being paired
  reg [2:0] current_j; // current partner j being considered
  reg [2:0] pair_count; // number of pairs found
  reg [2:0] M_hold; // hold M when start is pulsed

  // Function to find first unpaired translator
  function [2:0] find_first_unpaired;
    input [7:0] mask;
    integer k;
    begin
      for (k = 0; k < 8; k = k + 1) begin
        if (mask[k] == 1'b0) begin
          find_first_unpaired = k;
          return;
        end
      end
      find_first_unpaired = 3'd0; // default, should not happen
    end
  endfunction

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      paired_mask <= 8'b0;
      current_i <= 3'b0;
      current_j <= 3'b0;
      pair_count <= 3'b0;
      M_hold <= 3'b0;
      pair1 <= 3'b0;
      pair2 <= 3'b0;
      done <= 1'b0;
      impossible <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            M_hold <= M;
            if (M[0] == 1'b1) begin // M is odd
              state <= IMPOSSIBLE;
            end else begin
              state <= CHECK_PAIRS;
              paired_mask <= 8'b0;
              pair_count <= 3'b0;
            end
          end
        end

        CHECK_PAIRS: begin
          done <= 1'b0;
          impossible <= 1'b0;
          if (pair_count == (M_hold >> 1)) begin // M_hold / 2
            state <= DONE;
          end else begin
            state <= FIND_I;
          end
        end

        FIND_I: begin
          done <= 1'b0;
          impossible <= 1'b0;
          current_i <= find_first_unpaired(paired_mask);
          current_j <= 3'b0;
          state <= FIND_PARTNER;
        end

        FIND_PARTNER: begin
          done <= 1'b0;
          impossible <= 1'b0;
          if (current_j > 3'd7) begin
            state <= IMPOSSIBLE;
          end else begin
            if (current_j != current_i && paired_mask[current_j] == 1'b0) begin
              if (lang1[current_i] == lang1[current_j] ||
                  lang1[current_i] == lang2[current_j] ||
                  lang2[current_i] == lang1[current_j] ||
                  lang2[current_i] == lang2[current_j]) begin
                state <= OUTPUT_PAIR;
              end else begin
                current_j <= current_j + 1;
              end
            end else begin
              current_j <= current_j + 1;
            end
          end
        end

        OUTPUT_PAIR: begin
          done <= 1'b1;
          impossible <= 1'b0;
          pair1 <= current_i;
          pair2 <= current_j;
          paired_mask[current_i] <= 1'b1;
          paired_mask[current_j] <= 1'b1;
          pair_count <= pair_count + 1;
          state <= CHECK_PAIRS;
        end

        IMPOSSIBLE: begin
          done <= 1'b0;
          impossible <= 1'b1;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b0;
          impossible <= 1'b0;
          if (start) begin
            state <= IDLE;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule