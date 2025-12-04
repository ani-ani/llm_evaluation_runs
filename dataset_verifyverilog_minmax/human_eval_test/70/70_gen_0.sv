module strange_sorter (
  input clk,
  input rst_n,
  input start,
  input [7:0][31:0] data_in,
  input [2:0] size_in,
  output reg [7:0][31:0] data_out,
  output reg done
);

// State machine states
localparam IDLE = 3'b000;
localparam FIND_MIN = 3'b001;
localparam FIND_MAX = 3'b010;
localparam STORE = 3'b011;
localparam DONE = 3'b100;

// Internal registers
reg [2:0] state;
reg [2:0] count;   // counts the number of stored elements (0 to size_in)
reg [7:0] mask;
reg [31:0] cur_data [0:7];   // current data array
reg [31:0] captured_value;   // holds the min or max value found
reg [2:0] captured_index;    // holds the index of the min or max

// Min and max computation
reg [31:0] min_value, max_value;
reg [2:0] min_index, max_index;

integer i;
always @(*) begin
  min_value = 32'h7FFFFFFF;
  min_index = 0;
  max_value = 32'h80000000;
  max_index = 0;
  for (i=0; i<8; i++) begin
    if (mask[i]) begin
      if (cur_data[i] < min_value) begin
        min_value = cur_data[i];
        min_index = i;
      end
      if (cur_data[i] > max_value) begin
        max_value = cur_data[i];
        max_index = i;
      end
    end
  end
end

// State machine
always @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    count <= 0;
    mask <= 0;
    done <= 0;
    captured_value <= 0;
    captured_index <= 0;
    // Reset data_out
    for (i=0; i<8; i++) begin
      data_out[i] <= 0;
    end
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          if (size_in == 0) begin
            state <= DONE;
            done <= 1;
          end else begin
            state <= FIND_MIN;
            done <= 0;
            // Load the data and mask
            for (i=0; i<8; i++) begin
              cur_data[i] <= data_in[i];
            end
            mask <= 0;
            for (i=0; i<size_in; i++) begin
              mask[i] <= 1;
            end
            count <= 0;
          end
        end
      end
      FIND_MIN: begin
        captured_value <= min_value;
        captured_index <= min_index;
        state <= STORE;
      end
      FIND_MAX: begin
        captured_value <= max_value;
        captured_index <= max_index;
        state <= STORE;
      end
      STORE: begin
        data_out[count] <= captured_value;
        mask[captured_index] <= 1'b0;
        count <= count + 1;

        if (count == size_in-1) begin
          state <= DONE;
          done <= 1;
        end else begin
          if (count[0] == 1'b0) 
            state <= FIND_MAX;
          else
            state <= FIND_MIN;
        end
      end
      DONE: begin
        if (!start) begin
          state <= IDLE;
          done <= 0;
        end
      end
    endcase
  end
end

endmodule