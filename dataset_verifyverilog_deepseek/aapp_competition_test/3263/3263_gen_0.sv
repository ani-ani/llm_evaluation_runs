module fluttershy_scheduler(input clk, input rst_n, input start, output reg [2:0] max_customers, output reg done);

  // State definitions
  typedef enum reg [2:0] {
    IDLE,
    CHECK,
    REMOVE_START,
    REMOVE_WAIT,
    PUT_START,
    PUT_WAIT,
    DONE
  } state_t;
  
  state_t state;
  
  // Parameters
  parameter logic [1:0] N = 4;
  parameter logic [1:0] M = 2;
  
  parameter logic [7:0] P_time [0:1] = '{8'h0A, 8'h14};
  parameter logic [7:0] R_time [0:1] = '{8'h05, 8'h05};
  
  parameter logic [1:0] customer_clothes [0:3] = '{2'b10, 2'b01, 2'b01, 2'b10};
  parameter logic [15:0] customer_times [0:3] = '{16'h0014, 16'h001E, 16'h0020, 16'h0078};
  
  // Internal registers
  reg [15:0] current_time;
  reg [2:0] current_clothing;
  reg [2:0] count;
  reg [2:0] customer_index;
  reg [7:0] saved_remove_time;
  reg [7:0] saved_put_time;
  reg [1:0] saved_customer_clothing;
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_customers <= 0;
      current_time <= 0;
      current_clothing <= 0;
      count <= 0;
      customer_index <= 0;
      saved_remove_time <= 0;
      saved_put_time <= 0;
      saved_customer_clothing <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= CHECK;
            current_time <= 0;
            current_clothing <= 0;
            count <= 0;
            customer_index <= 0;
          end
        end
        
        CHECK: begin
          if (customer_index >= N) begin
            state <= DONE;
            max_customers <= count;
            done <= 1;
          end else begin
            // Get current customer data
            saved_customer_clothing <= customer_clothes[customer_index];
            
            if (current_clothing == customer_clothes[customer_index]) begin
              // Clothing matches - serve immediately
              count <= count + 1;
              current_time <= customer_times[customer_index];
              customer_index <= customer_index + 1;
            end else begin
              // Calculate times
              saved_remove_time <= (current_clothing != 0) ? R_time[current_clothing-1] : 8'b0;
              saved_put_time <= P_time[customer_clothes[customer_index]-1];
              
              if ((current_time + saved_remove_time + saved_put_time) <= customer_times[customer_index]) begin
                state <= REMOVE_START;
              end else begin
                // No time to change - skip
                customer_index <= customer_index + 1;
              end
            end
          end
        end
        
        REMOVE_START: begin
          state <= REMOVE_WAIT;
        end
        
        REMOVE_WAIT: begin
          current_time <= current_time + saved_remove_time;
          current_clothing <= 0;
          state <= PUT_START;
        end
        
        PUT_START: begin
          state <= PUT_WAIT;
        end
        
        PUT_WAIT: begin
          current_time <= current_time + saved_put_time;
          current_clothing <= saved_customer_clothing;
          count <= count + 1;
          customer_index <= customer_index + 1;
          state <= CHECK;
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule