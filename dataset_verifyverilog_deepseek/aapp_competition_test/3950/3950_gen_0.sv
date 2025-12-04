module query_array_validator(
  input clk, 
  input rst_n, 
  input start, 
  input [2:0] n, 
  input [5:0] q, 
  input [5:0] a0, input [5:0] a1, input [5:0] a2, input [5:0] a3, 
  input [5:0] a4, input [5:0] a5, input [5:0] a6, input [5:0] a7, 
  output reg valid, 
  output reg [5:0] restored_0, restored_1, restored_2, restored_3, 
  output reg [5:0] restored_4, restored_5, restored_6, restored_7, 
  output reg done
);

  // State encoding
  parameter IDLE = 2'b00;
  parameter PROCESSING = 2'b01;
  parameter DONE = 2'b10;
  reg [1:0] state, next_state;

  // Processing counters
  reg [2:0] index;
  reg [2:0] cycle_count;

  // Stack storage and pointer
  reg [5:0] stack [0:3]; // 4 levels deep
  reg [1:0] sp;           // Stack pointer

  // Array storage
  reg [5:0] array [0:7];

  // Algorithm flags
  reg found_q;
  reg zero_replaced;
  reg invalid_flag;

  // Element processing
  reg [5:0] current_element;
  wire [5:0] current_a;

  // Restored array output
  always @* begin
    restored_0 = array[0];
    restored_1 = array[1];
    restored_2 = array[2];
    restored_3 = array[3];
    restored_4 = array[4];
    restored_5 = array[5];
    restored_6 = array[6];
    restored_7 = array[7];
  end

  // Input array selection
  assign current_a = (index == 3'd0) ? a0 :
                       (index == 3'd1) ? a1 :
                       (index == 3'd2) ? a2 :
                       (index == 3'd3) ? a3 :
                       (index == 3'd4) ? a4 :
                       (index == 3'd5) ? a5 :
                       (index == 3'd6) ? a6 :
                       a7;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      index <= 0;
      sp <= 0;
      found_q <= 0;
      invalid_flag <= 0;
      cycle_count <= 0;
      zero_replaced <= 0;
      for (int i=0; i<8; i++) array[i] <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          valid <= 0;
          if (start) begin
            state <= PROCESSING;
            index <= 0;
            sp <= 0;
            found_q <= 0;
            invalid_flag <= 0;
            zero_replaced <= 0;
            array[0] <= 0; array[1] <= 0; array[2] <= 0; array[3] <= 0;
            array[4] <= 0; array[5] <= 0; array[6] <= 0; array[7] <= 0;
            cycle_count <= 0;
          end
        end

        PROCESSING: begin
          current_element <= current_a;
          // Zero replacement logic
          if (current_a == 0) begin
            if (!found_q && !zero_replaced) begin
              array[index] <= q;
              current_element <= q;
              found_q <= 1'b1;
              zero_replaced <= 1'b1;
            end else begin
              if (sp == 0) begin
                array[index] <= (index == 0) ? 6'd1 : array[index-1];
                current_element <= (index == 0) ? 6'd1 : array[index-1];
              end else begin
                array[index] <= stack[sp-1];
                current_element <= stack[sp-1];
              end
            end
          end else begin
            array[index] <= current_a;
            if (current_a == q) found_q <= 1'b1;
          end

          // Stack processing
          begin
            automatic logic [1:0] temp_sp = sp;
            // Determine pop count (max depth 4)
            while (temp_sp > 0 && current_element > stack[temp_sp-1])
              temp_sp = temp_sp - 1;

            // Push new value if valid
            if (temp_sp <= 3'd4) begin
              if (temp_sp == 0 || current_element <= stack[temp_sp-1]) begin
                if (temp_sp < 4) begin
                  stack[temp_sp] <= current_element;
                  sp <= temp_sp + 1;
                end else
                  invalid_flag <= 1; // Stack overflow
              end else
                invalid_flag <= 1; // Invalid push condition
            end else
              invalid_flag <= 1; // Invalid stack pointer
          end

          index <= index + 1;
          cycle_count <= cycle_count + 1;

          // Check termination conditions
          if (cycle_count >= (n + (n>>2))) begin
            state <= DONE;
            // Final q check
            if (!found_q || invalid_flag) valid <= 0;
            else valid <= 1;
          end
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule