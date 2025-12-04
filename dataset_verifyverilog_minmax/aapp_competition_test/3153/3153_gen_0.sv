module purchase_outcome_decoder(
  input clk,
  input rst_n, // active-low reset
  input start, // start computation
  input [3:0][15:0] child_count, // 4 children's final counts (index 0-3)
  input [2:0] purchase_count, // number of purchases (0-5)
  input [5:0][1:0][1:0] purchase_pairs, // max 6 purchases [purchase][0/1] = child_id (2-bit)

  output reg [5:0][1:0] outcome, // outcome per purchase (0/1/2)
  output reg done // high when computation complete
);

  typedef enum logic { IDLE = 1'b0, RUN = 1'b1 } state_t;
  state_t state;

  reg [2:0] idx;          // current purchase index being computed
  reg [2:0] count;        // latched purchase count
  reg [5:0][1:0][1:0] pppairs; // latched purchase pairs

  // Compute outcome for the purchase pointed to by idx
  logic [1:0] next_outcome;
  logic [15:0] cur_a, cur_b;
  logic [15:0] required_a, required_b;
  logic [1:0] child_a, child_b;

  always_comb begin
    child_a = pppairs[idx][0];
    child_b = pppairs[idx][1];
    case (child_a)
      2'b00: cur_a = outcome[0][1:0];
      2'b01: cur_a = outcome[1][1:0];
      2'b10: cur_a = outcome[2][1:0];
      default: cur_a = 3'b0;
    endcase
    case (child_b)
      2'b00: cur_b = outcome[0][1:0];
      2'b01: cur_b = outcome[1][1:0];
      2'b10: cur_b = outcome[2][1:0];
      default: cur_b = 3'b0;
    endcase
    required_a = child_count[child_a] - cur_a;
    required_b = child_count[child_b] - cur_b;
    if (required_a > required_b || (required_a == required_b && child_a < child_b)) begin
      next_outcome = 2'd2;
    end else if (required_b > required_a) begin
      next_outcome = 2'd0;
    end else begin
      next_outcome = 2'd1;
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      idx <= 3'd0;
      count <= 3'd0;
      pppairs <= 6'(0);
      outcome <= 6'(0);
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          idx <= 3'd0;
          outcome <= 6'(0);
          done <= 1'b0;
          if (start) begin
            state <= RUN;
            count <= purchase_count;
            pppairs <= purchase_pairs;
          end
        end

        RUN: begin
          if (idx < count) begin
            outcome[idx] <= next_outcome;
            idx <= idx + 1;
            done <= 1'b0;
          end else begin
            // All purchases processed; hold final outcomes and assert done
            outcome <= outcome;
            idx <= idx;
            done <= 1'b1;
          end
        end
      endcase
    end
  end
endmodule