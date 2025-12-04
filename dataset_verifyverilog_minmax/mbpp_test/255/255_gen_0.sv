module combination_generator (
  input clk,
  input rst_n,
  input [1:0] combo_len,
  input start,
  output reg [5:0] current_combo,
  output reg [3:0] combo_count,
  output reg done
);

  localparam IDLE = 2'd0;
  localparam GENERATING = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state;
  reg [3:0] total_combos;
  reg [3:0] combo_index;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      total_combos <= 4'd0;
      combo_index <= 4'd0;
      combo_count <= 4'd0;
      current_combo <= 6'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            case (combo_len)
              2'd1: total_combos <= 4'd3;
              2'd2: total_combos <= 4'd6;
              2'd3: total_combos <= 4'd10;
              default: total_combos <= 4'd0;
            endcase
            combo_index <= 4'd0;
            state <= GENERATING;
            done <= 1'b0;
          end
        end

        GENERATING: begin
          combo_count <= combo_index + 1;
          
          case (combo_len)
            2'd1: begin
              case (combo_index)
                4'd0: current_combo <= 6'b00_0000;
                4'd1: current_combo <= 6'b00_0001;
                4'd2: current_combo <= 6'b00_0010;
                default: current_combo <= 6'b00_0000;
              endcase
            end
            2'd2: begin
              case (combo_index)
                4'd0: current_combo <= 6'b00_0000; // (0,0)
                4'd1: current_combo <= 6'b00_0001; // (0,1)
                4'd2: current_combo <= 6'b00_0010; // (0,2)
                4'd3: current_combo <= 6'b00_0101; // (1,1)
                4'd4: current_combo <= 6'b00_0110; // (1,2)
                4'd5: current_combo <= 6'b00_1010; // (2,2)
                default: current_combo <= 6'b00_0000;
              endcase
            end
            2'd3: begin
              case (combo_index)
                4'd0: current_combo <= 6'b00_0000; // (0,0,0)
                4'd1: current_combo <= 6'b00_0001; // (0,0,1)
                4'd2: current_combo <= 6'b00_0010; // (0,0,2)
                4'd3: current_combo <= 6'b00_0101; // (0,1,1)
                4'd4: current_combo <= 6'b00_0110; // (0,1,2)
                4'd5: current_combo <= 6'b00_1010; // (0,2,2)
                4'd6: current_combo <= 6'b01_0101; // (1,1,1)
                4'd7: current_combo <= 6'b01_0110; // (1,1,2)
                4'd8: current_combo <= 6'b01_1010; // (1,2,2)
                4'd9: current_combo <= 6'b10_1010; // (2,2,2)
                default: current_combo <= 6'b00_0000;
              endcase
            end
          endcase

          if (combo_index == total_combos - 1) begin
            state <= DONE;
          end else begin
            combo_index <= combo_index + 1;
          end
        end

        DONE: begin
          done <= 1'b1;
          combo_count <= 4'd0;
          current_combo <= 6'd0;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule