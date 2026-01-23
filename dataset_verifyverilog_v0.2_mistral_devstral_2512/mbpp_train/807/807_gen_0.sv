module first_odd_finder (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  input [2:0] list_size,
  input valid_in,
  output reg [7:0] first_odd,
  output reg found,
  output reg done
);

  typedef enum logic [1:0] {
    IDLE,
    PROCESSING,
    CHECKING,
    DONE
  } state_t;

  state_t current_state, next_state;
  reg [2:0] counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      counter <= 0;
      first_odd <= 8'hFF;
      found <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == CHECKING && data_in[0]) begin
        first_odd <= data_in;
        found <= 1;
      end else if (current_state == DONE) begin
        done <= 1;
      end
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = PROCESSING;
      end
      PROCESSING: begin
        if (valid_in) next_state = CHECKING;
      end
      CHECKING: begin
        if (data_in[0]) begin
          next_state = DONE;
        end else if (counter == list_size - 1) begin
          next_state = DONE;
          first_odd = 8'hFF;
          found = 0;
        end else begin
          next_state = PROCESSING;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      counter <= 0;
    end else if (current_state == CHECKING && !data_in[0] && counter < list_size - 1) begin
      counter <= counter + 1;
    end else if (current_state == IDLE && start) begin
      counter <= 0;
    end
  end

endmodule