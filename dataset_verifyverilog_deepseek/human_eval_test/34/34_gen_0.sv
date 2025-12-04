module unique_sorted (
  input clk,
  input rst_n,
  input [7:0] d_in[0:7],
  input start,
  output reg [7:0] result[0:7],
  output reg [3:0] count,
  output reg done
);

  localparam IDLE = 3'd0;
  localparam LOAD = 3'd1;
  localparam SORT = 3'd2;
  localparam DEDUP = 3'd3;
  localparam DONE = 3'd4;

  reg [2:0] state = IDLE;
  reg [6:0] cycle_counter = 0;
  reg [7:0] data_reg[0:7];
  reg [7:0] unique_reg[0:7];
  reg [3:0] unique_count = 0;
  reg [7:0] last_value = 0;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      cycle_counter <= 0;
      for (int i = 0; i < 8; i++) begin
        data_reg[i] <= 8'b0;
        unique_reg[i] <= 8'b0;
        result[i] <= 8'b0;
      end
      unique_count <= 0;
      last_value <= 0;
      count <= 0;
    end else begin
      case (state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= LOAD;
            cycle_counter <= 0;
          end
        end

        LOAD: begin
          for (int i = 0; i < 8; i++) begin
            data_reg[i] <= d_in[i];
          end
          state <= SORT;
          cycle_counter <= 0;
        end

        SORT: begin
          if (cycle_counter < 7'd63) begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter[2:0] < 3'd7) begin
              if (data_reg[cycle_counter[2:0]] > data_reg[cycle_counter[2:0] + 1]) begin
                data_reg[cycle_counter[2:0]] <= data_reg[cycle_counter[2:0] + 1];
                data_reg[cycle_counter[2:0] + 1] <= data_reg[cycle_counter[2:0]];
              end
            end
          end else begin
            state <= DEDUP;
            cycle_counter <= 7'd64;
            unique_count <= 0;
            last_value <= 0;
            for (int i = 0; i < 8; i++) unique_reg[i] <= 0;
          end
        end

        DEDUP: begin
          if (cycle_counter < 7'd71) begin
            cycle_counter <= cycle_counter + 1;
            if (cycle_counter == 7'd64) begin
              unique_reg[0] <= data_reg[0];
              unique_count <= 4'd1;
              last_value <= data_reg[0];
            end else if (data_reg[cycle_counter - 64] != last_value) begin
              unique_reg[unique_count] <= data_reg[cycle_counter - 64];
              unique_count <= unique_count + 4'd1;
              last_value <= data_reg[cycle_counter - 64];
            end
          end else begin
            if (data_reg[7] != last_value) begin
              unique_reg[unique_count] <= data_reg[7];
              unique_count <= unique_count + 4'd1;
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          for (int i = 0; i < 8; i++) result[i] <= unique_reg[i];
          count <= unique_count;
          if (start) begin
            state <= LOAD;
            done <= 0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule