module cylinder_volume (
  input logic        clk,
  input logic        rst_n,
  input logic        start,
  input logic [15:0] radius,
  input logic [15:0] height,
  output logic [31:0] volume,
  output logic       done
);

  // Internal signals
  logic [1:0] state;
  logic [31:0] r_squared;
  logic [47:0] rh_product;  // Q16.16 * Q16.16 -> Q32.16

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state    <= 2'b00;
      r_squared <= '0;
      rh_product <= '0;
      volume   <= '0;
      done     <= '0;
    end else begin
      case (state)
        2'b00: begin // IDLE
          done <= '0;
          if (start) begin
            r_squared <= $unsigned(radius) * $unsigned(radius); // Q0.16 * Q0.16 = Q32.16
            state     <= 2'b01;
          end else begin
            r_squared <= '0;
          end
        end

        2'b01: begin // Cycle 2: rh_product = r_squared * height
          rh_product <= r_squared * $unsigned(height);           // Q32.16 * Q0.16 = Q48.16
          state      <= 2'b10;
        end

        2'b10: begin // Cycle 3: volume = rh_product * pi (0x3243F), Q16.16
          volume   <= ((rh_product * 18'd3243F) + (1 << 15)) >> 16; // Round to nearest
          done     <= 1'b1;
          state    <= 2'b00;
          rh_product <= '0;
        end

        default: begin
          state <= 2'b00;
        end
      endcase
    end
  end

endmodule
