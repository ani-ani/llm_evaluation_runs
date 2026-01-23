module voodoo_average (
  input clk,
  input rst_n,
  input start,
  input [15:0] valid_length,
  input [31:0] price_i,
  input [31:0] P,
  output reg [31:0] result,
  output reg done,
  output reg input_ready
);

  parameter N = 16;
  
  typedef enum logic [1:0] {
    IDLE,
    LOAD_PRICES,
    COMPUTE,
    DONE
  } state_t;
  
  state_t current_state, next_state;
  reg [31:0] prices [0:N-1];
  reg [4:0] price_counter;
  reg [4:0] i_reg, j_reg;
  reg [63:0] running_sum;
  reg [31:0] result_reg;
  reg [31:0] threshold;
  reg [31:0] length;
  
  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      price_counter <= 0;
      i_reg <= 0;
      j_reg <= 0;
      running_sum <= 0;
      result_reg <= 0;
      done <= 0;
      input_ready <= 1;
    end else begin
      current_state <= next_state;
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_PRICES;
          price_counter = 0;
          i_reg = 0;
          j_reg = 0;
          running_sum = 0;
          result_reg = 0;
          done = 0;
          input_ready = 1;
        end
      end
      LOAD_PRICES: begin
        if (price_counter == valid_length - 1) begin
          next_state = COMPUTE;
          input_ready = 0;
        end
      end
      COMPUTE: begin
        if (i_reg == valid_length - 1 && j_reg == valid_length) begin
          next_state = DONE;
          done = 1;
          result = result_reg;
        end
      end
      DONE: begin
        if (start) begin
          next_state = LOAD_PRICES;
          price_counter = 0;
          i_reg = 0;
          j_reg = 0;
          running_sum = 0;
          result_reg = 0;
          done = 0;
          input_ready = 1;
        end
      end
      default: next_state = IDLE;
    endcase
  end
  
  // Price loading logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      price_counter <= 0;
    end else if (current_state == LOAD_PRICES && input_ready) begin
      if (price_counter < valid_length) begin
        prices[price_counter] <= price_i;
        price_counter <= price_counter + 1;
      end
    end
  end
  
  // Compute logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      i_reg <= 0;
      j_reg <= 0;
      running_sum <= 0;
      result_reg <= 0;
    end else if (current_state == COMPUTE) begin
      if (j_reg == i_reg) begin
        running_sum <= {1'b0, prices[i_reg]};
      end else if (j_reg < valid_length) begin
        running_sum <= running_sum + {1'b0, prices[j_reg]};
      end
      
      if (j_reg < valid_length) begin
        length = j_reg - i_reg + 1;
        threshold = P * length;
        if (running_sum >= {1'b0, threshold}) begin
          result_reg <= result_reg + 1;
        end
      end
      
      if (j_reg == valid_length - 1) begin
        i_reg <= i_reg + 1;
        j_reg <= i_reg;
      end else if (j_reg < valid_length - 1) begin
        j_reg <= j_reg + 1;
      end
    end
  end
  
  // Default assignments
  assign input_ready = (current_state == IDLE || (current_state == LOAD_PRICES && price_counter < valid_length)) ? 1 : 0;
  
endmodule