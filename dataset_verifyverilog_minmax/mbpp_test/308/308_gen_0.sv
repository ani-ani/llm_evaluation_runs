module top_n_products (
  input clk,
  input rst_n,
  input start,
  input [7:0] list1 [0:5],
  input [7:0] list2 [0:5],
  input [2:0] N,
  output reg [15:0] products [0:4],
  output reg done
);

  // FSM state encoding
  localparam IDLE   = 2'b00;
  localparam COMPUTE= 2'b01;
  localparam SORT   = 2'b10;
  localparam DONE   = 2'b11;

  // Internal signals
  reg [1:0] state, next_state;
  reg [5:0] prod_idx;         // 0..35
  reg [15:0] prod_arr [0:35]; // all 36 products
  reg [35:0] mask;            // selected products mask
  reg [2:0] select_cnt;       // how many top products selected
  reg [5:0] max_idx;          // index of current max in selection sort
  reg [15:0] curr_max;        // value of current max
  reg [2:0] N_reg;            // registered N (safe against changes mid-run)

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // N registration (capture when entering SORT or DONE from IDLE)
  always @(posedge clk) begin
    if (state == IDLE) begin
      N_reg <= N;
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE:   next_state = (start) ? COMPUTE : IDLE;
      COMPUTE: next_state = (prod_idx == 6'd36) ? SORT : COMPUTE;
      SORT:   next_state = (select_cnt == (N_reg > 3'd5 ? 3'd5 : N_reg)) ? DONE : SORT;
      DONE:   next_state = (start) ? DONE : IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Outputs/control signals
  always @(*) begin
    done = (state == DONE);
  end

  // Compute all 36 products (6x6)
  always @(posedge clk) begin
    if (state == IDLE) begin
      prod_idx <= 6'd0;
    end else if (state == COMPUTE) begin
      // Compute product for current indices
      prod_arr[prod_idx] <= $unsigned(list1[prod_idx / 6]) * $unsigned(list2[prod_idx % 6]);
      prod_idx <= prod_idx + 1;
    end else if (state == SORT || state == DONE) begin
      // keep stable during sorting/done
      prod_idx <= 6'd0;
    end
  end

  // Sorting: iterative selection of top-N
  always @(posedge clk) begin
    if (state == IDLE) begin
      mask <= 36'h0;
      select_cnt <= 3'd0;
      max_idx <= 6'd0;
      curr_max <= 16'd0;
    end else if (state == SORT) begin
      // Selection sort for the next best product
      if (select_cnt == (N_reg > 3'd5 ? 3'd5 : N_reg)) begin
        // already have N top products
        max_idx <= 6'd0;
        curr_max <= 16'd0;
      end else begin
        // find max among unselected products
        if (select_cnt == 3'd0) begin
          // initialize for first selection
          max_idx <= 6'd0;
          curr_max <= prod_arr[0];
        end
        // Scan all 36 products
        for (int k = 0; k < 36; k = k + 1) begin
          if (!mask[k]) begin
            if (prod_arr[k] > curr_max) begin
              curr_max <= prod_arr[k];
              max_idx <= k[5:0];
            end
          end
        end
        // One selection per SORT cycle
        mask[max_idx] <= 1'b1;
        select_cnt <= select_cnt + 1;
        products[select_cnt] <= curr_max;
      end
    end else if (state == DONE) begin
      // No-op; outputs already valid
    end
  end

  // Zero remaining product output slots (if N < 5)
  integer s, t;
  always @(posedge clk) begin
    if (state == IDLE) begin
      for (t = 0; t < 5; t = t + 1) begin
        products[t] <= 16'd0;
      end
    end else if (state == SORT) begin
      // Fill subsequent slots as selections complete
      for (s = 0; s < 5; s = s + 1) begin
        if (s >= (N_reg > 3'd5 ? 3'd5 : N_reg)) begin
          products[s] <= 16'd0;
        end
      end
    end else if (state == DONE) begin
      // Keep final outputs stable
    end
  end

endmodule
