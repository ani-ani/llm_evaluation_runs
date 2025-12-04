module unique_tuples(
  input clk,
  input rst_n,
  input start,
  input [31:0] data,
  output reg [2:0] unique_count,
  output reg done
);

  typedef enum logic [2:0] { IDLE, STEP0, STEP1, STEP2, STEP3, DONE } state_t;
  state_t state;

  reg [31:0] data_reg;
  reg [3:0] stored_min [0:3];
  reg [3:0] stored_max [0:3];
  reg [2:0] stored_count;

  reg found;
  reg [3:0] min_val, max_val;
  integer i;

  always_comb begin
    found = 1'b0;
    for (i = 0; i < stored_count; i = i + 1) begin
      if (stored_min[i] == min_val && stored_max[i] == max_val) found = 1'b1;
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      unique_count <= 3'b0;
      stored_count <= 3'b0;
      for (int j=0; j<4; j++) begin
        stored_min[j] <= 4'b0;
        stored_max[j] <= 4'b0;
      end
      data_reg <= 32'b0;
    end else begin
      done <= 1'b0;
      case(state)
        IDLE: begin
          if (start) begin
            data_reg <= data;
            stored_count <= 3'b0;
            for (int j=0; j<4; j++) begin
              stored_min[j] <= 4'b0;
              stored_max[j] <= 4'b0;
            end
            state <= STEP0;
          end
        end

        STEP0: begin
          min_val = (data_reg[31:28] < data_reg[27:24]) ? data_reg[31:28] : data_reg[27:24];
          max_val = (data_reg[31:28] >= data_reg[27:24]) ? data_reg[31:28] : data_reg[27:24];
          if (!found && (stored_count < 4)) begin
            stored_min[stored_count] <= min_val;
            stored_max[stored_count] <= max_val;
            stored_count <= stored_count + 1;
          end
          state <= STEP1;
        end

        STEP1: begin
          min_val = (data_reg[23:20] < data_reg[19:16]) ? data_reg[23:20] : data_reg[19:16];
          max_val = (data_reg[23:20] >= data_reg[19:16]) ? data_reg[23:20] : data_reg[19:16];
          if (!found && (stored_count < 4)) begin
            stored_min[stored_count] <= min_val;
            stored_max[stored_count] <= max_val;
            stored_count <= stored_count + 1;
          end
          state <= STEP2;
        end

        STEP2: begin
          min_val = (data_reg[15:12] < data_reg[11:8]) ? data_reg[15:12] : data_reg[11:8];
          max_val = (data_reg[15:12] >= data_reg[11:8]) ? data_reg[15:12] : data_reg[11:8];
          if (!found && (stored_count < 4)) begin
            stored_min[stored_count] <= min_val;
            stored_max[stored_count] <= max_val;
            stored_count <= stored_count + 1;
          end
          state <= STEP3;
        end

        STEP3: begin
          min_val = (data_reg[7:4] < data_reg[3:0]) ? data_reg[7:4] : data_reg[3:0];
          max_val = (data_reg[7:4] >= data_reg[3:0]) ? data_reg[7:4] : data_reg[3:0];
          if (!found && (stored_count < 4)) begin
            stored_min[stored_count] <= min_val;
            stored_max[stored_count] <= max_val;
            stored_count <= stored_count + 1;
          end
          state <= DONE;
        end

        DONE: begin
          unique_count <= stored_count;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule