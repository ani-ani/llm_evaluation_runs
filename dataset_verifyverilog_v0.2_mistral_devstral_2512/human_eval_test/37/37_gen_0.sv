module sort_even (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in [0:7],
  output reg [7:0] data_out [0:7],
  output reg done
);

  // Internal buffer for data
  reg [7:0] buffer [0:7];
  
  // State machine
  typedef enum logic [2:0] {
    IDLE,
    READ,
    SORT_EVEN,
    WRITE,
    DONE
  } state_t;
  
  state_t state, next_state;
  
  // Bubble sort variables
  reg [7:0] temp;
  integer i, j;
  reg [3:0] pass_count;
  reg [3:0] swap_count;
  
  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      pass_count <= 0;
      swap_count <= 0;
      i <= 0;
      j <= 0;
    end else begin
      state <= next_state;
    end
  end
  
  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = READ;
      end
      READ: begin
        next_state = SORT_EVEN;
      end
      SORT_EVEN: begin
        if (pass_count == 3) next_state = WRITE;
      end
      WRITE: begin
        next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end
  
  // Data processing logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (integer k = 0; k < 8; k = k + 1) begin
        buffer[k] <= 0;
        data_out[k] <= 0;
      end
    end else begin
      case (state)
        READ: begin
          for (integer k = 0; k < 8; k = k + 1) begin
            buffer[k] <= data_in[k];
          end
        end
        SORT_EVEN: begin
          if (j < 3) begin
            if (buffer[2*j] > buffer[2*j + 2]) begin
              temp <= buffer[2*j];
              buffer[2*j] <= buffer[2*j + 2];
              buffer[2*j + 2] <= temp;
              swap_count <= swap_count + 1;
            end
            j <= j + 1;
          end else begin
            j <= 0;
            if (swap_count == 0 || pass_count == 3) begin
              pass_count <= pass_count + 1;
              swap_count <= 0;
            end else begin
              pass_count <= pass_count + 1;
              swap_count <= 0;
            end
          end
        end
        WRITE: begin
          for (integer k = 0; k < 8; k = k + 1) begin
            data_out[k] <= buffer[k];
          end
        end
        DONE: begin
          done <= 1;
        end
        default: begin
          done <= 0;
        end
      endcase
    end
  end

endmodule