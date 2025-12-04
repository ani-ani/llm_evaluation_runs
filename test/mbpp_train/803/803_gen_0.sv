module perfect_square_checker(
  input  wire        clk,
  input  wire        rst_n,
  input  wire        start,
  input  wire [15:0] n,
  output reg         done,
  output reg         is_square
);

  // State encoding
  localparam IDLE = 1'b0;
  localparam BUSY = 1'b1;

  reg        state;
  reg [15:0] n_reg;
  reg [7:0]  i;
  reg [15:0] square;

  // Next-state and output logic (sequential)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state     <= IDLE;
      n_reg     <= 16'd0;
      i         <= 8'd0;
      square    <= 16'd0;
      done      <= 1'b0;
      is_square <= 1'b0;
    end else begin
      // Default: done deasserted each cycle unless completion this cycle
      done <= 1'b0;

      case (state)
        IDLE: begin
          i      <= 8'd0;
          square <= 16'd0;
          if (start) begin
            n_reg <= n;
            // Handle 0 as a special case: 0 is a perfect square (0*0)
            if (n == 16'd0) begin
              is_square <= 1'b1;
              done      <= 1'b1; // one-cycle pulse
              state     <= IDLE;
            end else begin
              i         <= 8'd1;
              square    <= 16'd1;
              is_square <= 1'b0; // default until proven square
              state     <= BUSY;
            end
          end
        end

        BUSY: begin
          // Check current square vs n_reg
          if (square == n_reg) begin
            is_square <= 1'b1;
            done      <= 1'b1; // one-cycle pulse
            state     <= IDLE;
          end else if (square > n_reg || i == 8'd255) begin
            // If exceeded n_reg or reached max i (satisfies max latency)
            is_square <= 1'b0;
            done      <= 1'b1; // one-cycle pulse
            state     <= IDLE;
          end else begin
            // Increment i and compute next square for the next cycle
            i      <= i + 8'd1;
            square <= (i + 8'd1) * (i + 8'd1);
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule