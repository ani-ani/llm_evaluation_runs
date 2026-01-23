module bamboo_solver(
  input clk,
  input rst_n,
  input start,
  input stop,
  input [7:0] a_0, a_1, a_2, a_3,
  input [11:0] k,
  output reg [11:0] best_d,
  output reg [11:0] current_waste,
  output reg searching,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    SEARCHING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal d counter
  reg [11:0] d;

  // Calculate waste for each bamboo
  wire [11:0] waste_0 = (d * ((a_0 + d - 1) / d)) - a_0;
  wire [11:0] waste_1 = (d * ((a_1 + d - 1) / d)) - a_1;
  wire [11:0] waste_2 = (d * ((a_2 + d - 1) / d)) - a_2;
  wire [11:0] waste_3 = (d * ((a_3 + d - 1) / d)) - a_3;

  // Sum of wastes
  assign current_waste = waste_0 + waste_1 + waste_2 + waste_3;

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      best_d <= 12'b0;
      d <= 12'b0;
      searching <= 1'b0;
      done <= 1'b0;
    end else begin
      current_state <= next_state;
      
      case (current_state)
        IDLE: begin
          searching <= 1'b0;
          done <= 1'b0;
          best_d <= 12'b0;
          d <= 12'b0;
        end
        
        SEARCHING: begin
          searching <= 1'b1;
          done <= 1'b0;
          
          if (stop || d == 12'd4095) begin
            next_state <= DONE;
          end else begin
            d <= d + 12'd1;
            
            if (current_waste <= k) begin
              best_d <= d;
            end
          end
        end
        
        DONE: begin
          searching <= 1'b0;
          done <= 1'b1;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = SEARCHING;
        end
      end
      
      SEARCHING: begin
        if (stop || d == 12'd4095) begin
          next_state = DONE;
        end
      end
      
      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end
    endcase
  end

endmodule