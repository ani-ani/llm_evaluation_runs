module cylinder_volume (
  input        clk,
  input        rst_n,
  input        start,
  input  [15:0] radius,
  input  [15:0] height,
  output reg [31:0] volume,
  output reg   done
);

  // States for 3-cycle pipeline
  typedef enum logic [1:0] {
    IDLE  = 2'b00,
    STAGE1 = 2'b01,
    STAGE2 = 2'b10,
    STAGE3 = 2'b11
  } state_t;

  state_t state, next_state;

  // Intermediate registers
  reg [31:0] r_squared;      // radius^2
  reg [47:0] rh_product;     // r_squared * height (up to 32x16 = 48 bits)
  reg [63:0] pi_product;     // rh_product * PI (48x19 = up to 67 bits, use 64 bits)

  // PI in Q16.16 scaled integer: 3.1415 * 65536 ≈ 0x0003243F
  localparam [18:0] PI_Q16_16 = 19'h3243F;

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    case (state)
      IDLE: begin
        if (start)
          next_state = STAGE1;
        else
          next_state = IDLE;
      end
      STAGE1: next_state = STAGE2;
      STAGE2: next_state = STAGE3;
      STAGE3: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

  // Datapath and outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      r_squared  <= 32'd0;
      rh_product <= 48'd0;
      pi_product <= 64'd0;
      volume     <= 32'd0;
      done       <= 1'b0;
    end else begin
      done <= 1'b0; // default, asserted only when result becomes valid

      case (state)
        IDLE: begin
          if (start) begin
            // Cycle 1: compute radius^2
            r_squared <= radius * radius;
          end
        end

        STAGE1: begin
          // Cycle 2: compute r_squared * height
          rh_product <= r_squared * height;
        end

        STAGE2: begin
          // Cycle 3: compute rh_product * PI_Q16_16
          pi_product <= rh_product * PI_Q16_16;
        end

        STAGE3: begin
          // Cycle 4: finalize volume in Q16.16 format
          // Inputs are integers; after multiplying by PI (Q16.16),
          // the result is in Q16.16. Take lower 32 bits.
          volume <= pi_product[31:0];
          done   <= 1'b1;
        end

        default: begin
          // No action
        end
      endcase
    end
  end

endmodule