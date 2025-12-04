module even_nested_elements (
  input clk,
  input rst_n,
  input start,
  input [15:0][2:0][7:0] flat_tuple,
  input [3:0] size_in,
  output reg [15:0][2:0][7:0] flat_out,
  output reg [3:0] size_out,
  output reg done
);

  typedef enum {IDLE, PROCESSING, DONE} state_t;
  state_t state;

  reg [3:0] element_counter;
  reg [3:0] write_ptr;
  reg [2:0] prev_level;
  
  // Stack to track parent write indices (max depth=3)
  reg [2:0][3:0] stack;
  reg [1:0] sp;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      flat_out <= '{default: '{3'b000, 8'hFF}};
      size_out <= 4'b0;
      element_counter <= 4'b0;
      write_ptr <= 4'b0;
      prev_level <= 3'b0;
      stack <= '{default: 4'b0};
      sp <= 2'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            element_counter <= 4'b0;
            write_ptr <= 4'b0;
            prev_level <= 3'b0;
            sp <= 2'b0;
            size_out <= 4'b0;
            done <= 1'b0;
            flat_out <= '{default: '{3'b000, 8'hFF}};
          end
        end

        PROCESSING: begin
          if (element_counter < size_in) begin
            automatic logic [2:0] curr_level = flat_tuple[element_counter][2:0];
            automatic logic [7:0] curr_val = flat_tuple[element_counter][7:0];
            automatic logic is_even_valid = (curr_val[0] == 0) && (curr_val != 0) && (curr_val != 8'hFF);
            
            // Check level continuity
            if (curr_level <= (prev_level + 1) || (element_counter == 0 && curr_level == 0)) begin
              
              // Pop stack for level decreases
              if (curr_level < prev_level) begin
                sp <= sp - (prev_level - curr_level);
              end
              
              // Push to stack for level increase
              if (is_even_valid && curr_level == (prev_level + 1)) begin
                stack[sp] <= write_ptr;
                sp <= sp + 1;
              end 
              
              // Write element if valid
              if (is_even_valid) begin
                flat_out[write_ptr] <= {curr_level, curr_val};
                write_ptr <= write_ptr + 1;
                size_out <= size_out + 1;
                prev_level <= curr_level;
              end 
            end
            element_counter <= element_counter + 1;
          end else begin
            state <= DONE;
            done <= 1'b1;
          end
        end

        DONE: begin
          state <= IDLE;
          done <= 1'b0;
        end
      endcase
    end
  end

endmodule