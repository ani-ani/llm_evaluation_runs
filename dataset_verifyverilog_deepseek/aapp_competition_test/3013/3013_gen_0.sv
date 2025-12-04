module spiral_exit_point(
  input clk,
  input rst_n,
  input start,
  input [31:0] b_q248,
  input [31:0] tx_q248,
  input [31:0] ty_q248,
  output reg [31:0] x_out_q248,
  output reg [31:0] y_out_q248,
  output reg done
);

  // Control FSM states
  typedef enum {
    IDLE,
    INIT,
    ITERATE,
    DONE_STATE
  } state_t;
  state_t current_state, next_state;

  // Signed representation for arithmetic
  reg signed [31:0] tx_reg;
  reg signed [31:0] ty_reg;
  reg signed [31:0] b_reg;
  reg signed [15:0] phi; // Q8.8
  reg [4:0] iter;
  reg [2:0] cycle;
  reg phase;

  // ROM definitions
  reg [31:0] sin_rom [0:4095];
  reg [31:0] cos_rom [0:4095];
  reg [31:0] sin_val, cos_val;
  reg [31:0] sin_delta, cos_delta;

  // Computational pipeline registers
  reg signed [47:0] r_product;
  reg signed [63:0] x_product;
  reg signed [63:0] y_product;
  reg signed [31:0] x_curr;
  reg signed [31:0] y_curr;
  reg signed [31:0] dx_dphi;
  reg signed [31:0] dy_dphi;
  reg signed [63:0] num;
  reg signed [63:0] den;
  reg signed [63:0] adjustment;
  reg signed [15:0] delta_phi;

  // Initialization placeholder for ROMs
  initial begin
    for(int i=0; i<4096; i++) begin
      sin_rom[i] = 0;
      cos_rom[i] = 0;
    end
  end

  // State machine and main control
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
      current_state <= IDLE;
      done <= 1'b0;
      x_out_q248 <= 0;
      y_out_q248 <= 0;
      phi <= 0;
      iter <= 0;
      cycle <= 0;
      tx_reg <= 0;
      ty_reg <= 0;
      b_reg <= 0;
    end
    else begin
      current_state <= next_state;
      case(current_state)
        IDLE: begin
          done <= 1'b0;
          if(start) begin
            tx_reg <= tx_q248;
            ty_reg <= ty_q248;
            b_reg <= b_q248;
            next_state <= INIT;
          end
        end

        INIT: begin
          phi <= 0;
          iter <= 0;
          cycle <= 0;
          next_state <= ITERATE;
        end

        ITERATE: begin
          if(cycle == 7) begin
            if(iter == 15) next_state <= DONE_STATE;
            else iter <= iter + 1;
            cycle <= 0;
            // Phi update
            phi <= $signed(phi) + $signed(delta_phi);
          end
          else cycle <= cycle + 1;

          // Computational pipeline
          case(cycle)
            0: begin
              r_product <= $signed(b_reg) * $signed({phi, 8'b0});
              sin_val <= sin_rom[phi[15:4]];
              cos_val <= cos_rom[phi[15:4]];
            end
            1: begin
              x_product <= $signed(r_product) * $signed(cos_val);
              y_product <= $signed(r_product) * $signed(sin_val);
              sin_delta <= sin_rom[{phi[15:8], phi[7:0]+8'h1}];
              cos_delta <= cos_rom[{phi[15:8], phi[7:0]+8'h1}];
            end
            2: begin
              x_curr <= x_product[55:24]; // Q24.8 from Q56.24
              y_curr <= y_product[55:24];
            end
            3: begin
              dx_dphi <= (($signed(r_product) * $signed(cos_delta)) >> 24) - x_curr;
              dy_dphi <= (($signed(r_product) * $signed(sin_delta)) >> 24) - y_curr;
            end
            4: begin
              num <= ($signed(tx_reg - x_curr) * $signed(dy_dphi)) - 
                     ($signed(ty_reg - y_curr) * $signed(dx_dphi));
            end
            5: begin
              den <= ($signed(dx_dphi) * $signed(dx_dphi)) + 
                     ($signed(dy_dphi) * $signed(dy_dphi));
            end
            6: begin
              adjustment <= ($signed(num) << 16) / den; // Q16.16
            end
            7: begin
              delta_phi <= adjustment[23:8]; // Q8.8
            end
          endcase
        end

        DONE_STATE: begin
          x_out_q248 <= x_curr;
          y_out_q248 <= y_curr;
          done <= 1'b1;
          next_state <= IDLE;
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // FSM next state logic
  always_comb begin
    next_state = current_state;
    case(current_state)
      IDLE: next_state = start ? INIT : IDLE;
      INIT: next_state = ITERATE;
      ITERATE: if(iter == 15 && cycle == 7) next_state = DONE_STATE;
      DONE_STATE: next_state = IDLE;
    endcase
  end

endmodule