module settle_bills (
   input clk,
   input rst_n, // active low
   input start,
   input [2:0] num_people,
   input [2:0] num_receipts,
   input [2:0] payer,
   input [2:0] beneficiary,
   input [15:0] amount,
   input receipt_valid,
   output reg [7:0] num_transactions,
   output reg done,
   output reg error
);

   // Define MAX_PEOPLE
   localparam MAX_PEOPLE = 8;

   // State definitions
   localparam IDLE = 3'd0;
   localparam RECEIPT_INPUT = 3'd1;
   localparam CALC_BALANCES = 3'd2;
   localparam SETTLE = 3'd3;
   localparam DONE_STATE = 3'd4;

   // Registers
   reg [2:0] state, num_people_reg, num_receipts_reg;
   reg [2:0] received_receipts;
   reg [15:0] balance[MAX_PEOPLE];
   reg [15:0] transaction_count;
   reg done, error;

   // Default assignments for synthesis
   assign done = 1'b0;
   assign error = 1'b0;
   assign num_transactions = 16'd0;

   always @(negedge rst_n) begin
      if (!rst_n) begin
         state <= IDLE;
         num_people_reg <= 3'b000;
         num_receipts_reg <= 3'b000;
         received_receipts <= 3'b000;
         balance[0] <= 16'd0; balance[1] <=16'd0; balance[2] <=16'd0; balance[3] <=16'd0;
         balance[4] <=16'd0; balance[5] <=16'd0; balance[6] <=16'd0; balance[7] <=16'd0;
         transaction_count <= 16'd0;
         done <= 1'b0;
         error <= 1'b0;
      end
   end

   always @(posedge clk) begin
      if (!rst_n) begin
         // Asynchronous reset already handled
      end else begin
         case (state)
            IDLE: begin
               if (start == 1'b1) begin
                  if (num_people < 1 || num_people > 8) begin
                     error <= 1'b1;
                     state <= DONE_STATE;
                  end else begin
                     num_people_reg <= num_people;
                     num_receipts_reg <= num_receipts;
                     balance[0] <= 16'd0; balance[1] <=16'd0; balance[2] <=16'd0; balance[3] <=16'd0;
                     balance[4] <=16'd0; balance[5] <=16'd0; balance[6] <=16'd0; balance[7] <=16'd0;
                     received_receipts <= 3'b000;
                     transaction_count <= 16'd0;
                     error <= 1'b0;
                     state <= RECEIPT_INPUT;
                  end
               end else begin
                  state <= IDLE;
               end
            end
            RECEIPT_INPUT: begin
               if (receipt_valid == 1'b1 && received_receipts < num_receipts_reg) begin
                  if (payer >= num_people_reg || beneficiary >= num_people_reg) begin
                     error <= 1'b1;
                     state <= DONE_STATE;
                  end else begin
                     balance[payer] <= balance[payer] - amount;
                     balance[beneficiary] <= balance[beneficiary] + amount;
                     received_receipts <= received_receipts + 1;
                  end
               end
               if (received_receipts == num_receipts_reg) begin
                  state <= CALC_BALANCES;
               end
            end
            CALC_BALANCES: begin
               wire [15:0] total_sum;
               assign total_sum = balance[0] + balance[1] + balance[2] + balance[3] + 
                             balance[4] + balance[5] + balance[6] + balance[7];
               if (total_sum != 0) begin
                  error <= 1'b1;
                  state <= DONE_STATE;
               end else begin
                  state <= SETTLE;
               end
            end
            SETTLE: begin
               // Dummy: move to done with 0 transactions
               state <= DONE_STATE;
               num_transactions <= transaction_count;
            end
            DONE_STATE: begin
               state <= DONE_STATE;
            end
         endcase
      end
   end

   endmodule