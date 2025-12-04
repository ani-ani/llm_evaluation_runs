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
  
  typedef enum {IDLE, SORT, DONE} state_t;
  state_t state;
  
  logic [15:0] products_all_comb [0:35];
  reg [15:0] products_all_reg [0:35];
  reg [6:0] sort_cycles;
  reg is_odd_phase;
  
  // Compute all 36 products combinatorially
  always_comb begin
    for (int i=0; i<6; i++) begin
      for (int j=0; j<6; j++) begin
        products_all_comb[i*6 + j] = list1[i] * list2[j];
      end
    end
  end
  
  // Next products sorting logic
  logic [15:0] next_products [0:35];
  always_comb begin
    next_products = products_all_reg;
    if (state == SORT) begin
      if (is_odd_phase) begin
        // Odd phase
        for (int i=1; i<=33; i=i+2) begin
          if (next_products[i] < next_products[i+1]) begin
            automatic logic [15:0] temp = next_products[i];
            next_products[i] = next_products[i+1];
            next_products[i+1] = temp;
          end
        end
      end else begin
        // Even phase
        for (int i=0; i<=34; i=i+2) begin
          if (next_products[i] < next_products[i+1]) begin
            automatic logic [15:0] temp = next_products[i];
            next_products[i] = next_products[i+1];
            next_products[i+1] = temp;
          end
        end
      end
    end
  end
  
  // State machine and registers
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      state <= IDLE;
      sort_cycles <= 7'b0;
      is_odd_phase <= 1'b0;
      foreach (products_all_reg[i]) products_all_reg[i] <= 16'b0;
      foreach (products[i]) products[i] <= 16'b0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            state <= SORT;
            products_all_reg <= products_all_comb;
            sort_cycles <= 7'b0;
            is_odd_phase <= 1'b0;
          end
        end
        SORT: begin
          products_all_reg <= next_products;
          is_odd_phase <= ~is_odd_phase;
          sort_cycles <= sort_cycles + 1;
          if (sort_cycles == 7'd71) begin
            state <= DONE;
          end
        end
        DONE: begin
          for (int k=0; k<5; k++) begin
            products[k] <= (k < N) ? products_all_reg[k] : 16'b0;
          end
          done <= 1'b1;
          state <= IDLE;
        end
        default: begin
          state <= IDLE;
        end
      endcase
    end
  end
endmodule