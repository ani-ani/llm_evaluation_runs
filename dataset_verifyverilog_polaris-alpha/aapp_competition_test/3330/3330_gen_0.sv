module potato_store_optimizer(
  input        clk,
  input        rst_n,
  input        start,
  input  [2:0] N,
  input  [1:0] L,
  input  [3:0][7:0]  a,
  input  [3:0][19:0] c,
  output reg [31:0]  min_product,
  output reg         done
);

  // FSM States
  typedef enum logic [2:0] {
    S_IDLE      = 3'd0,
    S_INIT      = 3'd1,
    S_CHECK     = 3'd2,
    S_PREP_DIV1 = 3'd3,
    S_DIV1      = 3'd4,
    S_PREP_DIV2 = 3'd5,
    S_DIV2      = 3'd6,
    S_DONE      = 3'd7
  } state_t;

  state_t state, next_state;

  // Assignment enumeration
  reg [3:0] assign_mask;           // current assignment mask (up to 4 bags)
  reg [3:0] assign_next;
  reg [3:0] max_mask;              // (1<<N)-1

  // Totals for each store
  reg [4:0]  cnt1;                 // number of bags in store1 (0..4)
  reg [4:0]  cnt2;
  reg [11:0] pot1;                 // potatoes store1 (max 4*8 = 32)
  reg [11:0] pot2;
  reg [21:0] price1;               // price store1 (max 4*128 = 512)
  reg [21:0] price2;

  // Division engine (restoring integer division)
  // Computes (dividend / divisor) for 32-bit dividend, 12-bit divisor
  reg        div_busy;
  reg [31:0] div_dividend;
  reg [11:0] div_divisor;
  reg [31:0] div_quotient;
  reg [31:0] div_remainder;
  reg [5:0]  div_bit;              // up to 32 iterations

  // Captured averages (P1, P2)
  reg [31:0] P1;
  reg [31:0] P2;

  // Product
  reg [63:0] product;

  // Tracking
  reg [31:0] current_min;
  reg        min_valid;

  // Internal control
  reg start_pulse;
  reg start_d;

  //============================================================
  // Start pulse detect
  //============================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      start_d <= 1'b0;
    end else begin
      start_d <= start;
    end
  end
  assign start_pulse = start & ~start_d;

  //============================================================
  // FSM: State register
  //============================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
    end else begin
      state <= next_state;
    end
  end

  //============================================================
  // Combinational: Next state logic
  //============================================================
  always @* begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start_pulse) begin
          next_state = S_INIT;
        end
      end

      S_INIT: begin
        next_state = S_CHECK;
      end

      S_CHECK: begin
        // Determine if current assignment is valid; if so go to PREP_DIV1, else
        // either advance or finish.
        // Detailed control handled in sequential block; here keep as default.
        next_state = S_PREP_DIV1;
      end

      S_PREP_DIV1: begin
        next_state = S_DIV1;
      end

      S_DIV1: begin
        if (!div_busy)
          next_state = S_PREP_DIV2;
      end

      S_PREP_DIV2: begin
        next_state = S_DIV2;
      end

      S_DIV2: begin
        if (!div_busy)
          next_state = S_CHECK;
      end

      S_DONE: begin
        // One-cycle done; return to IDLE
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

  //============================================================
  // Division Engine (32-bit dividend / 12-bit divisor)
  // Restoring division, 32 cycles max
  //============================================================
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_busy     <= 1'b0;
      div_quotient <= 32'd0;
      div_remainder<= 32'd0;
      div_bit      <= 6'd0;
      div_dividend <= 32'd0;
      div_divisor  <= 12'd0;
    end else begin
      if (div_busy) begin
        // Shift left remainder, bring in next dividend bit
        div_remainder <= {div_remainder[30:0], div_dividend[31]};
        div_dividend  <= {div_dividend[30:0], 1'b0};

        // Compare and subtract
        if (div_remainder[31:20] >= div_divisor) begin
          div_remainder[31:20] <= div_remainder[31:20] - div_divisor;
          div_quotient <= {div_quotient[30:0], 1'b1};
        end else begin
          div_quotient <= {div_quotient[30:0], 1'b0};
        end

        // Next bit
        if (div_bit == 6'd31) begin
          div_busy <= 1'b0;
        end
        div_bit <= div_bit + 6'd1;
      end
    end
  end

  //============================================================
  // Main Sequential Logic
  //============================================================
  integer i;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      assign_mask  <= 4'd0;
      max_mask     <= 4'd0;
      cnt1         <= 5'd0;
      cnt2         <= 5'd0;
      pot1         <= 12'd0;
      pot2         <= 12'd0;
      price1       <= 22'd0;
      price2       <= 22'd0;
      P1           <= 32'd0;
      P2           <= 32'd0;
      product      <= 64'd0;
      current_min  <= 32'hFFFFFFFF;
      min_valid    <= 1'b0;
      done         <= 1'b0;
      min_product  <= 32'd0;
    end else begin
      done <= 1'b0; // default, unless asserted in S_DONE

      case (state)
        //------------------------------------------------------
        S_IDLE: begin
          // Wait for start; reset tracking
          if (start_pulse) begin
            current_min <= 32'hFFFFFFFF;
            min_valid   <= 1'b0;
          end
        end

        //------------------------------------------------------
        S_INIT: begin
          // Precompute max_mask = (1<<N) - 1
          max_mask <= (4'd1 << N) - 4'd1;
          assign_mask <= 4'd0;
          // Clear totals
          cnt1   <= 5'd0;
          cnt2   <= 5'd0;
          pot1   <= 12'd0;
          pot2   <= 12'd0;
          price1 <= 22'd0;
          price2 <= 22'd0;
        end

        //------------------------------------------------------
        S_CHECK: begin
          // If we've exhausted all assignments, we're done.
          if (assign_mask > max_mask) begin
            // Finalize result
            if (min_valid) begin
              min_product <= current_min;
            end else begin
              min_product <= 32'd0;
            end
            done <= 1'b1;
          end

          if (assign_mask > max_mask) begin
            // Move to S_DONE via FSM next_state
          end else begin
            // Compute counts and sums for current assignment
            cnt1   <= 5'd0;
            cnt2   <= 5'd0;
            pot1   <= 12'd0;
            pot2   <= 12'd0;
            price1 <= 22'd0;
            price2 <= 22'd0;

            for (i = 0; i < 4; i = i + 1) begin
              if (i < N) begin
                if (assign_mask[i]) begin
                  cnt1   <= cnt1   + 5'd1;
                  pot1   <= pot1   + a[i];
                  price1 <= price1 + c[i];
                end else begin
                  cnt2   <= cnt2   + 5'd1;
                  pot2   <= pot2   + a[i];
                  price2 <= price2 + c[i];
                end
              end
            end
          end
        end

        //------------------------------------------------------
        S_PREP_DIV1: begin
          if (assign_mask > max_mask) begin
            // No-op, FSM will move to S_DONE
          end else begin
            // Check validity: cnt1>=L and cnt2>=L
            if ((cnt1 >= L) && (cnt2 >= L) && (pot1 != 0) && (pot2 != 0)) begin
              // Start division for P1 = (price1<<16)/pot1
              div_dividend <= {price1, 16'd0};
              div_divisor  <= pot1;
              div_quotient <= 32'd0;
              div_remainder<= 32'd0;
              div_bit      <= 6'd0;
              div_busy     <= 1'b1;
            end else begin
              // Invalid assignment; skip to next mask
              if (assign_mask == max_mask) begin
                // All done
                min_product <= min_valid ? current_min : 32'd0;
                done        <= 1'b1;
              end
              assign_mask <= assign_mask + 4'd1;
            end
          end
        end

        //------------------------------------------------------
        S_DIV1: begin
          // Wait for division completion (div_busy cleared)
          if (!div_busy && (assign_mask <= max_mask) && (cnt1 >= L) && (cnt2 >= L) && (pot1 != 0) && (pot2 != 0)) begin
            P1 <= div_quotient;
          end
        end

        //------------------------------------------------------
        S_PREP_DIV2: begin
          if ((assign_mask <= max_mask) && (cnt1 >= L) && (cnt2 >= L) && (pot1 != 0) && (pot2 != 0)) begin
            // Start division for P2 = (price2<<16)/pot2
            div_dividend <= {price2, 16'd0};
            div_divisor  <= pot2;
            div_quotient <= 32'd0;
            div_remainder<= 32'd0;
            div_bit      <= 6'd0;
            div_busy     <= 1'b1;
          end
        end

        //------------------------------------------------------
        S_DIV2: begin
          if (!div_busy && (assign_mask <= max_mask) && (cnt1 >= L) && (cnt2 >= L) && (pot1 != 0) && (pot2 != 0)) begin
            P2 <= div_quotient;
            // Compute product = (P1 * P2) >> 16
            product <= (P1 * div_quotient) >> 16;
            // Update minimum
            if (!min_valid || product[31:0] < current_min) begin
              current_min <= product[31:0];
              min_valid   <= 1'b1;
            end
            // Advance assignment mask
            if (assign_mask == max_mask) begin
              min_product <= product[31:0] < current_min ? product[31:0] : current_min;
              done        <= 1'b1;
            end
            assign_mask <= assign_mask + 4'd1;
          end
        end

        //------------------------------------------------------
        S_DONE: begin
          // done already asserted in previous cycle; here hold result
          // FSM will move back to IDLE
        end

        default: ;
      endcase
    end
  end

endmodule