module music_parser(input clk, input rst_n, input start, input [5:0] length, input [255:0] music_string, 
  output reg [2:0] beat, output reg beat_valid, output reg done);

  localparam IDLE = 2'd0;
  localparam PROCESSING = 2'd1;
  localparam DONE = 2'd2;

  reg [1:0] state;
  reg [5:0] index;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      index <= 6'b0;
      beat <= 3'b0;
      beat_valid <= 1'b0;
      done <= 1'b0;
    end else begin
      beat_valid <= 1'b0;
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            state <= PROCESSING;
            index <= 6'b0;
          end
        end

        PROCESSING: begin
          if (index >= length) begin
            state <= DONE;
            done <= 1'b1;
          end else begin
            reg [7:0] current_byte = music_string[index*8 +: 8];
            if (current_byte == 8'h20) begin
              index <= index + 1;
            end else if (current_byte == "o") begin
              if ((index + 1 < length) && (music_string[(index+1)*8 +: 8] == "|")) begin
                beat <= 3'd2;
                beat_valid <= 1'b1;
                index <= index + 2;
              end else begin
                beat <= 3'd4;
                beat_valid <= 1'b1;
                index <= index + 1;
              end
            end else if (current_byte == ".") begin
              if ((index + 1 < length) && (music_string[(index+1)*8 +: 8] == "|")) begin
                beat <= 3'd1;
                beat_valid <= 1'b1;
                index <= index + 2;
              end else begin
                state <= DONE;
                done <= 1'b1;
              end
            end else begin
              state <= DONE;
              done <= 1'b1;
            end
          end
        end

        DONE: begin
          done <= 1'b1;
          if (start) begin
            state <= PROCESSING;
            index <= 6'b0;
          end
        end

        default: state <= IDLE;
      endcase
    end
  end
endmodule