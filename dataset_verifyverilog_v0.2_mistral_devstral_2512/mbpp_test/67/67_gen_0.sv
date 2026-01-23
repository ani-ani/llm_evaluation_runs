module bell_number (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  output reg [63:0] result,
  output reg done
);

  // Define states
  typedef enum logic [1:0] {
    IDLE,
    FETCH,
    COMPUTE,
    DONE
  } state_t;

  // State register
  state_t state, next_state;

  // Counter for latency
  reg [3:0] counter;

  // Lookup table (ROM) for Bell numbers
  localparam [63:0] bell_table [0:8] = '{64'd1, 64'd1, 64'd2, 64'd5, 64'd15, 64'd52, 64'd203, 64'd877, 64'd4140};

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      counter <= 0;
      result <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      
      case (state)
        IDLE: begin
          if (start) begin
            next_state = FETCH;
            counter <= 0;
          end else begin
            next_state = IDLE;
          end
        end
        
        FETCH: begin
          if (counter == 9) begin
            next_state = COMPUTE;
            counter <= 0;
          end else begin
            next_state = FETCH;
            counter <= counter + 1;
          end
        end
        
        COMPUTE: begin
          if (counter == 9) begin
            next_state = DONE;
            counter <= 0;
          end else begin
            next_state = COMPUTE;
            counter <= counter + 1;
          end
        end
        
        DONE: begin
          if (!start) begin
            next_state = IDLE;
          end else begin
            next_state = DONE;
          end
        end
      endcase
    end
  end

  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          result <= 0;
          done <= 0;
        end
        
        FETCH: begin
          if (counter == 9) begin
            if (n > 8) begin
              result <= 0;
            end else begin
              result <= bell_table[n];
            end
          end
        end
        
        COMPUTE: begin
          // No additional processing needed
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule