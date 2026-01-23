module zebra_solver (
   input clk,
   input rst_n, 
   input start,
   input [7:0] char_in,
   input [4:0] char_index,
   input load,
   output reg [7:0] max_len,
   output reg done
);

// Buffer to hold 16 characters
reg [7:0] buffer [15:0];

// State machine states
localparam IDLE = 2'd0;
localparam LOAD = 2'd1;
localparam PROCESS = 2'd2;
localparam DONE = 2'd3;
reg [1:0] state;

// Substates for PROCESS
localparam SUBSTATEML = 2'd0;
localparam SUBSTATEPREFIX = 2'd1;
localparam SUBSTATESUFFIX = 2'd2;
localparam SUBSTATECOMPUTE = 2'd3;
reg [1:0] substate;

// Registers for max_linear computation
reg [4:0] max_linear;
reg [4:0] current_length_ml;
reg [3:0] count_ml;

// Registers for prefix and suffix
reg [4:0] prefix_length;
reg [4:0] suffix_length;
reg [3:0] i_prefix;
reg [3:0] i_suffix;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      substate <= SUBSTATEML;
      // Initialize all registers to zero or default
      max_linear <=1; // in case buffer has at least one char
      current_length_ml <=1;
      count_ml <=1;
      prefix_length <=0;
      suffix_length <=0;
      i_prefix <=0;
      i_suffix <=0;
      max_len <=0;
      done <=0;
   end else begin
      case (state)
         IDLE: begin
            if (start) begin
               // Move to PROCESS, initialize ML computation
               state <= PROCESS;
               substate <= SUBSTATEML;
               // Initialize for ML: current_length_ml=1 (for first char), count_ml=1 (to check index1)
               current_length_ml <=1;
               count_ml <=1;
               max_linear <=1; // initial value
            end else if (load) begin
               // Write to buffer and go to LOAD state
               state <= LOAD;
               buffer[char_index] <= char_in;
            end else begin
               state <= IDLE;
            end
         end
         LOAD: begin
            // Transition back to IDLE
            state <= IDLE;
         end
         PROCESS: begin
            case (substate)
               SUBSTATEML: begin
                  if (count_ml < 16) begin // indices 1 to15
                     if (buffer[count_ml] != buffer[count_ml-1]) begin
                         current_length_ml = current_length_ml +1;
                     end else begin
                         current_length_ml =1;
                     end
                     if (current_length_ml > max_linear) begin
                         max_linear = current_length_ml;
                     end
                     count_ml = count_ml +1;
                  end else begin
                     // Final check for current_length_ml
                     if (current_length_ml > max_linear) begin
                         max_linear = current_length_ml;
                     end
                     // Move to prefix computation
                     substate <= SUBSTATEPREFIX;
                     prefix_length <=1; // initialize prefix_length to1
                     i_prefix <=1; // start checking from index1
                  end
               end
               SUBSTATEPREFIX: begin
                  if (i_prefix < 16) begin // indices1 to15
                     if (buffer[i_prefix] != buffer[i_prefix-1]) begin
                         prefix_length = prefix_length +1;
                         i_prefix = i_prefix +1;
                     end else begin
                         i_prefix = i_prefix +1;
                     end
                  end else begin
                     // Move to suffix computation
                     substate <= SUBSTATESUFFIX;
                     suffix_length <=1; // start with 1 for last character
                     i_suffix <=14; // start comparing from index14 and15
                  end
               end
               SUBSTATESUFFIX: begin
                  if (i_suffix >=0) begin // from14 down to0
                     if (buffer[i_suffix] != buffer[i_suffix+1]) begin
                         suffix_length = suffix_length +1;
                         i_suffix = i_suffix -1;
                     end else begin
                         i_suffix = i_suffix -1;
                     end
                  end else begin
                     // All done, compute result
                     substate <= SUBSTATECOMPUTE;
                  end
               end
               SUBSTATECOMPUTE: begin
                  // Calculate final max_len
                  reg [4:0] candidate;
                  if (buffer[0] != buffer[15]) begin
                     candidate = prefix_length + suffix_length;
                     if (candidate > 16) candidate =16;
                     max_len = (candidate > max_linear) ? candidate : max_linear;
                  end else begin
                     max_len = max_linear;
                  end
                  if (max_len >16) max_len =16; // Ensure does not exceed 16
                  done <=1;
                  state <= DONE;
               end
            endcase
         end
         DONE: state <= DONE;
      endcase
   end
endmodule