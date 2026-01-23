module power_set_generator (
   input clk,
   input rst_n, // active-low reset
   input start,
   input [3:0] valid_mask,
   input [7:0] element_0, element_1, element_2, element_3,
   output reg [7:0] output_element,
   output reg output_valid,
   output reg [3:0] output_indices,
   output reg output_done
);

// Registers
reg [3:0] subset_counter; // 0 to 15
reg [3:0] current_output_indices_reg;
reg [3:0] sent_bits;
reg [3:0] state; // IDLE=0, PROCESS_SUBSET=1, OUTPUT_ELEMENT=2, DONE=3

// Wires for combinatorial logic
wire [3:0] next_bit;

// Compute next_bit as lowest set bit in (current_output_indices_reg & ~sent_bits)
always @(*) begin
   wire [3:0] temp_val = current_output_indices_reg & ~sent_bits;
   next_bit = 4'd4;
   if (temp_val !=4'd0) begin
      if (temp_val & 1) next_bit =0;
      else if (temp_val & 2) next_bit =1;
      else if (temp_val &4) next_bit =2;
      else if (temp_val &8) next_bit =3;
   end
end

// State machine
always @(posedge clk or negedge rst_n) begin
   if (!rst_n) begin
      subset_counter <=4'd0;
      current_output_indices_reg <=4'd0;
      sent_bits <=4'd0;
      state <=4'd0; // IDLE
      output_done <=1'b0;
      output_valid <=1'b0;
      output_element <=8'd0;
   end else begin
      case (state)
         4'd0: // IDLE
            output_valid <=1'b0;
            output_element <=8'd0;
            output_indices <=4'd0;
            if (start) begin
               subset_counter <=4'd0;
               current_output_indices_reg <=4'd0;
               sent_bits <=4'd0;
               state <=4'd1; // PROCESS_SUBSET
            end else begin
               state <=4'd0;
            end
         4'd1: // PROCESS_SUBSET
            output_valid <=1'b0;
            output_element <=8'd0;
            output_indices <=4'd0;
            if (subset_counter <4'd16) begin
               wire [3:0] current_output_indices = subset_counter & valid_mask;
               if (current_output_indices ==4'd0) begin
                  subset_counter <= subset_counter +1;
                  state <=4'd1;
               end else begin
                  current_output_indices_reg <= current_output_indices;
                  sent_bits <=4'd0;
                  state <=4'd2; // OUTPUT_ELEMENT
               end
            end else begin
               state <=4'd3; // DONE
            end
         4'd2: // OUTPUT_ELEMENT
            output_valid <=1'b0;
            output_element <=8'd0;
            output_indices <=4'd0;
            if (next_bit ==4'd4) begin // no more bits in this subset
               subset_counter <= subset_counter +1;
               state <=4'd1; // PROCESS_SUBSET
            end else begin
               // Output the current element
               case (next_bit)
                  0: output_element <= element_0;
                  1: output_element <= element_1;
                  2: output_element <= element_2;
                  3: output_element <= element_3;
                  default: output_element <=8'd0;
               endcase
               output_valid <=1'b1;
               output_indices <= current_output_indices_reg;
               sent_bits <= sent_bits | (1 << next_bit);
               state <=4'd2; // stay in OUTPUT_ELEMENT
            end
         4'd3: // DONE
            output_valid <=1'b0;
            output_element <=8'd0;
            output_indices <=4'd0;
            state <=4'd3;
      endcase
   end
end

// Assign output_done
assign output_done = (subset_counter ==4'd16);
endmodule