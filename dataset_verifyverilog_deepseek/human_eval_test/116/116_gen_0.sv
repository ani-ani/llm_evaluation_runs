module bit_count_sorter (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] data_in [0:7],
  output reg signed [7:0] sorted_data [0:7],
  output reg done
);
  typedef enum logic [1:0] {IDLE, CAPTURE, SORTING, DONE} state_t;
  reg signed [7:0] data_reg [0:7];
  state_t state;
  reg [3:0] pass_count;
  reg [2:0] index;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      pass_count <= 0;
      index <= 0;
      for (int i=0; i<8; i++) data_reg[i] <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) state <= CAPTURE;
        end
        CAPTURE: begin
          state <= SORTING;
          for (int i=0; i<8; i++) data_reg[i] <= data_in[i];
          pass_count <= 0;
          index <= 0;
        end
        SORTING: begin
          int pc1 = $countones(data_reg[index]);
          int pc2 = $countones(data_reg[index+1]);
          if ((pc1 > pc2) || (pc1 == pc2 && data_reg[index] > data_reg[index+1])) begin
            automatic logic signed [7:0] temp = data_reg[index];
            data_reg[index] <= data_reg[index+1];
            data_reg[index+1] <= temp;
          end
          if (index == 3'd6) begin
            index <= 0;
            pass_count <= pass_count + 1;
            if (pass_count == 4'd7) state <= DONE;
          end else begin
            index <= index + 1;
          end
        end
        DONE: begin
          done <= 1;
          if (start) state <= CAPTURE;
        end
        default: state <= IDLE;
      endcase
    end
  end

  always_comb begin
    for (int i=0; i<8; i++) sorted_data[i] = data_reg[i];
  end
endmodule