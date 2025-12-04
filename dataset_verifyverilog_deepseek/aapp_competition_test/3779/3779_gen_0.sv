module tax_divine_digit(input clk, input rst_n, input start, input [3:0] n, input [15:0] k, input [15:0] denomination_0, input [15:0] denomination_1, input [15:0] denomination_2, input [15:0] denomination_3, input [15:0] denomination_4, input [15:0] denomination_5, input [15:0] denomination_6, input [15:0] denomination_7, output reg [15:0] g, output reg [15:0] total, output reg done);
  
  typedef enum logic [3:0] { 
    IDLE,
    GCD_START,
    GCD_STEP0,
    GCD_STEP1,
    GCD_STEP2,
    GCD_STEP3,
    GCD_STEP4,
    GCD_STEP5,
    DIV_START,
    DIV_CALC,
    DONE
  } state_t;
  
  state_t state, next_state;
  reg [15:0] denominations[0:7];
  reg [15:0] current_g;
  reg [3:0] denom_index;
  
  // GCD variables
  reg [15:0] gcd_a, gcd_b;
  reg [4:0] shift_count;
  
  // Division variables
  reg [15:0] numer, denom;
  reg [15:0] quotient, remainder;
  reg [4:0] div_counter;
  
  always_comb begin
    denominations[0] = denomination_0;
    denominations[1] = denomination_1;
    denominations[2] = denomination_2;
    denominations[3] = denomination_3;
    denominations[4] = denomination_4;
    denominations[5] = denomination_5;
    denominations[6] = denomination_6;
    denominations[7] = denomination_7;
  end
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      g <= 16'b0;
      total <= 16'b0;
      state <= IDLE;
    end 
    else begin
      case (state)
        IDLE: begin
          done <= 0;
          g <= k;
          total <= 0;
          if (start) begin
            current_g <= k;
            denom_index <= 0;
            state <= GCD_START;
          end
        end
        
        GCD_START: begin
          gcd_a <= current_g;
          gcd_b <= denominations[denom_index];
          shift_count <= 0;
          state <= GCD_STEP0;
        end
        
        GCD_STEP0: begin
          if (!(gcd_a[0] || gcd_b[0])) begin // Both even
            gcd_a <= gcd_a >> 1;
            gcd_b <= gcd_b >> 1;
            shift_count <= shift_count + 1;
            state <= GCD_STEP0;
          end
          else begin
            state <= GCD_STEP1;
          end
        end
        
        GCD_STEP1: begin
          if (!gcd_a[0]) begin
            gcd_a <= gcd_a >> 1;
            state <= GCD_STEP1;
          end
          else begin
            state <= GCD_STEP2;
          end
        end
        
        GCD_STEP2: begin
          if (gcd_b == 0) begin
            current_g <= gcd_a << shift_count;
            if (denom_index == (n - 1)) begin
              state <= DIV_START;
            end
            else begin
              denom_index <= denom_index + 1;
              state <= GCD_START;
            end
          end
          else begin
            state <= GCD_STEP3;
          end
        end
        
        GCD_STEP3: begin
          if (!gcd_b[0]) begin
            gcd_b <= gcd_b >> 1;
            state <= GCD_STEP3;
          end
          else begin
            state <= GCD_STEP4;
          end
        end
        
        GCD_STEP4: begin
          if (gcd_a > gcd_b) begin
            {gcd_a, gcd_b} <= {gcd_b, gcd_a};
          end
          state <= GCD_STEP5;
        end
        
        GCD_STEP5: begin
          gcd_b <= gcd_b - gcd_a;
          state <= GCD_STEP2;
        end
        
        DIV_START: begin
          numer <= k;
          denom <= (current_g == 0) ? k : current_g;
          quotient <= 0;
          remainder <= 0;
          div_counter <= 0;
          state <= DIV_CALC;
        end
        
        DIV_CALC: begin
          if (div_counter < 16) begin
            remainder <= {remainder[14:0], numer[15]};
            numer <= numer << 1;
            if (remainder >= denom) begin
              remainder <= remainder - denom;
              quotient <= {quotient[14:0], 1'b1};
            end
            else begin
              quotient <= {quotient[14:0], 1'b0};
            end
            div_counter <= div_counter + 1;
            state <= DIV_CALC;
          end
          else begin
            total <= quotient;
            g <= denom;
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end

endmodule