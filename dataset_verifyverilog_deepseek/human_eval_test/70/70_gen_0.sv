module strange_sorter(
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] data_in,
  input [2:0] size_in,
  output reg [7:0][31:0] data_out,
  output reg done
);

typedef enum logic [2:0] { IDLE, FIND_MIN, FIND_MAX, STORE, DONE } state_t;
reg [2:0] current_size;
reg [7:0][31:0] current_data;
reg [7:0] mask;
reg [31:0] found_value;
reg [2:0] found_index;
reg [2:0] output_idx;
reg last_find_was_min;
state_t current_state, next_state;

// Combinational min/max finding
always_comb begin
  found_value = last_find_was_min ? 32'h7FFFFFFF : 32'h80000000;
  found_index = 0;
  if (current_state == FIND_MIN || current_state == FIND_MAX) begin
    for (int i=0; i<8; i=i+1) begin
      if (i < current_size && ~mask[i]) begin
        if (current_state == FIND_MIN) begin
          if (current_data[i] < found_value) begin
            found_value = current_data[i]; 
            found_index = i;
          end
        end
        else begin
          if (current_data[i] > found_value) begin
            found_value = current_data[i];
            found_index = i;
          end
        end
      end
    end
  end
end

// State transition
always_comb begin
  next_state = current_state;
  case (current_state)
    IDLE: next_state = (start) ? (size_in ? FIND_MIN : DONE) : IDLE;
    FIND_MIN, FIND_MAX: next_state = STORE;
    STORE: begin
      if ((output_idx + 1) >= current_size) 
        next_state = IDLE;
      else 
        next_state = last_find_was_min ? FIND_MAX : FIND_MIN;
    end
    DONE: next_state = IDLE;
  endcase
end

// Sequential logic
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    current_state <= IDLE;
    current_data <= '0;
    current_size <= 0;
    mask <= 8'h00;
    output_idx <= 0;
    last_find_was_min <= 0;
    done <= 0;
    data_out <= '0;
  end else begin
    current_state <= next_state;
    done <= 0;

    case (next_state)
      IDLE: begin
        mask <= 8'h00;
        output_idx <= 0;
        last_find_was_min <= 0;
        if (current_state == IDLE && start) begin
          current_data <= data_in;
          current_size <= size_in;
        end
      end
      
      FIND_MIN: last_find_was_min <= 1;
      FIND_MAX: last_find_was_min <= 0;
      
      STORE: begin
        data_out[output_idx] <= found_value;
        mask[found_index] <= 1'b1;
        output_idx <= output_idx + 1;
        if ((output_idx + 1) >= current_size) 
          done <= 1;
      end
      
      DONE: done <= 1;
    endcase
  end
end

endmodule