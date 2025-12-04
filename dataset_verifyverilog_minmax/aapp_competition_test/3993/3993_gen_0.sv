module page_operations_counter(
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  input [7:0] m,
  input [7:0] k,
  input [7:0] p_data,
  input p_valid,
  output reg [3:0] out_op,
  output reg done
);

  // Internal memory for storing up to 8 sorted special items
  reg [7:0] p_mem [0:7];
  reg [3:0] store_count;
  
  // State machine states
  localparam IDLE = 2'd0;
  localparam INIT = 2'd1;
  localparam COMPUTE = 2'd2;
  localparam DONE = 2'd3;
  
  reg [1:0] state;
  
  // Internal computation variables
  reg [7:0] shift_reg;
  reg [3:0] op_count_reg;
  reg [3:0] current_index_reg;
  reg [3:0] num_discarded;
  reg [7:0] first_page;
  
  // Store special items when p_valid is high
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      store_count <= 4'd0;
    end else begin
      if (p_valid) begin
        p_mem[store_count] <= p_data;
        store_count <= store_count + 1;
      end
    end
  end
  
  // Combinational logic for counting consecutive items in current group
  always @(*) begin
    if (state == COMPUTE) begin
      if (current_index_reg < m) begin
        first_page = (p_mem[current_index_reg] - shift_reg - 1) / k;
        num_discarded = 4'd0;
        for (int j = 0; j < 8; j++) begin
          if (current_index_reg + j < m) begin
            if (j < num_discarded) begin
              // Already counted, continue
            end else if ((p_mem[current_index_reg+j] - shift_reg) <= ((first_page + 1) * k)) begin
              num_discarded = j + 1;
            end else begin
              j = 8; // Break loop
            end
          end
        end
      end else begin
        num_discarded = 4'd0;
      end
    end else begin
      num_discarded = 4'd0;
    end
  end
  
  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      out_op <= 4'd0;
      done <= 1'b0;
      shift_reg <= 8'd0;
      op_count_reg <= 4'd0;
      current_index_reg <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 1'b0;
          end
        end
        
        INIT: begin
          // Initialize computation variables
          shift_reg <= 8'd0;
          op_count_reg <= 4'd0;
          current_index_reg <= 4'd0;
          
          // Check if no special items to process
          if (m == 8'd0) begin
            state <= DONE;
            out_op <= 4'd0;
            done <= 1'b1;
          end else begin
            state <= COMPUTE;
          end
        end
        
        COMPUTE: begin
          // Update state variables
          shift_reg <= shift_reg + num_discarded;
          op_count_reg <= op_count_reg + 1;
          current_index_reg <= current_index_reg + num_discarded;
          
          // Check if all items processed
          if (current_index_reg + num_discarded >= m) begin
            state <= DONE;
            out_op <= op_count_reg + 1;
            done <= 1'b1;
          end
        end
        
        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
            done <= 1'b0;
          end
        end
        
        default: state <= IDLE;
      endcase
    end
  end
  
endmodule