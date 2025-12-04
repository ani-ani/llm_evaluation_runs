module unique_product(
  input clk,
  input rst_n,
  input start,
  input [3:0] data_in,
  input data_valid,
  output reg [31:0] product,
  output reg done
);
  
  // States
  typedef enum logic [1:0] { IDLE, COLLECT, DONE } state_t;
  reg [1:0] state, next_state;
  
  // Data storage & tracking
  reg [3:0] input_count;   // 0-8 counts (4-bit)
  reg [3:0] unique_count;  // 0-8 counts (4-bit)
  reg [3:0] unique_numbers [0:7];
  reg [31:0] product_reg;
  wire is_duplicate;
  
  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      input_count <= 4'b0;
      unique_count <= 4'b0;
      product_reg <= 32'd1;
      done <= 1'b0;
      for (int i = 0; i < 8; i = i + 1) unique_numbers[i] <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COLLECT;
            input_count <= 4'b0;
            unique_count <= 4'b0;
            product_reg <= 32'd1;
            for (int i = 0; i < 8; i = i + 1) unique_numbers[i] <= 4'b0;
            done <= 1'b0;
          end
        end
        
        COLLECT: begin
          done <= 1'b0;
          if (data_valid) begin
            input_count <= input_count + 1;
            if (!is_duplicate && (unique_count < 4'd8)) begin
              unique_numbers[unique_count] <= data_in;
              unique_count <= unique_count + 1;
              product_reg <= product_reg * data_in;
            end
          end
          
          if (input_count == 4'd8) state <= DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
  // Duplicate check logic
  always_comb begin
    is_duplicate = 1'b0;
    for (int i = 0; i < unique_count; i = i + 1) begin
      if (data_in == unique_numbers[i]) is_duplicate = 1'b1;
    end
  end
  
  // Output logic
  always_comb begin
    if (done) begin
      product = (unique_count == 4'b0) ? 32'b0 : product_reg;
    end else begin
      product = 32'b0; 
    end
  end
  
endmodule