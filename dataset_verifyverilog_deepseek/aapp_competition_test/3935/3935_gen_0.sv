module bipartite_graph_eraser(input clk, input rst_n, input start, input [15:0] data_in, output reg [15:0] erased_element, output reg element_valid, output reg [3:0] erased_count, output reg done);
  typedef enum logic [2:0] {IDLE, LOAD, PROCESS, OUTPUT, DONE} state_t;
  state_t state;
  reg [2:0] input_counter;
  reg [2:0] output_counter;
  reg [15:0] data_store [0:7];
  reg [3:0] exponent_store [0:7];
  reg [3:0] group_count [0:15];
  reg [3:0] max_group_exponent;
  reg [3:0] max_count;
  reg [3:0] erased_count_total;
  reg [3:0] current_erased_count;

  function automatic logic [3:0] count_trailing_zeros(input [15:0] data);
    begin
      count_trailing_zeros = 4'd15;
      for (int i = 0; i < 16; i++) begin
        if (data[i]) begin
          count_trailing_zeros = i;
          break;
        end
      end
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      input_counter <= 3'b0;
      output_counter <= 3'b0;
      erased_count <= 4'b0;
      element_valid <= 0;
      done <= 0;
      erased_element <= 16'b0;
      current_erased_count <= 0;
      for (int i = 0; i < 8; i++) begin
        data_store[i] <= 16'b0;
        exponent_store[i] <= 4'b0;
      end
      for (int j = 0; j < 16; j++) group_count[j] <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          erased_element <= 0;
          element_valid <= 0;
          done <= 0;
          if (start) begin
            state <= LOAD;
            input_counter <= 0;
            erased_count <= 0;
            current_erased_count <= 0;
            for (int j = 0; j < 16; j++) group_count[j] <= 0;
          end
        end
        
        LOAD: begin
          element_valid <= 0;
          erased_element <= 0;
          done <= 0;
          data_store[input_counter] <= data_in;
          exponent_store[input_counter] <= count_trailing_zeros(data_in);
          group_count[count_trailing_zeros(data_in)] <= group_count[count_trailing_zeros(data_in)] + 1;
          input_counter <= input_counter + 1;
          if (input_counter == 3'd7) state <= PROCESS;
        end
        
        PROCESS: begin
          element_valid <= 0;
          erased_element <= 0;
          done <= 0;
          max_count <= group_count[0];
          max_group_exponent <= 0;
          for (int i = 1; i < 16; i++) begin
            if (group_count[i] > max_count) begin
              max_count <= group_count[i];
              max_group_exponent <= i;
            end
          end
          erased_count_total <= 8 - max_count;
          if (erased_count_total == 0) state <= DONE;
          else begin
            state <= OUTPUT;
            output_counter <= 0;
          end
        end
        
        OUTPUT: begin
          done <= 0;
          if (output_counter < 3'd8) begin
            if (exponent_store[output_counter] != max_group_exponent) begin
              erased_element <= data_store[output_counter];
              element_valid <= 1'b1;
              current_erased_count <= current_erased_count + 1;
              erased_count <= current_erased_count + 1;
            end else begin
              erased_element <= 0;
              element_valid <= 0;
            end
            output_counter <= output_counter + 1;
          end
          if (output_counter == 3'd7) state <= DONE;
        end
        
        DONE: begin
          element_valid <= 0;
          erased_element <= 0;
          done <= 1'b1;
          if (start) state <= IDLE;
        end
      endcase
    end
  end
endmodule