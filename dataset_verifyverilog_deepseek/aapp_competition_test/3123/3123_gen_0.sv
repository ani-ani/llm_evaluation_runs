module max_quotation_level(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [2:0] a0,
  input [2:0] a1,
  input [2:0] a2,
  input [2:0] a3,
  input [2:0] a4,
  input [2:0] a5,
  input [2:0] a6,
  input [2:0] a7,
  output reg [2:0] k,
  output reg valid
);
  
  typedef enum logic [1:0] { STATE_IDLE, STATE_LATCH, STATE_MIN, STATE_FOUND } state_t;
  state_t current_state, next_state;
  
  reg [2:0] stored_n;
  reg [2:0] stored_a [0:7];
  reg [2:0] k_reg;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= STATE_IDLE;
      k <= 3'b0;
      valid <= 1'b0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        STATE_LATCH: begin
          stored_n <= n;
          stored_a[0] <= a0;
          stored_a[1] <= a1;
          stored_a[2] <= a2;
          stored_a[3] <= a3;
          stored_a[4] <= a4;
          stored_a[5] <= a5;
          stored_a[6] <= a6;
          stored_a[7] <= a7;
        end
        
        STATE_MIN: begin
          if (stored_n == 3'd1) begin
            if (stored_a[0] < 3'd2) k_reg <= 3'd0;
            else case (stored_a[0])
              3'd2, 3'd3: k_reg <= 3'd1;
              default:    k_reg <= 3'd2;
            endcase
          end else begin
            reg [2:0] min_k, min_inner, last_seg;
            last_seg = (stored_n == 3'd1) ? stored_a[0] :
                       (stored_n == 3'd2) ? stored_a[1] :
                       (stored_n == 3'd3) ? stored_a[2] :
                       (stored_n == 3'd4) ? stored_a[3] :
                       (stored_n == 3'd5) ? stored_a[4] :
                       (stored_n == 3'd6) ? stored_a[5] :
                       (stored_n == 3'd7) ? stored_a[6] : stored_a[7];
            min_k = (stored_a[0] < last_seg) ? stored_a[0] : last_seg;
            
            if (min_k == 3'b0) begin
              k_reg <= 3'b0;
            end else begin
              if (stored_n <= 3'd2) begin
                k_reg <= min_k;
              end else begin
                min_inner = 3'b111;
                for (int i=1; i <= stored_n-2; i=i+1) begin
                  if (stored_a[i] < min_inner) min_inner = stored_a[i];
                end
                k_reg <= (min_k < (min_inner + 1)) ? min_k : (min_inner + 1);
                if (k_reg < 3'b1) k_reg <= 3'b0;
              end
            end
          end
        end
        
        STATE_FOUND: begin
          k <= k_reg;
          valid <= 1'b1;
        end
        
        default: begin
          valid <= 1'b0;
        end
      endcase
    end
  end
  
  always_comb begin
    case (current_state)
      STATE_IDLE: next_state = start ? STATE_LATCH : STATE_IDLE;
      STATE_LATCH: next_state = STATE_MIN;
      STATE_MIN: next_state = STATE_FOUND;
      STATE_FOUND: next_state = STATE_IDLE;
      default: next_state = STATE_IDLE;
    endcase
  end
  
endmodule