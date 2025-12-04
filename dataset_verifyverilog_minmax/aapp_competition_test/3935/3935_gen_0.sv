module bipartite_graph_eraser(
  input clk, // clock signal
  input rst_n, // active-low reset
  input start, // start processing
  input [15:0] data_in, // input element (16-bit)
  output reg [15:0] erased_element, // current erased element (0 if none)
  output reg element_valid, // high when erased_element valid
  output reg [3:0] erased_count, // total erased count (3-bit width for up to 15 elements)
  output reg done // high when processing complete
);

  typedef enum logic [2:0] {IDLE = 3'b000, LOAD = 3'b001, PROCESS = 3'b010, OUTPUT = 3'b011, DONE = 3'b100} state_t;
  state_t state, next_state;

  reg [15:0] elements [0:7];
  reg [3:0] group_counts [0:15]; // counters per exponent (0..15), ignore index 16 for 0
  reg [3:0] input_count, next_input_count;
  reg [3:0] max_exp, next_max_exp;
  reg [3:0] max_size, next_max_size;
  reg [3:0] output_ptr, next_output_ptr;
  reg [3:0] output_count, next_output_count;
  reg next_done;

  function [3:0] ctz16;
    input [15:0] x;
    integer i;
    begin
      ctz16 = 4'b0;
      if (x == 16'b0) begin
        ctz16 = 4'd16; // classify zeros as exponent 0
      end else begin
        for (i = 0; i < 16; i = i + 1) begin
          if (x[i] === 1'b1) begin
            ctz16 = i[3:0];
            break;
          end
        end
      end
    end
  endfunction

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      input_count <= 4'd0;
      max_exp <= 4'd0;
      max_size <= 4'd0;
      output_ptr <= 4'd0;
      output_count <= 4'd0;
      done <= 1'b0;
      erased_element <= 16'd0;
      element_valid <= 1'b0;
      erased_count <= 4'd0;
    end else begin
      state <= next_state;
      input_count <= next_input_count;
      max_exp <= next_max_exp;
      max_size <= next_max_size;
      output_ptr <= next_output_ptr;
      output_count <= next_output_count;
      done <= next_done;

      element_valid <= 1'b0;
      erased_element <= 16'd0;
      erased_count <= output_count;

      if (state == OUTPUT) begin
        if (output_ptr < 4'd8) begin
          erased_element <= elements[output_ptr];
          element_valid <= 1'b1;
          if (output_ptr < 4'd7) begin
            output_ptr <= output_ptr + 1;
            output_count <= output_count + 1;
          end else begin
            output_count <= output_count + 1;
          end
        end
      end
    end
  end

  always_comb begin
    next_state = state;
    next_input_count = input_count;
    next_max_exp = max_exp;
    next_max_size = max_size;
    next_output_ptr = output_ptr;
    next_output_count = output_count;
    next_done = 1'b0;

    case (state)
      IDLE: begin
        next_input_count = 4'd0;
        next_max_exp = 4'd0;
        next_max_size = 4'd0;
        next_output_ptr = 4'd0;
        next_output_count = 4'd0;
        next_done = 1'b0;
        if (start) begin
          next_state = LOAD;
          next_input_count = 4'd0;
        end
      end

      LOAD: begin
        if (input_count < 4'd8) begin
          // Capture current data_in on this cycle
          elements[input_count] = data_in;
          begin
            automatic logic [3:0] tz;
            tz = ctz16(data_in);
            if (tz < 4'd16) begin
              group_counts[tz] = group_counts[tz] + 4'd1;
            end
          end
          next_input_count = input_count + 4'd1;
        end
        if (next_input_count == 4'd8) begin
          next_state = PROCESS;
        end
      end

      PROCESS: begin
        // Find group with max size (choose smallest exp on tie)
        next_max_size = 4'd0;
        next_max_exp = 4'd0;
        begin
          for (int e = 0; e < 16; e = e + 1) begin
            if (group_counts[e] > next_max_size) begin
              next_max_size = group_counts[e];
              next_max_exp = e[3:0];
            end
          end
        end
        next_state = OUTPUT;
        next_output_ptr = 4'd0;
        next_output_count = 4'd0;
      end

      OUTPUT: begin
        // Skip elements whose exponent matches max_exp
        if (output_ptr < 4'd8) begin
          automatic logic [3:0] tz;
          tz = ctz16(elements[output_ptr]);
          if (tz != max_exp) begin
            // erased_element and element_valid are set in FF block
          end else begin
            // Not erased this cycle, do not increment output pointer or count
          end
        end
        // Finish after 8 cycles (one per input element)
        if (output_ptr == 4'd7) begin
          next_state = DONE;
          next_done = 1'b1;
        end
      end

      DONE: begin
        next_done = 1'b1;
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end
endmodule
