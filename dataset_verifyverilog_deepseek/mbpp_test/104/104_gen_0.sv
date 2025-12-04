module string_sublist_sorter #(
  parameter MAX_SUBLIST_SIZE = 4,
  parameter MAX_LIST_SIZE = 4,
  parameter STR_WIDTH = 8
)(
  input clk,
  input rst_n,
  input start,
  input [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_in,
  input [7:0] sizes_in [MAX_LIST_SIZE-1:0],
  output reg [MAX_LIST_SIZE-1:0][MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] data_out,
  output reg done
);

  reg [2:0] state;
  reg [1:0] current_sublist_index;
  reg [MAX_SUBLIST_SIZE-1:0][STR_WIDTH-1:0] current_sublist;
  reg [7:0] current_size;
  reg [1:0] pass_counter;
  reg [1:0] element_counter;

  localparam 
    IDLE = 3'b000,
    LOAD = 3'b001,
    SORT = 3'b010,
    STORE = 3'b011,
    DONE_STATE = 3'b100;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      data_out <= '0;
      current_sublist_index <= '0;
      current_sublist <= '0;
      pass_counter <= '0;
      element_counter <= '0;
      current_size <= '0;
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            current_sublist_index <= 0;
            state <= LOAD;
          end
        end

        LOAD: begin
          current_sublist <= data_in[current_sublist_index];
          current_size <= sizes_in[current_sublist_index];
          if (sizes_in[current_sublist_index] > 1) begin
            pass_counter <= 0;
            element_counter <= 0;
            state <= SORT;
          end else begin
            state <= STORE;
          end
        end

        SORT: begin
          if (pass_counter < (current_size - 1)) begin
            if (element_counter < (current_size - pass_counter - 1)) begin
              if (current_sublist[element_counter][STR_WIDTH-1:STR_WIDTH-8] > current_sublist[element_counter+1][STR_WIDTH-1:STR_WIDTH-8]) begin
                current_sublist[element_counter] <= current_sublist[element_counter+1];
                current_sublist[element_counter+1] <= current_sublist[element_counter];
              end
              element_counter <= element_counter + 1;
            end else begin
              pass_counter <= pass_counter + 1;
              element_counter <= 0;
            end
          end else begin
            state <= STORE;
          end
        end

        STORE: begin
          data_out[current_sublist_index] <= current_sublist;
          if (current_sublist_index == (MAX_LIST_SIZE - 1)) begin
            state <= DONE_STATE;
          end else begin
            current_sublist_index <= current_sublist_index + 1;
            state <= LOAD;
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          if (start) state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule