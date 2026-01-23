module probability_calculator (
  input clk,
  input rst_n,
  input start,
  input [7:0] N,
  output reg [31:0] result,
  output reg done
);

  // Define states
  localparam [1:0] IDLE = 2'b00;
  localparam [1:0] PROCESSING = 2'b01;
  localparam [1:0] DONE = 2'b10;
  
  reg [1:0] state = IDLE;
  reg [31:0] numerator;
  reg [31:0] denominator;
  reg [31:0] quotient;
  reg [31:0] remainder;
  reg [4:0] count;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      result <= 32'b0;
      done <= 1'b0;
      numerator <= 32'b0;
      denominator <= 32'b0;
      quotient <= 32'b0;
      remainder <= 32'b0;
      count <= 5'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            done <= 1'b0;
            case (N)
              8'd2: begin
                result <= 32'h00010000; // 1.0 in Q16.16
                state <= DONE;
              end
              8'd4: begin
                numerator <= 32'h001a0000; // 26 * 65536 = 1703936
                denominator <= 32'h0000001b; // 27
                quotient <= 32'b0;
                remainder <= 32'b0;
                count <= 5'd16; // 16 bits for division
              end
              default: begin
                result <= 32'b0;
                state <= DONE;
              end
            endcase
          end
        end
        PROCESSING: begin
          if (N == 8'd4) begin
            if (count > 0) begin
              // Shift remainder and quotient left
              remainder <= {remainder[30:0], numerator[31]};
              quotient <= {quotient[30:0], 1'b0};
              numerator <= numerator << 1;
              
              // Subtract denominator if remainder >= denominator
              if (remainder >= denominator) begin
                remainder <= remainder - denominator;
                quotient[0] <= 1'b1;
              end
              
              count <= count - 1;
            end else begin
              result <= quotient;
              state <= DONE;
            end
          end else begin
            state <= DONE;
          end
        end
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
        default: state <= IDLE;
      endcase
    end
  end

endmodule