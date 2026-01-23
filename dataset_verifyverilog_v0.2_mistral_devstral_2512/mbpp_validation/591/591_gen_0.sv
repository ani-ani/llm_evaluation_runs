module swap_list (
  input clk,
  input rst_n,
  input start,
  input [4:0][7:0] data_in,
  output reg [4:0][7:0] data_out,
  output reg done
);

  parameter N = 5;
  
  typedef enum logic [1:0] {
    IDLE,
    SWAP,
    DONE
  } state_t;
  
  state_t state, next_state;
  
  reg [7:0] temp_first;
  reg [7:0] temp_last;
  
  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      data_out <= '0;
    end else begin
      state <= next_state;
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = SWAP;
      end
      SWAP: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end
  
  // Output logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      data_out <= '0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          data_out <= data_in;
          done <= 1'b0;
        end
        SWAP: begin
          // Store first and last elements
          temp_first = data_in[0];
          temp_last = data_in[N-1];
          
          // Swap first and last
          data_out[0] = temp_last;
          data_out[N-1] = temp_first;
          
          // Pass through other elements
          for (int i = 1; i < N-1; i++) begin
            data_out[i] = data_in[i];
          end
          done <= 1'b0;
        end
        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end

endmodule