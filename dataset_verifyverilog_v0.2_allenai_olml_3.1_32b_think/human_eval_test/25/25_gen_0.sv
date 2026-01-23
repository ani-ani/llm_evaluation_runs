module factorize (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [15:0] n,
   output reg [15:0] factors_out,
   output reg factors_valid,
   output reg done
);

// State register
reg [2:0] state;
// Current value being factored
reg [15:0] current_n;
// Divisor
reg [8:0] divisor;
// Value of the current factor to output
reg [15:0] factor_value;

localparam IDLE = 3'd0,
        CHECK_DIVISOR = 3'd1,
        OUTPUT_FACTOR = 3'd2,
        INCREMENT_DIVISOR = 3'd3,
        DONE = 3'd4;

always_ff @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      current_n <= 0;
      divisor <= 0;
      factor_value <= 0;
      done <= 0;
      factors_valid <= 0;
      factors_out <= 0;
   end else begin
      factors_out <=0;
      factors_valid <=0;
      done <=0;
      case (state)
         IDLE: 
            if (start) begin
               if (n == 0 || n == 1) begin
                  state <= DONE;
                  done <= 1'b1;
               end else begin
                  current_n <= n;
                  divisor <= 2;
                  state <= CHECK_DIVISOR;
               end
            end else begin
               state <= IDLE;
            end
         CHECK_DIVISOR: 
            if (current_n == 1) begin
               state <= DONE;
               done <= 1'b1;
            end else if (current_n % divisor == 0) begin
               factor_value <= divisor;
               state <= OUTPUT_FACTOR;
            end else begin
               state <= INCREMENT_DIVISOR;
            end
         INCREMENT_DIVISOR: 
            divisor <= divisor + 1;
            if (divisor * divisor > current_n && current_n > 1) begin
               factor_value <= current_n;
               state <= OUTPUT_FACTOR;
            end else begin
               state <= CHECK_DIVISOR;
            end
         OUTPUT_FACTOR: 
            factors_out <= factor_value;
            factors_valid <= 1'b1;
            if (factor_value == divisor) begin // regular factor case
               current_n <= current_n / factor_value;
            end else begin // final prime case
               current_n <= 1;
            end
            state <= CHECK_DIVISOR;
         DONE: 
            state <= DONE;
      endcase
   end
end