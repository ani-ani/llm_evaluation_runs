module pita_pizza_calculator(
  input clk,
  input rst_n,
  input start,
  input [13:0] total_profit,
  input [9:0] pita_profit,
  input [9:0] pizza_profit,
  output reg [6:0] pita_count,
  output reg [6:0] pizza_count,
  output reg valid,
  output reg done
);

  // State encoding
  localparam IDLE  = 2'b00;
  localparam RUN   = 2'b01;
  localparam FINISH= 2'b10;

  reg [1:0] state, next_state;
  reg [6:0] pita_idx, next_pita_idx;

  // Internal signals for current computation
  reg [23:0] mult_pita_profit;
  reg [14:0] temp_ext;
  reg [13:0] temp;
  reg        temp_non_neg;
  reg [13:0] rem;
  reg [6:0]  pizza_q;
  reg        found;
  reg [6:0]  next_pita_count;
  reg [6:0]  next_pizza_count;
  reg        next_valid;
  reg        next_done;

  // Combinational logic
  always @* begin
    // Default assignments
    next_state       = state;
    next_pita_idx    = pita_idx;
    next_pita_count  = pita_count;
    next_pizza_count = pizza_count;
    next_valid       = 1'b0;
    next_done        = 1'b0;
    found            = 1'b0;

    // Default computation results
    mult_pita_profit = pita_idx * pita_profit; // up to 100*1000 = 100000 (< 17 bits)

    // temp = total_profit - mult_pita_profit (handle potential negative via extended width)
    // Use 15-bit signed-style comparison via explicit check
    if (total_profit >= mult_pita_profit[13:0]) begin
      temp_ext      = {1'b0, total_profit} - {1'b0, mult_pita_profit[13:0]};
      temp_non_neg  = 1'b1;
      temp          = temp_ext[13:0];
    end else begin
      temp_ext      = 15'd0;
      temp_non_neg  = 1'b0;
      temp          = 14'd0;
    end

    // Division and modulo only used when pizza_profit != 0 and temp_non_neg
    rem      = 14'd0;
    pizza_q  = 7'd0;
    if (temp_non_neg && (pizza_profit != 0)) begin
      rem     = temp % pizza_profit;
      pizza_q = temp / pizza_profit;
    end

    // State machine
    case (state)
      IDLE: begin
        if (start) begin
          next_pita_idx = 7'd0;
          next_state    = RUN;
        end
      end

      RUN: begin
        // Check current pita_idx combination
        if (temp_non_neg && (pizza_profit != 0) && (rem == 0) && (pizza_q <= 7'd100)) begin
          found            = 1'b1;
          next_pita_count  = pita_idx;
          next_pizza_count = pizza_q;
          next_valid       = 1'b1;
        end

        // Move to next pita index or finish
        if (pita_idx == 7'd100) begin
          // Last index processed, go to FINISH next cycle
          next_state    = FINISH;
          next_pita_idx = pita_idx; // hold
        end else begin
          next_pita_idx = pita_idx + 7'd1;
          next_state    = RUN;
        end
      end

      FINISH: begin
        // Signal done high (one or more cycles until next start)
        next_done = 1'b1;
        if (start) begin
          // Restart search
          next_pita_idx = 7'd0;
          next_state    = RUN;
          next_done     = 1'b0;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      pita_idx    <= 7'd0;
      pita_count  <= 7'd0;
      pizza_count <= 7'd0;
      valid       <= 1'b0;
      done        <= 1'b0;
    end else begin
      state       <= next_state;
      pita_idx    <= next_pita_idx;
      pita_count  <= next_pita_count;
      pizza_count <= next_pizza_count;
      valid       <= next_valid;
      done        <= next_done;
    end
  end

endmodule