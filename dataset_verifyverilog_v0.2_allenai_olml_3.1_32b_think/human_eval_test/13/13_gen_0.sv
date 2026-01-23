module gcd_calculator (
   input clk,
   input rst_n, // active low
   input start,
   input [15:0] a,
   input [15:0] b,
   output reg [15:0] result,
   output reg done,
   output reg error
);

// Internal registers
reg [15:0] reg_a, reg_b;
reg [2:0] state; // IDLE=0, CHECK=1, SWAP=2, SUBTRACT=3, SHIFT=4, DONE=5
reg [15:0] result_reg;
reg done_reg, error_reg;

// State encoding
localparam IDLE = 3'd0,
        CHECK = 3'd1,
        SWAP = 3'd2,
        SUBTRACT = 3'd3,
        SHIFT = 3'd4,
        DONE = 3'd5;

initial begin
   state <= IDLE;
   reg_a <=0;
   reg_b <=0;
   result_reg <=0;
   done_reg <=0;
   error_reg <=0;
end

// Clock and reset handling
always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      reg_a <=0;
      reg_b <=0;
      result_reg <=0;
      done_reg <=0;
      error_reg <=0;
   end else begin
      if (start) begin
         // Handle state transitions and updates
         case(state)
            IDLE: begin
               if (1'b1) begin // start is high
                  reg_a <= a;
                  reg_b <= b;
                  state <= CHECK;
               end
            end
            CHECK: begin
               if (reg_a ==0 && reg_b ==0) begin
                  error_reg <=1;
                  done_reg <=1;
                  state <= DONE;
               end else if (reg_b ==0) begin
                  result_reg <= reg_a;
                  done_reg <=1;
                  error_reg <=0;
                  state <= DONE;
               end else begin
                  if (reg_a < reg_b) begin
                     state <= SWAP;
                  end else begin
                     if (reg_b &1 ==0) begin
                        state <= SHIFT;
                     end else begin
                        if (reg_a &1 ==0) begin
                           state <= SHIFT;
                        end else begin
                           state <= SUBTRACT;
                        end
                     end
                  end
               end
            end
            SWAP: begin
               {reg_a, reg_b} <= {reg_b, reg_a};
               state <= CHECK;
            end
            SUBTRACT: begin
               reg_a <= reg_a - reg_b;
               state <= CHECK;
            end
            SHIFT: begin
               if (reg_b &1 ==0) begin
                  reg_b <= reg_b >>1;
               end else if (reg_a &1 ==0) begin
                  reg_a <= reg_a >>1;
               end else begin
                  // neither even, do nothing? Or treat as error? For now, do nothing and proceed
               end
               state <= CHECK;
            end
            DONE: begin
               // no action, stay in DONE
               state <= DONE;
            end
         endcase
      end // if start
   end // else (not reset)
end

// Assign outputs
assign result = result_reg;
assign done = done_reg;
assign error = error_reg;

endmodule